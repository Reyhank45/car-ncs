import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/car_theme.dart';

class NavRailCol1 extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTileSelected;

  const NavRailCol1({
    super.key,
    required this.selectedIndex,
    required this.onTileSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 88,
      height: double.infinity,
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
        right: false,
        child: Column(
          children: [
            const SizedBox(height: 8),
            // Tactile oversized action tiles (76dp height)
            _buildRailTile(
              index: 0,
              icon: Icons.shuffle_rounded,
              label: 'RAND',
              tooltip: 'Random Track / Genres',
            ),
            const SizedBox(height: 6),
            _buildRailTile(
              index: 1,
              icon: Icons.queue_music_rounded,
              label: 'LIST',
              tooltip: 'Queue / History',
            ),
            const SizedBox(height: 6),
            _buildRailTile(
              index: 2,
              icon: Icons.speed_rounded,
              label: 'METRIC',
              tooltip: 'Flight-deck Telemetry',
            ),
            const SizedBox(height: 6),
            _buildRailTile(
              index: 3,
              icon: Icons.settings_rounded,
              label: 'SET',
              tooltip: 'Settings & QNH Calibration',
            ),
            const Spacer(),
            // Bottom branding / status
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Column(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: CarColors.primaryAccent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: CarColors.primaryAccent.withOpacity(0.6),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'SYS OK',
                    style: GoogleFonts.robotoMono(
                      color: CarColors.textMuted,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRailTile({
    required int index,
    required IconData icon,
    required String label,
    required String tooltip,
  }) {
    final bool isActive = selectedIndex == index;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onTileSelected(index),
          splashColor: CarColors.secondaryCyan.withOpacity(0.2),
          highlightColor: CarColors.secondaryCyan.withOpacity(0.1),
          child: Container(
            height: 76,
            width: 88,
            decoration: BoxDecoration(
              color: isActive
                  ? CarColors.background.withOpacity(0.85)
                  : Colors.transparent,
            ),
            child: Stack(
              children: [
                // Active state: Left neon-cyan vertical accent bar (4dp width) with subtle glow
                if (isActive)
                  Positioned(
                    left: 0,
                    top: 8,
                    bottom: 8,
                    child: Container(
                      width: 4,
                      decoration: BoxDecoration(
                        color: CarColors.secondaryCyan,
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(2),
                          bottomRight: Radius.circular(2),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: CarColors.secondaryCyan.withOpacity(0.8),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        icon,
                        size: 28,
                        color: isActive
                            ? CarColors.secondaryCyan
                            : CarColors.textSecondary,
                        shadows: isActive
                            ? [
                                Shadow(
                                  color: CarColors.secondaryCyan.withOpacity(0.7),
                                  blurRadius: 10,
                                ),
                              ]
                            : null,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        style: GoogleFonts.robotoMono(
                          fontSize: 11,
                          fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                          color: isActive
                              ? CarColors.textPrimary
                              : CarColors.textMuted,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

