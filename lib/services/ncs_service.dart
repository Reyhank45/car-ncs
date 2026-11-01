import 'dart:async';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:flutter/foundation.dart';
import '../models/ncs_track.dart';

void _logNcs(String msg) {
  debugPrint(msg);
  if (kIsWeb) {
    http.get(Uri.http('127.0.0.1:8088', '/log', {'msg': '[NcsService] $msg'})).ignore();
  }
}

class NcsService {
  static final NcsService _instance = NcsService._internal();
  factory NcsService() => _instance;
  NcsService._internal();

  static final Random _rng = Random();

  static const Map<String, String> ncsHeaders = {
    'User-Agent':
        'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36',
    'Referer': 'https://ncs.io/',
    'Accept':
        'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.9',
  };

  // Official NCS genre IDs from ncs.io filter form
  static const Map<String, int> _genreIds = {
    'trap': 14,
    'house': 10,
    'dubstep': 5,
    'chill': 2,
    'dnb': 3,
    'drum & bass': 3,
    'drum and bass': 3,
  };

  static int _mapGenreToId(String genre) {
    final lower = genre.toLowerCase();
    for (final entry in _genreIds.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    return 0; // 0 = all / surprise me
  }

  // Master genre pools retained for Viewport B (SONG | LIST). Never pruned with removeAt().
  final Map<String, List<NcsTrack>> _genrePools = {};
  // Played track IDs to enforce zero-duplicate playback.
  final Set<String> _playedTrackIds = {};
  // Track fetched pages per genre to rotate pages.
  final Map<String, Set<int>> _fetchedPages = {};

  // Active HTTP client for scraping to allow instant abort on genre switch
  http.Client? _activeScrapeClient;

  List<NcsTrack> getGenrePool(String genre) => List.unmodifiable(_genrePools[genre] ?? []);
  Set<String> get playedTrackIds => Set.unmodifiable(_playedTrackIds);

  void markTrackPlayed(String id) {
    _playedTrackIds.add(id);
  }

  /// Cancels any active in-flight HTML scrape immediately to liberate sockets
  void cancelActiveScrape() {
    try {
      _activeScrapeClient?.close();
    } catch (_) {}
    _activeScrapeClient = null;
  }

  /// Pre-scrapes track metadata for major genres in background so clicking a genre
  /// tile has instant metadata ready without waiting on a cold HTML scrape.
  Future<void> warmGenrePools() async {
    const genresToWarm = ['Trap', 'House', 'Dubstep'];
    for (final genre in genresToWarm) {
      if (_genrePools[genre]?.isEmpty ?? true) {
        try {
          await fetchPage(genre, 1);
        } catch (_) {}
      }
    }
  }

  /// Scrapes a page directly from https://ncs.io/music-search?page=$page&genre=$genreId
  /// Enforces a strict 6-second timeout. If page > 1 fails, retries once with page 1.
  Future<List<NcsTrack>> fetchPage(String genre, int page) async {
    final genreId = _mapGenreToId(genre);
    final queryMap = <String, String>{'page': page.toString()};
    if (genreId != 0) {
      queryMap['genre'] = genreId.toString();
    }

    final searchUri = kIsWeb
        ? Uri.http('127.0.0.1:8088', '/music-search', queryMap)
        : Uri.https('ncs.io', '/music-search', queryMap);
    _logNcs('Requesting: $searchUri');

    final client = http.Client();
    _activeScrapeClient = client;

    try {
      final response = await client
          .get(searchUri, headers: ncsHeaders)
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final tracks = _parseTracks(response.body, genre);
        if (tracks.isNotEmpty) {
          _appendUniqueTracks(genre, tracks);
          _markPageFetched(genre, page);
          _logNcs('Parsed ${tracks.length} tracks for "$genre" (page $page)');
          return tracks;
        }
      } else {
        _logNcs('Search returned HTTP ${response.statusCode}');
      }
    } catch (e) {
      _logNcs('Network error for $searchUri (attempt 1): $e');
      // If page > 1 failed, retry once with page 1
      if (page > 1) {
        try {
          final p1Map = {'page': '1', if (genreId != 0) 'genre': genreId.toString()};
          final p1Uri = kIsWeb
              ? Uri.http('127.0.0.1:8088', '/music-search', p1Map)
              : Uri.https('ncs.io', '/music-search', p1Map);
          _logNcs('Retrying page 1: $p1Uri');
          final retryResponse = await client
              .get(p1Uri, headers: ncsHeaders)
              .timeout(const Duration(seconds: 6));
          if (retryResponse.statusCode == 200) {
            final tracks = _parseTracks(retryResponse.body, genre);
            if (tracks.isNotEmpty) {
              _appendUniqueTracks(genre, tracks);
              _markPageFetched(genre, 1);
              return tracks;
            }
          }
        } catch (retryErr) {
          _logNcs('Retry page 1 error: $retryErr');
        }
      }
    } finally {
      if (_activeScrapeClient == client) {
        _activeScrapeClient = null;
      }
    }

    return [];
  }

  List<NcsTrack> _parseTracks(String html, String requestedGenre) {
    final document = html_parser.parse(html);
    final anchors = document.querySelectorAll('a.player-play');
    final tracks = <NcsTrack>[];

    for (final anchor in anchors) {
      final tid = anchor.attributes['data-tid']?.trim();
      final title = anchor.attributes['data-track']?.trim();
      final artistRaw =
          (anchor.attributes['data-artistraw'] ?? anchor.attributes['data-artist'] ?? '').trim();
      final dataUrl = anchor.attributes['data-url']?.trim();
      final coverUrl = anchor.attributes['data-cover']?.trim() ?? '';
      final genreAttr = anchor.attributes['data-genre']?.trim() ?? requestedGenre;

      if (title == null || title.isEmpty) continue;

      // Primary stream: AWS S3 direct stream URL via data-url (normalized hostname)
      String audioUrl = '';
      if (dataUrl != null && dataUrl.isNotEmpty && dataUrl.startsWith('http')) {
        audioUrl = dataUrl.replaceAll(
          'ncsmusic.s3.eu-west-1.amazonaws.com',
          'ncsmusic.s3-eu-west-1.amazonaws.com',
        );
      }

      // STRICT VALIDATION: discard nodes with invalid / non-http URLs
      if (!audioUrl.startsWith('http')) continue;

      // Normalize artwork URL
      String art = coverUrl;
      if (art.startsWith('//')) {
        art = 'https:$art';
      } else if (art.startsWith('/')) {
        art = 'https://ncs.io$art';
      }

      // Strip HTML formatting from artist tags
      String artist = artistRaw.replaceAll(RegExp(r'<[^>]*>'), '').trim();
      if (artist.isEmpty) artist = 'NCS Artist';

      tracks.add(NcsTrack(
        id: tid ?? '${title.hashCode}',
        title: title,
        artists: artist,
        audioUrl: audioUrl,
        artworkUrl: art,
        genreName: genreAttr,
        genreColorHex: NcsTrack.mapGenreToHex(genreAttr),
        duration: const Duration(minutes: 3, seconds: 20),
      ));
    }

    return tracks;
  }

  void _appendUniqueTracks(String genre, List<NcsTrack> newTracks) {
    final pool = _genrePools.putIfAbsent(genre, () => []);
    final existingIds = pool.map((t) => t.id).toSet();
    for (final t in newTracks) {
      if (!existingIds.contains(t.id)) {
        pool.add(t);
        existingIds.add(t.id);
      }
    }
  }

  /// Loads initial set of unplayed tracks for AOT queue.
  /// If tracks are already cached in _genrePools, selects immediately without blocking on network!
  Future<List<NcsTrack>> loadInitialTracks(String genre, {int count = 3}) async {
    final pool = _genrePools[genre] ?? [];

    // 1. If pool already has tracks, return immediately without blocking!
    if (pool.isNotEmpty) {
      var unplayed = _getUnplayedTracks(genre);
      if (unplayed.length < count) {
        // Recycle played tracks if unplayed exhausted
        for (final t in pool) {
          _playedTrackIds.remove(t.id);
        }
        unplayed = pool;
      }
      final selected = unplayed.take(count).toList();
      for (final t in selected) {
        _playedTrackIds.add(t.id);
      }
      // Top up pool in background if low
      if (pool.length < 10) {
        unawaited(fetchPage(genre, _nextPage(genre)));
      }
      return selected;
    }

    // 2. Only issue an HTTP scrape if the local pool for this genre is completely empty:
    final page = _nextPage(genre);
    await fetchPage(genre, page);

    var available = _getUnplayedTracks(genre);
    if (available.isEmpty && (_genrePools[genre]?.isNotEmpty ?? false)) {
      available = _genrePools[genre]!;
    }

    final result = available.take(count).toList();
    for (final t in result) {
      _playedTrackIds.add(t.id);
    }
    return result;
  }

  /// Fetches a single unplayed track without removing it from the master genre pool
  Future<NcsTrack?> fetchNextTrack(String genre) async {
    var unplayed = _getUnplayedTracks(genre);

    // If running low on unplayed tracks, prefetch next page in background
    if (unplayed.length < 3) {
      unawaited(fetchPage(genre, _nextPage(genre)));
    }

    if (unplayed.isEmpty) {
      // Scrape immediately if none unplayed
      final page = _nextPage(genre);
      final fetched = await fetchPage(genre, page);
      unplayed = fetched.where((t) => !_playedTrackIds.contains(t.id)).toList();

      // If still empty after scraping, recycle played tracks for this genre
      if (unplayed.isEmpty && (_genrePools[genre]?.isNotEmpty ?? false)) {
        final pool = _genrePools[genre]!;
        for (final t in pool) {
          _playedTrackIds.remove(t.id);
        }
        unplayed = pool;
      }
    }

    if (unplayed.isNotEmpty) {
      final selected = unplayed[_rng.nextInt(unplayed.length)];
      _playedTrackIds.add(selected.id);
      debugPrint('[NCS Scraper] Next track selected: "${selected.title}" by ${selected.artists}');
      return selected;
    }

    return null;
  }

  List<NcsTrack> _getUnplayedTracks(String genre) {
    final pool = _genrePools[genre] ?? [];
    return pool.where((t) => !_playedTrackIds.contains(t.id)).toList();
  }

  int _nextPage(String genre) {
    final fetched = _fetchedPages[genre] ?? {};
    for (int p = 1; p <= 12; p++) {
      if (!fetched.contains(p)) return p;
    }
    _fetchedPages[genre] = {};
    return 1;
  }

  void _markPageFetched(String genre, int page) {
    _fetchedPages.putIfAbsent(genre, () => {}).add(page);
  }
}

void unawaited(Future<void> future) => future.ignore();
