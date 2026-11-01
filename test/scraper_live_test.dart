import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:car_ncs/services/ncs_service.dart';

void main() {
  group('NcsService AOT Scraper Pipeline', () {
    test('fetchPage returns real scraped tracks from live AWS S3', () async {
      final svc = NcsService();
      final tracks = await svc.fetchPage('Trap', 1);
      debugPrint('=== SCRAPED TRAP TRACKS: ${tracks.length} ===');
      for (final t in tracks.take(3)) {
        debugPrint('  [${t.genreName}] ${t.title} — ${t.artists}');
        debugPrint('  Audio: ${t.audioUrl}');
        debugPrint('  Art: ${t.artworkUrl}');
      }
      expect(tracks.isNotEmpty, true);
      expect(tracks.first.audioUrl.startsWith('http'), true);
      expect(tracks.first.title.isNotEmpty, true);
    });

    test('loadInitialTracks returns at least 3 unplayed tracks for AOT queue', () async {
      final svc = NcsService();
      final tracks = await svc.loadInitialTracks('House', count: 3);
      debugPrint('=== AOT INITIAL HOUSE TRACKS: ${tracks.length} ===');
      for (int i = 0; i < tracks.length; i++) {
        debugPrint('  Index $i: ${tracks[i].title} (${tracks[i].audioUrl})');
      }
      expect(tracks.length, greaterThanOrEqualTo(3));
      for (final t in tracks) {
        expect(t.audioUrl.startsWith('http'), true);
      }
    });

    test('fetchNextTrack returns an unplayed track without pruning master pool', () async {
      final svc = NcsService();
      final track = await svc.fetchNextTrack('Dubstep');
      debugPrint('=== NEXT DUBSTEP TRACK: ===');
      debugPrint('  ${track?.title} by ${track?.artists}');
      debugPrint('  Audio: ${track?.audioUrl}');
      expect(track, isNotNull);
      expect(track!.audioUrl.startsWith('http'), true);

      // Verify master pool still contains the tracks for Viewport B
      final pool = svc.getGenrePool('Dubstep');
      expect(pool.isNotEmpty, true);
    });
  });
}
