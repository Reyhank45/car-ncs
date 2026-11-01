import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/ncs_track.dart';
import '../providers/audio_provider.dart';
import '../providers/safety_provider.dart';
import '../theme/car_theme.dart';
import 'ncs_logo.dart';

class PersistentDeckCol2 extends StatefulWidget {
  const PersistentDeckCol2({super.key});

  @override
  State<PersistentDeckCol2> createState() => _PersistentDeckCol2State();
}

class _PersistentDeckCol2State extends State<PersistentDeckCol2> {
  bool _isTitleExpanded = false;
  Timer? _collapseTimer;

  void _onTitleTapped() {
    setState(() {
      _isTitleExpanded = true;
    });

    _collapseTimer?.cancel();
    _collapseTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _isTitleExpanded = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _collapseTimer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final audio = context.watch<AudioProvider>();
    // Select only motion lock status to avoid rebuilding on telemetry stream ticks
    final bool isLocked = context.select<SafetyProvider, bool>((s) => s.isMotionLocked);
    final track = audio.currentTrack;
    final genreColor = track != null
        ? track.genreColor
        : CarColors.genreDefault;
    final bool isOffline = audio.isOfflineRetrying;
    final bool isPreCaching = audio.isPreCaching;

    // AOT Artwork Caching: Pre-cache upcoming and current track artwork in RAM at 400x400
    final nextTrack = audio.nextTrack;
    if (nextTrack != null && nextTrack.artworkUrl.startsWith('http')) {
      precacheImage(
        ResizeImage(NetworkImage(nextTrack.artworkUrl), width: 400, height: 400),
        context,
      ).ignore();
    }
    if (track != null && track.artworkUrl.startsWith('http')) {
      precacheImage(
        ResizeImage(NetworkImage(track.artworkUrl), width: 400, height: 400),
        context,
      ).ignore();
    }

    return Container(
      decoration: const BoxDecoration(
        color: CarColors.cardContainer,
        border: Border(
          right: BorderSide(
            color: CarColors.cardBorder,
            width: 1.0,
          ),
        ),
      ),
      child: SafeArea(
        left: false,
        right: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Top Bar: NCS Vector badge + Connectivity indicator + Pre-caching / Offline Badge
              _buildTopBar(genreColor, isOffline, isPreCaching, audio.cachingProgress),

              const SizedBox(height: 8),

              // 2. Album Art & Track Info
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AlbumArtWidget(track: track, genreColor: genreColor),
                        const SizedBox(height: 10),
                        _buildTitleArtistBlock(track, genreColor, isOffline),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 6),

              // 3. Scrubber / Progress bar
              _buildScrubber(audio, isLocked),

              const SizedBox(height: 8),

              // 4. Transport Controls
              _buildTransportControls(audio),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(Color genreColor, bool isOffline, bool isPreCaching, double cachingProgress) {
    final progressPercent = (cachingProgress * 100).toInt();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            NcsLogo(
              size: 22,
              glowColor: genreColor,
            ),
            const SizedBox(width: 6),
            Text(
              'CAR NCS',
              style: GoogleFonts.robotoMono(
                color: CarColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        if (isPreCaching)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: CarColors.secondaryCyan.withOpacity(0.18),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: CarColors.secondaryCyan, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 8,
                  height: 8,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    valueColor: AlwaysStoppedAnimation<Color>(CarColors.secondaryCyan),
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  '[CACHING: $progressPercent%]',
                  style: GoogleFonts.robotoMono(
                    color: CarColors.secondaryCyan,
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          )
        else if (isOffline)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: CarColors.amberWarning.withOpacity(0.18),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: CarColors.amberWarning, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 8,
                  height: 8,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    valueColor: AlwaysStoppedAnimation<Color>(CarColors.amberWarning),
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  '[OFFLINE: RETRYING STREAM...]',
                  style: GoogleFonts.robotoMono(
                    color: CarColors.amberWarning,
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: CarColors.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: CarColors.cardBorder,
              width: 1,
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.bluetooth_connected_rounded,
                size: 13,
                color: CarColors.secondaryCyan,
              ),
              SizedBox(width: 4),
              Icon(
                Icons.volume_up_rounded,
                size: 13,
                color: CarColors.primaryAccent,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTitleArtistBlock(NcsTrack? track, Color genreColor, bool isOffline) {
    final title = track?.title ?? (isOffline ? 'OFFLINE: RETRYING...' : 'PRELOADING NCS STREAM...');
    final artists = track?.artists ?? (isOffline ? 'Connecting to NCS server' : 'Scraping live AWS S3 audio...');
    final genre = track?.genreName ?? 'NCS';

    return GestureDetector(
      onTap: _onTitleTapped,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: _isTitleExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.robotoMono(
                color: CarColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
            secondChild: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: CarColors.background,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: CarColors.cardBorder),
              ),
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: GoogleFonts.robotoMono(
                  color: CarColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  artists,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.robotoMono(
                    color: CarColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: genreColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: genreColor.withOpacity(0.8),
                    width: 1,
                  ),
                ),
                child: Text(
                  genre.toUpperCase(),
                  style: GoogleFonts.robotoMono(
                    color: genreColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScrubber(AudioProvider audio, bool isMotionLocked) {
    final progress = audio.progressRatio;
    final posStr = _formatDuration(audio.currentPosition);
    final durStr = _formatDuration(audio.duration);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                posStr,
                style: GoogleFonts.robotoMono(
                  fontSize: 11,
                  color: CarColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (isMotionLocked)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: CarColors.amberWarning.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: CarColors.amberWarning,
                      width: 1,
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock_rounded,
                        size: 11,
                        color: CarColors.amberWarning,
                      ),
                      SizedBox(width: 3),
                      Text(
                        'LOCKED (IN MOTION)',
                        style: TextStyle(
                          color: CarColors.amberWarning,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              Text(
                durStr,
                style: GoogleFonts.robotoMono(
                  fontSize: 11,
                  color: CarColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (isMotionLocked) ...[
          Container(
            height: 18,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Stack(
                children: [
                  Container(color: const Color(0xFF22222A)),
                  FractionallySizedBox(
                    widthFactor: progress,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [CarColors.primaryAccent, CarColors.secondaryCyan],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ] else ...[
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 4,
              activeTrackColor: CarColors.primaryAccent,
              inactiveTrackColor: const Color(0xFF22222A),
              thumbColor: CarColors.primaryAccent,
              overlayColor: CarColors.primaryAccent.withOpacity(0.2),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.5),
              trackShape: const RectangularSliderTrackShape(),
            ),
            child: Slider(
              value: progress,
              onChanged: (val) {
                final newMillis = (val * audio.duration.inMilliseconds).round();
                audio.seek(Duration(milliseconds: newMillis));
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTransportControls(AudioProvider audio) {
    final isPreCaching = audio.isPreCaching;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildTactileButton(
          size: 72,
          icon: Icons.skip_previous_rounded,
          iconSize: 36,
          backgroundColor: const Color(0xFF1A1A22),
          foregroundColor: CarColors.textPrimary,
          onTap: audio.playPrevious,
        ),
        _buildTactileButton(
          size: 84,
          icon: audio.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          iconSize: 46,
          backgroundColor: CarColors.primaryAccent,
          foregroundColor: const Color(0xFF0A0A0C),
          isPrimaryGlow: true,
          onTap: audio.togglePlayPause,
        ),
        _buildTactileButton(
          size: 72,
          icon: Icons.skip_next_rounded,
          iconSize: 36,
          backgroundColor: const Color(0xFF1A1A22),
          foregroundColor: CarColors.textPrimary,
          onTap: audio.playNext,
        ),
      ],
    );
  }

  Widget _buildTactileButton({
    required double size,
    required IconData icon,
    required double iconSize,
    required Color backgroundColor,
    required Color foregroundColor,
    required VoidCallback onTap,
    bool isPrimaryGlow = false,
  }) {
    return SizedBox(
      width: size,
      height: size,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(size / 2),
          splashColor: foregroundColor.withOpacity(0.2),
          child: Container(
            decoration: BoxDecoration(
              color: backgroundColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: isPrimaryGlow
                    ? CarColors.primaryAccent
                    : CarColors.cardBorder,
                width: 1.5,
              ),
              boxShadow: isPrimaryGlow
                  ? [
                      BoxShadow(
                        color: CarColors.primaryAccent.withOpacity(0.4),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
            ),
            child: Center(
              child: Icon(
                icon,
                size: iconSize,
                color: foregroundColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dedicated Album Art Widget wrapped with RepaintBoundary to avoid GPU re-rasterization
/// on sensor/GPS telemetry stream ticks.
class AlbumArtWidget extends StatelessWidget {
  final NcsTrack? track;
  final Color genreColor;

  const AlbumArtWidget({
    super.key,
    required this.track,
    required this.genreColor,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        width: 130,
        height: 130,
        decoration: BoxDecoration(
          color: const Color(0xFF1B1B22),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: genreColor.withOpacity(0.4),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: genreColor.withOpacity(0.2),
              blurRadius: 18,
              spreadRadius: 2,
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.6),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (track?.artworkUrl != null && track!.artworkUrl.startsWith('http'))
              Image.network(
                track!.artworkUrl,
                fit: BoxFit.cover,
                cacheWidth: 400,
                cacheHeight: 400,
                errorBuilder: (_, __, ___) => _buildAlbumFallback(track, genreColor),
              )
            else
              _buildAlbumFallback(track, genreColor),

            Positioned(
              bottom: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: CarColors.background.withOpacity(0.85),
                  shape: BoxShape.circle,
                  border: Border.all(color: genreColor, width: 1.5),
                ),
                child: NcsLogo(size: 16, glowColor: genreColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlbumFallback(NcsTrack? track, Color genreColor) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            genreColor.withOpacity(0.25),
            const Color(0xFF0D0D12),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            NcsLogo(size: 40, glowColor: genreColor),
            const SizedBox(height: 6),
            Text(
              track?.genreName.toUpperCase() ?? 'NCS',
              style: GoogleFonts.robotoMono(
                color: genreColor,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
