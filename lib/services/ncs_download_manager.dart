import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../models/ncs_track.dart';

class _DownloadJob {
  final String url;
  final String targetPath;
  final String partPath;
  final Map<String, String> headers;
  final SendPort replyPort;

  _DownloadJob({
    required this.url,
    required this.targetPath,
    required this.partPath,
    required this.headers,
    required this.replyPort,
  });
}

class _DownloadProgressMsg {
  final int receivedBytes;
  final int totalBytes;

  _DownloadProgressMsg(this.receivedBytes, this.totalBytes);
}

class _DownloadResultMsg {
  final bool success;
  final String? filePath;
  final String? error;

  _DownloadResultMsg({required this.success, this.filePath, this.error});
}

/// Hybrid high-speed 4-chunk parallel range engine with safe background isolate assembly.
/// Downloads tracks using 4 concurrent HTTP range connections (~210 KiB/s), stitches them
/// in a background isolate, and seals the final .mp3 before handing to just_audio.
class NcsDownloadManager {
  static final NcsDownloadManager _instance = NcsDownloadManager._internal();
  factory NcsDownloadManager() => _instance;
  NcsDownloadManager._internal();

  static const Map<String, String> defaultHeaders = {
    'User-Agent':
        'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36',
    'Referer': 'https://ncs.io/',
    'Origin': 'https://ncs.io',
  };

  Directory? _cacheDir;

  // Active in-flight isolate reference for instant socket termination
  Isolate? _activeIsolate;
  ReceivePort? _activePort;
  String? _activeTrackId;
  Completer<File?>? _activeCompleter;

  // Download progress state (0.0 to 1.0)
  final ValueNotifier<double> progressNotifier = ValueNotifier<double>(0.0);
  final StreamController<double> _progressController = StreamController<double>.broadcast();
  Stream<double> get progressStream => _progressController.stream;
  double get currentProgress => progressNotifier.value;

  // Cache of in-flight download futures to prevent duplicate concurrent downloads
  final Map<String, Future<File?>> _activeDownloads = {};

  /// Normalizes S3 bucket hostname to avoid direct origin DNS latency pitfalls
  static String normalizeUrl(String url) {
    return url.replaceAll(
      'ncsmusic.s3.eu-west-1.amazonaws.com',
      'ncsmusic.s3-eu-west-1.amazonaws.com',
    );
  }

  /// Sanitizes track ID for filesystem filename safety
  static String sanitizeId(String trackId) {
    return trackId.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
  }

  /// Resolves the local cache directory (<tempDir>/ncs_cache)
  Future<Directory?> getCacheDirectory() async {
    if (kIsWeb) return null;
    if (_cacheDir != null) return _cacheDir;
    try {
      final tempDir = await getTemporaryDirectory();
      final dir = Directory('${tempDir.path}/ncs_cache');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      _cacheDir = dir;
      return dir;
    } catch (e) {
      try {
        final dir = Directory('${Directory.systemTemp.path}/ncs_cache');
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        _cacheDir = dir;
        return dir;
      } catch (fallbackError) {
        debugPrint('[NcsDownloadManager] Error accessing cache directory: $fallbackError');
        return null;
      }
    }
  }

  /// Returns synchronous local file path if cached and valid
  String? getCachedPath(String trackId) {
    if (kIsWeb || _cacheDir == null) return null;
    final path = '${_cacheDir!.path}/${sanitizeId(trackId)}.mp3';
    try {
      final file = File(path);
      if (file.existsSync() && file.lengthSync() > 32 * 1024) {
        return path;
      }
    } catch (_) {}
    return null;
  }

  /// Checks synchronously if a track is cached on local disk (>32KB)
  bool isCachedSync(String trackId) {
    if (kIsWeb || _cacheDir == null) return false;
    final file = File('${_cacheDir!.path}/${sanitizeId(trackId)}.mp3');
    try {
      return file.existsSync() && file.lengthSync() > 32 * 1024;
    } catch (_) {
      return false;
    }
  }

  /// Asynchronously checks and returns cached File
  Future<File?> getCachedFile(String trackId) async {
    if (kIsWeb) return null;
    final dir = await getCacheDirectory();
    if (dir == null) return null;
    final file = File('${dir.path}/${sanitizeId(trackId)}.mp3');
    if (await file.exists()) {
      try {
        final len = await file.length();
        if (len > 32 * 1024) {
          return file;
        } else {
          await file.delete();
        }
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  bool isDownloading(String trackId) {
    return _activeDownloads.containsKey(trackId) || _activeTrackId == trackId;
  }

  void _updateProgress(double progress) {
    final clamped = progress.clamp(0.0, 1.0);
    progressNotifier.value = clamped;
    _progressController.add(clamped);
  }

  /// Immediately terminates any in-flight background isolate and HTTP sockets,
  /// cleans up partial files, and resets progress indicator to 0% immediately.
  Future<void> cancelActiveDownload() async {
    final isolateToKill = _activeIsolate;
    final portToClose = _activePort;
    final completerToCancel = _activeCompleter;
    final trackIdToCancel = _activeTrackId;

    _activeIsolate = null;
    _activePort = null;
    _activeCompleter = null;
    _activeTrackId = null;

    if (trackIdToCancel != null) {
      _activeDownloads.remove(trackIdToCancel);
    }
    _updateProgress(0.0);

    if (isolateToKill != null) {
      debugPrint('[NcsDownloadManager] Instantly terminating isolate for "$trackIdToCancel"');
      isolateToKill.kill(priority: Isolate.immediate);
    }
    portToClose?.close();

    if (completerToCancel != null && !completerToCancel.isCompleted) {
      completerToCancel.complete(null);
    }

    await cleanLeftoverPartFiles();
  }

  /// Cleans up any leftover .part files in the cache directory
  Future<void> cleanLeftoverPartFiles() async {
    if (kIsWeb) return;
    try {
      final dir = await getCacheDirectory();
      if (dir == null) return;
      final list = await dir.list().toList();
      for (final entity in list) {
        if (entity is File &&
            (entity.path.endsWith('.part') ||
                entity.path.contains('.part_') ||
                entity.path.contains('.tmp_'))) {
          try {
            await entity.delete();
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('[NcsDownloadManager] Error cleaning part files: $e');
    }
  }

  /// Downloads a track using 4 parallel HTTP range connections in a background isolate:
  /// - Probe track size with quick HEAD request
  /// - Divide file into 4 parallel byte-ranges (`bytes=start-end`)
  /// - Run chunk fetch and byte stitching in Isolate to keep UI thread completely free
  /// - Flushes complete buffer to `<trackId>.mp3` and returns File
  Future<File?> downloadTrack(
    String rawUrl,
    String trackId, {
    void Function(double progress)? onProgress,
  }) {
    if (kIsWeb) return Future.value(null);

    // Return in-flight future if already downloading this exact track
    if (_activeDownloads.containsKey(trackId)) {
      return _activeDownloads[trackId]!;
    }

    // Cancel any previous download to dedicate 100% bandwidth
    final prevTrack = _activeTrackId;
    if (prevTrack != null && prevTrack != trackId) {
      cancelActiveDownload();
    }

    final completer = Completer<File?>();
    _activeCompleter = completer;
    _activeTrackId = trackId;
    _activeDownloads[trackId] = completer.future;

    _executeParallelDownload(rawUrl, trackId, completer, onProgress);

    return completer.future;
  }

  Future<void> _executeParallelDownload(
    String rawUrl,
    String trackId,
    Completer<File?> completer,
    void Function(double progress)? onProgress,
  ) async {
    final sanitizedId = sanitizeId(trackId);
    final dir = await getCacheDirectory();
    if (dir == null) {
      _activeDownloads.remove(trackId);
      if (!completer.isCompleted) completer.complete(null);
      return;
    }

    final targetFile = File('${dir.path}/$sanitizedId.mp3');

    // Return immediately if already cached and valid (>32KB)
    if (await targetFile.exists()) {
      try {
        final len = await targetFile.length();
        if (len > 32 * 1024) {
          _updateProgress(1.0);
          onProgress?.call(1.0);
          _activeDownloads.remove(trackId);
          if (!completer.isCompleted) completer.complete(targetFile);
          return;
        }
      } catch (_) {}
    }

    if (_activeCompleter != completer) {
      return;
    }

    final partFile = File('${targetFile.path}.part');
    _updateProgress(0.0);

    // Clean prior lingering part file
    try {
      if (await partFile.exists()) await partFile.delete();
    } catch (_) {}

    final receivePort = ReceivePort();
    _activePort = receivePort;

    final job = _DownloadJob(
      url: normalizeUrl(rawUrl),
      targetPath: targetFile.path,
      partPath: partFile.path,
      headers: defaultHeaders,
      replyPort: receivePort.sendPort,
    );

    try {
      final isolate = await Isolate.spawn(
        _isolateParallelDownloadWorker,
        job,
        errorsAreFatal: true,
      );

      // Check if cancellation occurred while spawning
      if (_activeCompleter != completer) {
        isolate.kill(priority: Isolate.immediate);
        receivePort.close();
        return;
      }
      _activeIsolate = isolate;

      receivePort.listen((dynamic message) {
        if (message is _DownloadProgressMsg) {
          if (message.totalBytes > 0) {
            final p = (message.receivedBytes / message.totalBytes).clamp(0.0, 1.0);
            _updateProgress(p);
            onProgress?.call(p);
          }
        } else if (message is _DownloadResultMsg) {
          isolate.kill(priority: Isolate.immediate);
          receivePort.close();
          if (_activeIsolate == isolate) {
            _activeIsolate = null;
            _activePort = null;
            _activeTrackId = null;
            _activeCompleter = null;
          }

          if (message.success && message.filePath != null) {
            final resultFile = File(message.filePath!);
            _updateProgress(1.0);
            onProgress?.call(1.0);
            unawaited(pruneCache(dir: dir, maxTracks: 10));
            if (!completer.isCompleted) completer.complete(resultFile);
          } else {
            debugPrint('[NcsDownloadManager] Download failed: ${message.error}');
            if (!completer.isCompleted) completer.complete(null);
          }
        }
      });
    } catch (e) {
      debugPrint('[NcsDownloadManager] Isolate spawn error: $e');
      receivePort.close();
      if (!completer.isCompleted) completer.complete(null);
    } finally {
      _activeDownloads.remove(trackId);
    }
  }

  /// Dedicated background Isolate worker:
  /// Performs HEAD probe, 4-chunk parallel range GETs, sequential memory stitching,
  /// atomic disk write, and sends real-time aggregate byte progress to main thread.
  static void _isolateParallelDownloadWorker(_DownloadJob job) async {
    final uri = Uri.parse(job.url);
    final targetFile = File(job.targetPath);
    final partFile = File(job.partPath);

    try {
      // 1. Quick HEAD probe (6-second timeout)
      int? contentLength;
      bool supportsRanges = false;

      try {
        final headResponse = await http
            .head(uri, headers: job.headers)
            .timeout(const Duration(seconds: 6));

        if (headResponse.statusCode == 200) {
          final cl = headResponse.headers['content-length'];
          if (cl != null) contentLength = int.tryParse(cl);
          final ar = headResponse.headers['accept-ranges'];
          supportsRanges = ar != null && ar.toLowerCase().contains('bytes');
        }
      } catch (e) {
        debugPrint('[IsolateWorker] HEAD probe error: $e');
      }

      // Check if target file already exists with exact size
      if (contentLength != null && await targetFile.exists()) {
        final len = await targetFile.length();
        if (len == contentLength) {
          job.replyPort.send(_DownloadResultMsg(
            success: true,
            filePath: targetFile.path,
          ));
          return;
        }
      }

      // 2. Parallel 4-chunk download if ranges are supported and file is >= 1MB
      if (contentLength != null && contentLength >= 1024 * 1024 && supportsRanges) {
        final totalLength = contentLength;
        final chunkSize = (totalLength / 4).ceil();
        final chunks = <({int index, int start, int end})>[];

        for (int i = 0; i < 4; i++) {
          final start = i * chunkSize;
          final end = (i == 3) ? totalLength - 1 : (start + chunkSize - 1);
          chunks.add((index: i, start: start, end: end));
        }

        final chunkReceived = List<int>.filled(4, 0);
        int lastProgressSent = 0;

        final downloadFutures = chunks.map((chunk) async {
          final rangeHeader = 'bytes=${chunk.start}-${chunk.end}';
          final headers = {
            ...job.headers,
            'Range': rangeHeader,
          };

          final request = http.Request('GET', uri);
          request.headers.addAll(headers);
          final client = http.Client();

          try {
            final streamedResponse = await client.send(request).timeout(const Duration(seconds: 45));

            if (streamedResponse.statusCode != 206 && streamedResponse.statusCode != 200) {
              throw HttpException('Range HTTP ${streamedResponse.statusCode} for $rangeHeader');
            }

            final builder = BytesBuilder(copy: false);
            await for (final slice in streamedResponse.stream) {
              builder.add(slice);
              chunkReceived[chunk.index] += slice.length;

              final totalReceived = chunkReceived.fold<int>(0, (a, b) => a + b);
              // Report progress every ~64KB aggregate bytes
              if (totalReceived - lastProgressSent >= 64 * 1024) {
                lastProgressSent = totalReceived;
                job.replyPort.send(_DownloadProgressMsg(totalReceived, totalLength));
              }
            }

            return builder.takeBytes();
          } finally {
            client.close();
          }
        }).toList();

        final results = await Future.wait(downloadFutures);

        // Send final 100% progress
        job.replyPort.send(_DownloadProgressMsg(totalLength, totalLength));

        // Stitch 4 chunks sequentially to partFile
        final sink = partFile.openWrite();
        for (final slice in results) {
          sink.add(slice);
        }
        await sink.flush();
        await sink.close();

        final finalSize = await partFile.length();
        if (finalSize != totalLength) {
          throw HttpException('Assembled size mismatch: $finalSize vs expected $totalLength');
        }

        if (await targetFile.exists()) {
          await targetFile.delete();
        }
        await partFile.rename(targetFile.path);

        job.replyPort.send(_DownloadResultMsg(
          success: true,
          filePath: targetFile.path,
        ));
        return;
      }

      // 3. Fallback: single-stream GET in background isolate
      final client = http.Client();
      try {
        final request = http.Request('GET', uri);
        request.headers.addAll(job.headers);
        final streamedResponse = await client.send(request).timeout(const Duration(seconds: 40));

        if (streamedResponse.statusCode != 200) {
          throw HttpException('Stream failed with HTTP ${streamedResponse.statusCode}');
        }

        final totalBytes = streamedResponse.contentLength ?? 0;
        int receivedBytes = 0;
        final sink = partFile.openWrite();
        const bufferThreshold = 64 * 1024;
        final chunkBuffer = BytesBuilder(copy: false);

        await for (final chunk in streamedResponse.stream) {
          chunkBuffer.add(chunk);
          receivedBytes += chunk.length;

          if (chunkBuffer.length >= bufferThreshold) {
            sink.add(chunkBuffer.takeBytes());
            if (totalBytes > 0) {
              job.replyPort.send(_DownloadProgressMsg(receivedBytes, totalBytes));
            }
          }
        }

        if (chunkBuffer.isNotEmpty) {
          sink.add(chunkBuffer.takeBytes());
          if (totalBytes > 0) {
            job.replyPort.send(_DownloadProgressMsg(receivedBytes, totalBytes));
          }
        }

        await sink.flush();
        await sink.close();

        final downloadedSize = await partFile.length();
        if (downloadedSize > 32 * 1024) {
          if (await targetFile.exists()) await targetFile.delete();
          await partFile.rename(targetFile.path);

          job.replyPort.send(_DownloadResultMsg(
            success: true,
            filePath: targetFile.path,
          ));
          return;
        }

        throw HttpException('Stream too small ($downloadedSize bytes)');
      } finally {
        client.close();
      }
    } catch (e) {
      try {
        if (await partFile.exists()) await partFile.delete();
      } catch (_) {}
      job.replyPort.send(_DownloadResultMsg(success: false, error: e.toString()));
    }
  }

  /// Convenience method for prefetching a track
  Future<File?> prefetchTrack(NcsTrack track, {void Function(double progress)? onProgress}) {
    return downloadTrack(track.audioUrl, track.id, onProgress: onProgress);
  }

  /// Keeps the local cache directory capped at 10 tracks max (auto-deletes oldest .mp3 files)
  Future<void> pruneCache({Directory? dir, int maxTracks = 10}) async {
    if (kIsWeb) return;
    try {
      final cacheDir = dir ?? await getCacheDirectory();
      if (cacheDir == null) return;

      final files = await cacheDir
          .list()
          .where((e) => e is File && e.path.endsWith('.mp3'))
          .cast<File>()
          .toList();

      if (files.length <= maxTracks) return;

      final entries = <({File file, DateTime modified, int size})>[];
      for (final f in files) {
        final stat = await f.stat();
        entries.add((file: f, modified: stat.modified, size: stat.size));
      }

      entries.sort((a, b) => a.modified.compareTo(b.modified));

      while (entries.length > maxTracks) {
        final oldest = entries.removeAt(0);
        try {
          await oldest.file.delete();
          debugPrint('[NcsDownloadManager] Pruned oldest cached track: ${oldest.file.path}');
        } catch (e) {
          debugPrint('[NcsDownloadManager] Error deleting pruned track: $e');
        }
      }
    } catch (e) {
      debugPrint('[NcsDownloadManager] Cache pruning error: $e');
    }
  }

  void dispose() {
    cancelActiveDownload();
    progressNotifier.dispose();
    _progressController.close();
  }
}
