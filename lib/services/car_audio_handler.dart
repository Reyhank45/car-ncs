import 'dart:async';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:http/http.dart' as http;
import '../models/ncs_track.dart';
import '../services/ncs_service.dart';
import '../services/ncs_download_manager.dart';

void _logAudio(String msg) {
  debugPrint(msg);
  if (kIsWeb) {
    http.get(Uri.http('127.0.0.1:8088', '/log', {'msg': '[CarAudioHandler] $msg'})).ignore();
  }
}

/// Car audio engine implementing progressive stream-to-disk with IMMEDIATE playback.
/// Starts streaming live audio within 1-2s (or instant if cached), while detaching
/// a 4-chunk parallel background downloader to cache the complete file to disk.
class CarAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player = AudioPlayer(
    audioLoadConfiguration: const AudioLoadConfiguration(
      androidLoadControl: AndroidLoadControl(
        minBufferDuration: Duration(seconds: 15),
        maxBufferDuration: Duration(seconds: 45),
        bufferForPlaybackDuration: Duration(milliseconds: 500),
        bufferForPlaybackAfterRebufferDuration: Duration(milliseconds: 1000),
      ),
      darwinLoadControl: DarwinLoadControl(
        preferredForwardBufferDuration: Duration(seconds: 30),
      ),
    ),
  );
  final NcsService _ncsService = NcsService();
  final NcsDownloadManager _downloadManager = NcsDownloadManager();

  NcsTrack? _currentTrack;
  String _currentGenre = 'Trap';

  final List<NcsTrack> _historyList = [];
  final List<NcsTrack> _upcomingQueue = [];

  bool _isOfflineRetrying = false;
  bool _isPreCaching = false;
  double _cachingProgress = 0.0;
  bool _isRefilling = false;
  Timer? _retryTimer;
  StreamSubscription<double>? _progressSub;

  bool get isOfflineRetrying => _isOfflineRetrying;
  bool get isPreCaching => _isPreCaching;
  double get cachingProgress => _cachingProgress;
  NcsTrack? get currentTrack => _currentTrack;
  String get currentGenre => _currentGenre;
  List<NcsTrack> get historyList => List.unmodifiable(_historyList);
  List<NcsTrack> get upcomingQueue => List.unmodifiable(_upcomingQueue);
  AudioPlayer get player => _player;

  final _trackChangeController = StreamController<NcsTrack?>.broadcast();
  Stream<NcsTrack?> get trackChangeStream => _trackChangeController.stream;

  final _offlineController = StreamController<bool>.broadcast();
  Stream<bool> get offlineStream => _offlineController.stream;

  final _preCachingController = StreamController<bool>.broadcast();
  Stream<bool> get preCachingStream => _preCachingController.stream;

  final _cachingProgressController = StreamController<double>.broadcast();
  Stream<double> get cachingProgressStream => _cachingProgressController.stream;

  void _setPreCaching(bool value, {double progress = 0.0}) {
    _isPreCaching = value;
    _cachingProgress = value ? progress : 0.0;
    _preCachingController.add(value);
    _cachingProgressController.add(_cachingProgress);
    if (value) {
      _logAudio('Background caching state: true (${(_cachingProgress * 100).toInt()}%)');
    }
  }

  void _setCachingProgress(double progress) {
    _cachingProgress = progress.clamp(0.0, 1.0);
    _cachingProgressController.add(_cachingProgress);
  }

  CarAudioHandler({bool autoStart = true}) {
    _initAudioPipeline(autoStart: autoStart);
  }

  /// The next upcoming track (Index 1) for AOT caching and UI preview
  NcsTrack? get nextTrack {
    if (_upcomingQueue.isNotEmpty) {
      return _upcomingQueue.first;
    }
    final sequence = _player.sequence;
    final currentIndex = _player.currentIndex;
    if (currentIndex != null && currentIndex + 1 < sequence.length) {
      final source = sequence[currentIndex + 1];
      if (source.tag is NcsTrack) {
        return source.tag as NcsTrack;
      }
    }
    return null;
  }

  /// Builds AudioSource:
  /// - If already cached on disk, returns AudioSource.file (instant 0ms playback & seek)
  /// - If not yet cached, returns AudioSource.uri with low-latency headers for immediate playback
  AudioSource _createAudioSource(NcsTrack track) {
    final cachedPath = _downloadManager.getCachedPath(track.id);
    if (!kIsWeb && cachedPath != null && File(cachedPath).existsSync()) {
      _logAudio('[CACHE HIT DISK PLAY] "${track.title}" from: $cachedPath');
      return AudioSource.file(
        File(cachedPath).path,
        tag: track,
      );
    }

    final normalizedUrl = NcsDownloadManager.normalizeUrl(track.audioUrl);
    _logAudio('[PROGRESSIVE LIVE STREAM] "${track.title}" via: $normalizedUrl');
    return AudioSource.uri(
      Uri.parse(normalizedUrl),
      headers: NcsDownloadManager.defaultHeaders,
      tag: track,
    );
  }

  void _initAudioPipeline({bool autoStart = true}) {
    // 1. Playback event sync for OS lockscreen & notification
    _player.playbackEventStream.listen((PlaybackEvent event) {
      final playing = _player.playing;
      final processingState = _isOfflineRetrying
          ? AudioProcessingState.idle
          : const {
              ProcessingState.idle: AudioProcessingState.idle,
              ProcessingState.loading: AudioProcessingState.loading,
              ProcessingState.buffering: AudioProcessingState.buffering,
              ProcessingState.ready: AudioProcessingState.ready,
              ProcessingState.completed: AudioProcessingState.completed,
            }[_player.processingState]!;

      playbackState.add(
        playbackState.value.copyWith(
          controls: [
            MediaControl.skipToPrevious,
            if (playing) MediaControl.pause else MediaControl.play,
            MediaControl.skipToNext,
          ],
          systemActions: const {
            MediaAction.seek,
            MediaAction.seekForward,
            MediaAction.seekBackward,
          },
          androidCompactActionIndices: const [0, 1, 2],
          processingState: processingState,
          playing: playing,
          updatePosition: _player.position,
          bufferedPosition: _player.bufferedPosition,
          speed: _player.speed,
          queueIndex: event.currentIndex,
        ),
      );
    });

    // 2. Track transition notification
    _player.sequenceStateStream.listen((sequenceState) {
      final currentSource = sequenceState.currentSource;
      if (currentSource != null && currentSource.tag is NcsTrack) {
        final track = currentSource.tag as NcsTrack;
        _onActiveTrackChanged(track);
      }
    });

    // 3. Queue progression & automatic AOT maintenance
    _player.currentIndexStream.listen((newIndex) {
      if (newIndex != null && newIndex > 0) {
        _handleTrackAdvanced();
      }
    });

    // 4. Download progress listener for HUD indicator
    _progressSub = _downloadManager.progressStream.listen((progress) {
      if (_isPreCaching) {
        _setCachingProgress(progress);
      }
    });

    // Initial genre load and background pool pre-warming
    unawaited(_ncsService.warmGenrePools());
    if (autoStart) {
      switchGenre('Trap');
    }
  }

  void _onActiveTrackChanged(NcsTrack track) {
    if (_currentTrack?.id == track.id) return;

    if (_currentTrack != null) {
      _historyList.removeWhere((t) => t.id == _currentTrack!.id);
      _historyList.insert(0, _currentTrack!);
      if (_historyList.length > 20) _historyList.removeLast();
    }

    _currentTrack = track;
    _upcomingQueue.removeWhere((t) => t.id == track.id);
    _trackChangeController.add(track);

    _logAudio('Active track: "${track.title}" by ${track.artists}');

    final item = MediaItem(
      id: track.id,
      album: 'NCS',
      title: track.title,
      artist: track.artists,
      genre: track.genreName,
      duration: track.duration,
      artUri: Uri.tryParse(track.artworkUrl),
    );
    mediaItem.add(item);
  }

  /// Detached background caching worker:
  /// Downloads the active track using the 4-chunk parallel isolate worker without blocking playback.
  /// Once complete, triggers prefetch for the next track in queue.
  Future<void> _cacheActiveTrackInBackground(NcsTrack track) async {
    if (kIsWeb) return;
    try {
      _setPreCaching(true, progress: 0.0);
      _logAudio('[DETACHED 4-CHUNK CACHE] Starting background download for "${track.title}"...');
      final file = await _downloadManager.downloadTrack(
        track.audioUrl,
        track.id,
        onProgress: (p) => _setCachingProgress(p),
      );
      _setPreCaching(false);

      if (file != null) {
        _logAudio('[DETACHED CACHE COMPLETE] "${track.title}" saved to disk: ${file.path}');
        // Trigger prefetch for upcoming track now that active track is safely cached
        _triggerPrefetchUpcoming();
      }
    } catch (e) {
      _setPreCaching(false);
      _logAudio('Background caching notice for "${track.title}": $e');
    }
  }

  /// Triggers background 4-chunk prefetching of upcoming tracks
  void _triggerPrefetchUpcoming() {
    if (kIsWeb) return;
    if (_upcomingQueue.isEmpty) {
      unawaited(_refillUpcomingQueue());
      return;
    }

    final next = _upcomingQueue.first;
    if (_downloadManager.isCachedSync(next.id)) {
      if (_upcomingQueue.length > 1) {
        final afterNext = _upcomingQueue[1];
        if (!_downloadManager.isCachedSync(afterNext.id) && !_downloadManager.isDownloading(afterNext.id)) {
          unawaited(_downloadManager.downloadTrack(afterNext.audioUrl, afterNext.id));
        }
      }
      return;
    }

    if (_downloadManager.isDownloading(next.id)) return;

    _logAudio('[AOT BACKGROUND PREFETCH] Prefetching upcoming track "${next.title}" to disk...');
    unawaited(_downloadManager.downloadTrack(next.audioUrl, next.id));
  }

  /// Refills the upcoming queue with tracks from the scraper
  Future<void> _refillUpcomingQueue() async {
    if (_isRefilling) return;
    _isRefilling = true;
    try {
      while (_upcomingQueue.length < 3) {
        final track = await _ncsService.fetchNextTrack(_currentGenre);
        if (track == null) break;
        if (!_upcomingQueue.any((t) => t.id == track.id) && _currentTrack?.id != track.id) {
          _upcomingQueue.add(track);
        }
      }
      _triggerPrefetchUpcoming();
    } catch (e) {
      _logAudio('Refill queue error: $e');
    } finally {
      _isRefilling = false;
    }
  }

  /// When track at Index 0 finishes playing, advance and maintain queue
  Future<void> _handleTrackAdvanced() async {
    _logAudio('Track finished. Advancing queue...');
    if (_player.audioSources.length > 1) {
      try {
        await _player.removeAudioSourceAt(0);
      } catch (e) {
        _logAudio('Error removing completed source: $e');
      }
    }
    unawaited(_refillUpcomingQueue());
    _triggerPrefetchUpcoming();
  }

  void _setOffline(bool offline) {
    if (_isOfflineRetrying != offline) {
      _isOfflineRetrying = offline;
      _offlineController.add(offline);
      _logAudio('Offline state changed: $offline');
      if (offline) {
        playbackState.add(
          playbackState.value.copyWith(
            processingState: AudioProcessingState.idle,
          ),
        );
        _scheduleOfflineRetry();
      } else {
        _retryTimer?.cancel();
      }
    }
  }

  void _scheduleOfflineRetry() {
    _retryTimer?.cancel();
    _retryTimer = Timer(const Duration(seconds: 4), () async {
      if (!_isOfflineRetrying) return;
      _logAudio('[OFFLINE: RETRYING STREAM...] Attempting scraper reconnect...');
      final track = await _ncsService.fetchNextTrack(_currentGenre);
      if (track != null) {
        _setOffline(false);
        if (_currentTrack == null) {
          await playTrack(track);
        } else {
          _upcomingQueue.add(track);
          _triggerPrefetchUpcoming();
        }
      } else {
        _scheduleOfflineRetry();
      }
    });
  }

  /// Switches genre:
  /// 1. Immediately aborts running background downloads and HTML scrapes (kill zombie sockets)
  /// 2. Selects track from in-memory pool instantly (non-blocking)
  /// 3. Updates UI metadata and album art immediately on Persistent Deck
  /// 4. Forces IMMEDIATE playback (starts in 1-2s over live stream or 0ms if cached)
  /// 5. Launches detached 4-chunk parallel download in background
  Future<void> switchGenre(String genre) async {
    _currentGenre = genre;
    _logAudio('Switching genre to: "$genre"');

    // 1. Immediately abort running download and HTML scrape
    await _downloadManager.cancelActiveDownload();
    _ncsService.cancelActiveScrape();
    _setPreCaching(false);

    try {
      await _player.stop();
      await _player.clearAudioSources();

      // 2. Instant track selection from in-memory pool
      final initialTracks = await _ncsService.loadInitialTracks(genre, count: 3);
      if (initialTracks.isEmpty) {
        _logAudio('initialTracks is empty for genre $genre');
        _setOffline(true);
        return;
      }

      _setOffline(false);
      final firstTrack = initialTracks.first;
      _upcomingQueue.clear();
      _upcomingQueue.addAll(initialTracks.skip(1));

      // 3. Immediately update UI metadata
      _onActiveTrackChanged(firstTrack);

      // 4. Force IMMEDIATE playback (starts playing in 1-2s or instant if cached)
      final source = _createAudioSource(firstTrack);
      await _player.setAudioSources([source], initialIndex: 0, preload: true);

      _player.play().catchError((e) {
        _logAudio('Autoplay notice: $e');
      });

      // 5. Detached background caching worker:
      if (!kIsWeb && !_downloadManager.isCachedSync(firstTrack.id)) {
        unawaited(_cacheActiveTrackInBackground(firstTrack));
      } else {
        _triggerPrefetchUpcoming();
      }
    } catch (e, st) {
      _logAudio('Switch genre error: $e\n$st');
      _setOffline(true);
    }
  }

  /// Plays a specific track with IMMEDIATE forced playback and detached background caching
  Future<void> playTrack(NcsTrack track) async {
    await _downloadManager.cancelActiveDownload();
    _ncsService.cancelActiveScrape();
    _setPreCaching(false);

    try {
      _ncsService.markTrackPlayed(track.id);
      _onActiveTrackChanged(track);

      final source = _createAudioSource(track);
      await _player.stop();
      await _player.clearAudioSources();
      await _player.setAudioSources([source], initialIndex: 0, preload: true);

      _player.play().catchError((e) {
        _logAudio('Play notice: $e');
      });

      unawaited(_refillUpcomingQueue());

      // Detached background caching
      if (!kIsWeb && !_downloadManager.isCachedSync(track.id)) {
        unawaited(_cacheActiveTrackInBackground(track));
      } else {
        _triggerPrefetchUpcoming();
      }
    } catch (e) {
      _logAudio('Play track error: $e');
      _setOffline(true);
    }
  }

  @override
  Future<void> play() {
    return _player.play();
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    await _downloadManager.cancelActiveDownload();
    _ncsService.cancelActiveScrape();
    await _player.stop();
    await super.stop();
  }

  /// Seeking behavior:
  /// If the track has finished downloading to disk while streaming, seamlessly
  /// upgrade to the local disk file at the requested seek position with 0ms buffering!
  @override
  Future<void> seek(Duration position) async {
    final track = _currentTrack;
    if (track != null && !kIsWeb && _downloadManager.isCachedSync(track.id)) {
      final cachedPath = _downloadManager.getCachedPath(track.id);
      final currentSource = _player.audioSource;
      if (cachedPath != null && currentSource is UriAudioSource && !currentSource.uri.isScheme('file')) {
        _logAudio('[SEEK SEAMLESS UPGRADE] Switching to local disk file for seek: $cachedPath');
        final wasPlaying = _player.playing;
        await _player.setAudioSource(
          AudioSource.file(File(cachedPath).path, tag: track),
          initialPosition: position,
          preload: true,
        );
        if (wasPlaying) {
          _player.play();
        }
        return;
      }
    }
    return _player.seek(position);
  }

  /// Skips to the next track:
  /// 1. Immediately aborts running background downloads & HTML scrapes
  /// 2. Updates metadata and album art immediately on Persistent Deck
  /// 3. Forces IMMEDIATE playback (starts in 1-2s or instant if cached)
  /// 4. Launches detached 4-chunk background caching for current & upcoming tracks
  @override
  Future<void> skipToNext() async {
    _logAudio('skipToNext called');

    // 1. Immediately abort running background downloads and HTML scrapes
    await _downloadManager.cancelActiveDownload();
    _ncsService.cancelActiveScrape();
    _setPreCaching(false);

    if (_upcomingQueue.isEmpty) {
      await _refillUpcomingQueue();
    }

    if (_upcomingQueue.isEmpty) {
      _setOffline(true);
      return;
    }

    final next = _upcomingQueue.removeAt(0);

    // 2. Immediately update metadata and art on the Persistent Deck
    _onActiveTrackChanged(next);

    // 3. Force IMMEDIATE playback
    final source = _createAudioSource(next);
    await _player.stop();
    await _player.clearAudioSources();
    await _player.setAudioSources([source], initialIndex: 0, preload: true);

    _player.play().catchError((e) {
      _logAudio('Play notice: $e');
    });

    // 4. Refill queue and start detached background caching
    unawaited(_refillUpcomingQueue());
    if (!kIsWeb && !_downloadManager.isCachedSync(next.id)) {
      unawaited(_cacheActiveTrackInBackground(next));
    } else {
      _triggerPrefetchUpcoming();
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (_player.position.inSeconds > 3) {
      await _player.seek(Duration.zero);
    } else if (_historyList.isNotEmpty) {
      final prev = _historyList.removeAt(0);
      await playTrack(prev);
    } else {
      await _player.seek(Duration.zero);
    }
  }

  void dispose() {
    _progressSub?.cancel();
    _downloadManager.cancelActiveDownload();
    _ncsService.cancelActiveScrape();
    _retryTimer?.cancel();
    _trackChangeController.close();
    _offlineController.close();
    _preCachingController.close();
    _cachingProgressController.close();
    _player.dispose();
  }
}
