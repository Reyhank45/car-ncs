import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/ncs_track.dart';
import '../providers/audio_provider.dart';
import '../theme/car_theme.dart';
import '../widgets/ncs_logo.dart';

class ViewportList extends StatefulWidget {
  const ViewportList({super.key});

  @override
  State<ViewportList> createState() => _ViewportListState();
}

class _ViewportListState extends State<ViewportList> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final audio = context.watch<AudioProvider>();

    return Container(
      color: CarColors.background,
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Segmented Tab Selector
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: CarColors.cardContainer,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: CarColors.cardBorder),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: CarColors.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: CarColors.secondaryCyan.withOpacity(0.6)),
              ),
              labelColor: CarColors.secondaryCyan,
              unselectedLabelColor: CarColors.textMuted,
              labelStyle: GoogleFonts.robotoMono(fontSize: 12, fontWeight: FontWeight.w800),
              unselectedLabelStyle: GoogleFonts.robotoMono(fontSize: 12, fontWeight: FontWeight.w600),
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.history_rounded, size: 16),
                      const SizedBox(width: 6),
                      Text('RECENTLY PLAYED (${audio.history.length})'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.album_rounded, size: 16),
                      const SizedBox(width: 6),
                      Text('${audio.selectedGenre.toUpperCase()} POOL (${audio.currentGenrePool.length})'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Chunky list rows (min height 72dp)
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTrackListView(
                  tracks: audio.history,
                  emptyMessage: 'No tracks played yet in this session',
                  currentTrack: audio.currentTrack,
                  onSelect: (t) => audio.playTrack(t),
                ),
                _buildTrackListView(
                  tracks: audio.currentGenrePool,
                  emptyMessage: 'Genre pool empty. Tap RAND to load tracks.',
                  currentTrack: audio.currentTrack,
                  onSelect: (t) => audio.playTrack(t),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackListView({
    required List<NcsTrack> tracks,
    required String emptyMessage,
    required NcsTrack? currentTrack,
    required ValueChanged<NcsTrack> onSelect,
  }) {
    if (tracks.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.queue_music_rounded, size: 36, color: CarColors.textMuted),
            const SizedBox(height: 8),
            Text(
              emptyMessage,
              style: GoogleFonts.robotoMono(
                color: CarColors.textMuted,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: tracks.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final track = tracks[index];
        final isPlayingThis = track.id == currentTrack?.id;
        final genreColor = track.genreColor;

        return ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onSelect(track),
              borderRadius: BorderRadius.circular(12),
              splashColor: genreColor.withOpacity(0.2),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isPlayingThis
                      ? genreColor.withOpacity(0.12)
                      : CarColors.cardContainer,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isPlayingThis ? genreColor : CarColors.cardBorder,
                    width: isPlayingThis ? 1.5 : 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: CarColors.background,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isPlayingThis ? genreColor : CarColors.cardBorder,
                        ),
                      ),
                      child: Center(
                        child: isPlayingThis
                            ? Icon(Icons.equalizer_rounded, size: 18, color: genreColor)
                            : Text(
                                '${index + 1}',
                                style: GoogleFonts.robotoMono(
                                  color: CarColors.textMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 48,
                        height: 48,
                        color: const Color(0xFF1B1B22),
                        child: track.artworkUrl.isNotEmpty
                            ? Image.network(
                                track.artworkUrl,
                                fit: BoxFit.cover,
                                cacheWidth: 400,
                                cacheHeight: 400,
                                errorBuilder: (_, _, _) => Center(
                                  child: NcsLogo(size: 22, glowColor: genreColor),
                                ),
                              )
                            : Center(
                                child: NcsLogo(size: 22, glowColor: genreColor),
                              ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.robotoMono(
                              color: isPlayingThis ? genreColor : CarColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            track.artists,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.robotoMono(
                              color: CarColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: genreColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: genreColor.withOpacity(0.5)),
                      ),
                      child: Text(
                        track.genreName.toUpperCase(),
                        style: GoogleFonts.robotoMono(
                          color: genreColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      isPlayingThis ? Icons.play_arrow_rounded : Icons.play_circle_outline_rounded,
                      color: isPlayingThis ? genreColor : CarColors.textMuted,
                      size: 24,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
