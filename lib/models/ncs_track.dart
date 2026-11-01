import 'package:flutter/material.dart';

class NcsTrack {
  final String id;
  final String title;
  final String artists;
  final String audioUrl;
  final String artworkUrl;
  final String genreName;
  final String genreColorHex;
  final Duration duration;

  const NcsTrack({
    required this.id,
    required this.title,
    required this.artists,
    required this.audioUrl,
    required this.artworkUrl,
    required this.genreName,
    required this.genreColorHex,
    this.duration = const Duration(minutes: 3, seconds: 20),
  });

  Color get genreColor {
    try {
      final hex = genreColorHex.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return const Color(0xFF00FF88);
    }
  }

  static String mapGenreToHex(String genre) {
    final lower = genre.toLowerCase();
    if (lower.contains('trap')) return '#00FFA3';      // Mint
    if (lower.contains('house')) return '#FFE600';     // Yellow
    if (lower.contains('dubstep')) return '#00E5FF';   // Cyan
    if (lower.contains('dnb') || lower.contains('drum')) return '#FF2A55'; // Red
    if (lower.contains('chill') || lower.contains('peach')) return '#FF9E79'; // Peach
    if (lower.contains('surprise') || lower.contains('all')) return '#FFFFFF'; // White
    return '#00FFA3';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'artists': artists,
    'audioUrl': audioUrl,
    'artworkUrl': artworkUrl,
    'genreName': genreName,
    'genreColorHex': genreColorHex,
    'durationSeconds': duration.inSeconds,
  };

  factory NcsTrack.fromJson(Map<String, dynamic> json) => NcsTrack(
    id: json['id'] as String? ?? 'ncs-${DateTime.now().millisecondsSinceEpoch}',
    title: json['title'] as String? ?? 'Unknown Title',
    artists: json['artists'] as String? ?? 'NCS Artist',
    audioUrl: json['audioUrl'] as String? ?? '',
    artworkUrl: json['artworkUrl'] as String? ?? '',
    genreName: json['genreName'] as String? ?? 'Trap',
    genreColorHex: json['genreColorHex'] as String? ?? '#00FFA3',
    duration: Duration(seconds: json['durationSeconds'] as int? ?? 200),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NcsTrack && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
