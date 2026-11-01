import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../models/ncs_track.dart';
import '../services/car_audio_handler.dart';
import '../services/ncs_service.dart';

class AudioProvider extends ChangeNotifier {
  final CarAudioHandler _handler;
  final NcsService _ncsService = NcsService();

  StreamSubscription? _playerStateSub;
  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _trackSub;
  StreamSubscription? _offlineSub;
  StreamSubscription? _preCachingSub;
  StreamSubscription? _cachingProgressSub;

  Duration _currentPosition = Duration.zero;
  Duration _duration = const Duration(minutes: 3, seconds: 20);
  bool _isPlaying = false;
  bool _isLoading = false;
  double _cachingProgress = 0.0;

  AudioProvider(this._handler) {
    _bindHandler();
  }

  CarAudioHandler get handler => _handler;
  NcsTrack? get currentTrack => _handler.currentTrack;
  NcsTrack? get nextTrack => _handler.nextTrack;
  String get selectedGenre => _handler.currentGenre;
  List<NcsTrack> get currentGenrePool => _ncsService.getGenrePool(_handler.currentGenre);
  List<NcsTrack> get history => _handler.historyList;
  List<NcsTrack> get upcomingQueue => _handler.upcomingQueue;

  bool get isOfflineRetrying => _handler.isOfflineRetrying;
  bool get isPreCaching => _handler.isPreCaching;
  double get cachingProgress => _cachingProgress;
  Duration get currentPosition => _currentPosition;
  Duration get duration => _duration;
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;

  double get progressRatio => duration.inMilliseconds > 0
      ? (_currentPosition.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
      : 0.0;

  void _bindHandler() {
    _playerStateSub = _handler.player.playerStateStream.listen((state) {
      _isPlaying = state.playing;
      _isLoading = state.processingState == ProcessingState.loading ||
          state.processingState == ProcessingState.buffering;
      notifyListeners();
    });

    _positionSub = _handler.player.positionStream.listen((pos) {
      _currentPosition = pos;
      notifyListeners();
    });

    _durationSub = _handler.player.durationStream.listen((dur) {
      if (dur != null) {
        _duration = dur;
        notifyListeners();
      }
    });

    _trackSub = _handler.trackChangeStream.listen((track) {
      if (track != null) {
        _duration = track.duration;
      }
      notifyListeners();
    });

    _offlineSub = _handler.offlineStream.listen((_) {
      notifyListeners();
    });

    _preCachingSub = _handler.preCachingStream.listen((_) {
      _cachingProgress = _handler.cachingProgress;
      notifyListeners();
    });

    _cachingProgressSub = _handler.cachingProgressStream.listen((progress) {
      _cachingProgress = progress;
      notifyListeners();
    });
  }

  void togglePlayPause() {
    if (_isPlaying) {
      _handler.pause();
    } else {
      _handler.play();
    }
  }

  void seek(Duration position) {
    _handler.seek(position);
  }

  void playTrack(NcsTrack track) {
    _handler.playTrack(track);
  }

  void playNext() {
    _handler.skipToNext();
  }

  void playPrevious() {
    _handler.skipToPrevious();
  }

  Future<void> selectGenreAndFetchRandom(String genre) async {
    _isLoading = true;
    notifyListeners();
    await _handler.switchGenre(genre);
    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _playerStateSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _trackSub?.cancel();
    _offlineSub?.cancel();
    _preCachingSub?.cancel();
    _cachingProgressSub?.cancel();
    super.dispose();
  }
}
