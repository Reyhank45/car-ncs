import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/audio_provider.dart';
import '../theme/car_theme.dart';
import '../widgets/ncs_logo.dart';

class ViewportRand extends StatelessWidget {
  const ViewportRand({super.key});

  @override
  Widget build(BuildContext context) {
    final audio = context.watch<AudioProvider>();

    final genres = [
      {'name': 'Trap', 'color': CarColors.genreTrap, 'subtitle': 'Mint • Bass heavy'},
      {'name': 'House', 'color': CarColors.genreHouse, 'subtitle': 'Yellow • 128 BPM'},
      {'name': 'Dubstep', 'color': CarColors.genreDubstep, 'subtitle': 'Cyan • Wobs & drops'},
      {'name': 'Chill', 'color': CarColors.genreChill, 'subtitle': 'Peach • Melodic vibes'},
      {'name': 'DnB', 'color': CarColors.genreDnB, 'subtitle': 'Red • 174 BPM Fast'},
      {'name': 'Surprise Me', 'color': CarColors.genreSurprise, 'subtitle': 'White ring • All NCS'},
    ];

    return Container(
      color: CarColors.background,
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'GENRE SELECTOR (RANDOM DISPATCH)',
                style: GoogleFonts.robotoMono(
                  color: CarColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              if (audio.isOfflineRetrying)
                Row(
                  children: [
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(CarColors.amberWarning),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '[OFFLINE: RETRYING STREAM...]',
                      style: GoogleFonts.robotoMono(
                        color: CarColors.amberWarning,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                )
              else if (audio.isLoading)
                Row(
                  children: [
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(CarColors.secondaryCyan),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'AOT PRELOADING STREAM...',
                      style: GoogleFonts.robotoMono(
                        color: CarColors.secondaryCyan,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 8),

          // 2x3 Grid of chunky genre buttons (min height 76dp)
          Expanded(
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.75, // Ensures chunky >= 76dp height in landscape
              ),
              itemCount: genres.length,
              itemBuilder: (context, index) {
                final item = genres[index];
                final name = item['name'] as String;
                final color = item['color'] as Color;
                final subtitle = item['subtitle'] as String;
                final isSelected = audio.selectedGenre.toLowerCase() == name.toLowerCase() ||
                    (name == 'Surprise Me' && audio.selectedGenre == 'Surprise Me');

                return _buildChunkyGenreTile(
                  name: name,
                  subtitle: subtitle,
                  color: color,
                  isSelected: isSelected,
                  onTap: () {
                    audio.selectGenreAndFetchRandom(name);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChunkyGenreTile({
    required String name,
    required String subtitle,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: color.withOpacity(0.25),
        highlightColor: color.withOpacity(0.1),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.18) : CarColors.cardContainer,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? color : CarColors.cardBorder,
              width: isSelected ? 2.0 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.35),
                      blurRadius: 14,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              // Genre emblem ring
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: CarColors.background,
                  border: Border.all(
                    color: color,
                    width: 2.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.4),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Center(
                  child: NcsLogo(
                    size: 18,
                    glowColor: color,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.robotoMono(
                        color: isSelected ? color : CarColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.robotoMono(
                        color: isSelected ? color.withOpacity(0.85) : CarColors.textMuted,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle_rounded,
                  color: color,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

