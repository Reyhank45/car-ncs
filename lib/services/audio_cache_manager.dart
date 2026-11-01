import 'dart:io';
import '../models/ncs_track.dart';
import 'ncs_download_manager.dart';

/// Cache facade backed by NcsDownloadManager
class AudioCacheManager {
  static final AudioCacheManager _instance = AudioCacheManager._internal();
  factory AudioCacheManager() => _instance;
  AudioCacheManager._internal();

  final NcsDownloadManager _downloader = NcsDownloadManager();

  String? getCachedPath(String trackId) => _downloader.getCachedPath(trackId);
  Future<File?> getCachedFile(String trackId) => _downloader.getCachedFile(trackId);
  bool isCachedSync(String trackId) => _downloader.isCachedSync(trackId);
  bool isDownloading(String trackId) => _downloader.isDownloading(trackId);
  Future<File?> prefetchTrack(NcsTrack track) => _downloader.prefetchTrack(track);
}
