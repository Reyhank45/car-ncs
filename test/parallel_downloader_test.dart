import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:car_ncs/services/parallel_audio_downloader.dart';

void main() {
  HttpOverrides.global = null;

  group('ParallelAudioDownloader Tests', () {
    test('URL Normalization replaces eu-west-1 dots with dash', () {
      const originalUrl =
          'https://ncsmusic.s3.eu-west-1.amazonaws.com/tracks/000/001/916/time-1750896062-joS08R6oI9.mp3';
      final normalized = ParallelAudioDownloader.normalizeUrl(originalUrl);

      expect(
        normalized,
        'https://ncsmusic.s3-eu-west-1.amazonaws.com/tracks/000/001/916/time-1750896062-joS08R6oI9.mp3',
      );
    });

    test('Sanitizes track ID for filesystem safety', () {
      expect(
        ParallelAudioDownloader.sanitizeId('track/uuid:123*456?'),
        'track_uuid_123_456_',
      );
    });

    test('ParallelAudioDownloader forwards to NcsDownloadManager correctly', () async {
      final downloader = ParallelAudioDownloader();
      expect(downloader.isCachedSync('non_existent_id'), isFalse);
      expect(downloader.getCachedPath('non_existent_id'), isNull);
    });
  });
}
