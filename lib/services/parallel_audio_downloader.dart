import 'dart:io';
import '../models/ncs_track.dart';
import 'ncs_download_manager.dart';

/// Legacy alias forwarding to NcsDownloadManager to preserve interface compatibility.
class ParallelAudioDownloader {
  static final ParallelAudioDownloader _instance = ParallelAudioDownloader._internal();
  factory ParallelAudioDownloader() => _instance;
  ParallelAudioDownloader._internal();

  final NcsDownloadManager _manager = NcsDownloadManager();

  static const Map<String, String> defaultHeaders = NcsDownloadManager.defaultHeaders;
  static String normalizeUrl(String url) => NcsDownloadManager.normalizeUrl(url);
  static String sanitizeId(String trackId) => NcsDownloadManager.sanitizeId(trackId);

  Future<Directory?> getCacheDirectory() => _manager.getCacheDirectory();
  String? getCachedPath(String trackId) => _manager.getCachedPath(trackId);
  Future<File?> getCachedFile(String trackId) => _manager.getCachedFile(trackId);
  bool isCachedSync(String trackId) => _manager.isCachedSync(trackId);
  bool isDownloading(String trackId) => _manager.isDownloading(trackId);
  Future<void> cancelActiveDownload() => _manager.cancelActiveDownload();
  Future<File?> downloadTrackParallel(String url, String trackId) =>
      _manager.downloadTrack(url, trackId);
  Future<File?> prefetchTrack(NcsTrack track) => _manager.prefetchTrack(track);
}
