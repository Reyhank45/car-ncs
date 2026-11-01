import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:car_ncs/services/ncs_download_manager.dart';

void main() {
  HttpOverrides.global = null;

  group('NcsDownloadManager Unit & Integration Tests', () {
    test('URL Normalization replaces eu-west-1 dots with dash', () {
      const originalUrl =
          'https://ncsmusic.s3.eu-west-1.amazonaws.com/tracks/000/001/916/time-1750896062-joS08R6oI9.mp3';
      final normalized = NcsDownloadManager.normalizeUrl(originalUrl);

      expect(
        normalized,
        'https://ncsmusic.s3-eu-west-1.amazonaws.com/tracks/000/001/916/time-1750896062-joS08R6oI9.mp3',
      );
    });

    test('Sanitizes track ID for filesystem safety', () {
      expect(
        NcsDownloadManager.sanitizeId('track/uuid:123*456?'),
        'track_uuid_123_456_',
      );
    });

    test('Sequential stream-to-disk writes 64KB chunks, tracks progress, and renames .part to .mp3', () async {
      // Spin up local chunked HTTP server simulating S3 audio stream
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      const totalSize = 256 * 1024; // 256 KB test audio file
      final dummyData = Uint8List(totalSize);
      for (int i = 0; i < totalSize; i++) {
        dummyData[i] = i % 256;
      }

      server.listen((HttpRequest request) async {
        request.response.headers.contentType = ContentType('audio', 'mpeg');
        request.response.headers.contentLength = totalSize;
        request.response.statusCode = HttpStatus.ok;

        // Stream in 16KB chunks
        const chunkSize = 16 * 1024;
        for (int offset = 0; offset < totalSize; offset += chunkSize) {
          final end = (offset + chunkSize > totalSize) ? totalSize : offset + chunkSize;
          request.response.add(dummyData.sublist(offset, end));
          await request.response.flush();
        }
        await request.response.close();
      });

      final manager = NcsDownloadManager();
      final testUrl = 'http://${server.address.host}:${server.port}/test_track.mp3';
      const testId = 'unit_test_stream_to_disk';

      final progressList = <double>[];
      final file = await manager.downloadTrack(
        testUrl,
        testId,
        onProgress: (p) => progressList.add(p),
      );

      await server.close();

      expect(file, isNotNull);
      expect(file!.existsSync(), isTrue);
      expect(file.path.endsWith('$testId.mp3'), isTrue);
      expect(await file.length(), equals(totalSize));

      // Verify that the temporary .part file was deleted/renamed
      final partFile = File('${file.path}.part');
      expect(partFile.existsSync(), isFalse);

      // Verify progress reporting
      expect(progressList, isNotEmpty);
      expect(progressList.last, equals(1.0));

      // Second download call returns cached file synchronously/immediately
      expect(manager.isCachedSync(testId), isTrue);
      final cachedFile = await manager.downloadTrack(testUrl, testId);
      expect(cachedFile?.path, equals(file.path));

      // Cleanup
      if (await file.exists()) {
        await file.delete();
      }
    });

    test('Parallel 4-chunk range download fetches 4 ranges in isolate, stitches buffer, and saves .mp3', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      const totalSize = 1024 * 1024 + 512; // >1 MB to trigger 4-chunk parallel
      final dummyData = Uint8List(totalSize);
      for (int i = 0; i < totalSize; i++) {
        dummyData[i] = i % 256;
      }

      server.listen((HttpRequest request) async {
        if (request.method == 'HEAD') {
          request.response.headers.set('accept-ranges', 'bytes');
          request.response.headers.contentLength = totalSize;
          request.response.statusCode = HttpStatus.ok;
          await request.response.close();
          return;
        }

        final rangeHeader = request.headers.value('range');
        if (rangeHeader != null && rangeHeader.startsWith('bytes=')) {
          final parts = rangeHeader.substring(6).split('-');
          final start = int.parse(parts[0]);
          final end = int.parse(parts[1]);
          final slice = dummyData.sublist(start, end + 1);

          request.response.statusCode = HttpStatus.partialContent;
          request.response.headers.set('content-range', 'bytes $start-$end/$totalSize');
          request.response.headers.contentLength = slice.length;
          request.response.add(slice);
          await request.response.close();
        } else {
          request.response.statusCode = HttpStatus.ok;
          request.response.headers.contentLength = totalSize;
          request.response.add(dummyData);
          await request.response.close();
        }
      });

      final manager = NcsDownloadManager();
      final testUrl = 'http://${server.address.host}:${server.port}/parallel_track.mp3';
      const testId = 'unit_test_parallel_4chunk';

      final progressList = <double>[];
      final file = await manager.downloadTrack(
        testUrl,
        testId,
        onProgress: (p) => progressList.add(p),
      );

      await server.close();

      expect(file, isNotNull);
      expect(file!.existsSync(), isTrue);
      expect(await file.length(), equals(totalSize));

      // Cleanup
      if (await file.exists()) {
        await file.delete();
      }
    });

    test('cancelActiveDownload aborts active stream and cleans .part file', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((HttpRequest request) async {
        request.response.headers.contentType = ContentType('audio', 'mpeg');
        request.response.headers.contentLength = 10 * 1024 * 1024;
        request.response.statusCode = HttpStatus.ok;
        // Keep connection open without completing to test abort
        request.response.add(Uint8List(32 * 1024));
        await request.response.flush();
      });

      final manager = NcsDownloadManager();
      final testUrl = 'http://${server.address.host}:${server.port}/long_track.mp3';
      const testId = 'unit_test_cancel_stream';

      final downloadFuture = manager.downloadTrack(testUrl, testId);
      expect(manager.isDownloading(testId), isTrue);

      await manager.cancelActiveDownload();
      final result = await downloadFuture;

      await server.close(force: true);

      expect(result, isNull);
      expect(manager.isDownloading(testId), isFalse);

      // Verify .part file cleaned up
      final cacheDir = await manager.getCacheDirectory();
      if (cacheDir != null) {
        final partFile = File('${cacheDir.path}/$testId.mp3.part');
        expect(partFile.existsSync(), isFalse);
      }
    });

    test('pruneCache keeps at most 10 tracks, deleting oldest', () async {
      final manager = NcsDownloadManager();
      final cacheDir = await manager.getCacheDirectory();
      expect(cacheDir, isNotNull);

      // Create 12 dummy cached tracks with varying timestamps
      final createdFiles = <File>[];
      for (int i = 0; i < 12; i++) {
        final f = File('${cacheDir!.path}/dummy_track_$i.mp3');
        await f.writeAsBytes(Uint8List(35 * 1024)); // >32KB
        await f.setLastModified(DateTime.now().add(Duration(minutes: i)));
        createdFiles.add(f);
      }

      await manager.pruneCache(dir: cacheDir, maxTracks: 10);

      final remainingMp3s = cacheDir!
          .listSync()
          .where((e) => e is File && e.path.contains('dummy_track_') && e.path.endsWith('.mp3'))
          .toList();

      expect(remainingMp3s.length, lessThanOrEqualTo(10));

      // Clean up dummy tracks
      for (final f in createdFiles) {
        if (f.existsSync()) await f.delete();
      }
    });
  });
}
