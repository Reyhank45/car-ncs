import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/safety_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/car_theme.dart';

class ViewportMetric extends StatelessWidget {
  const ViewportMetric({super.key});

  /// Formats coordinate in Degrees & Decimal Minutes:
  /// e.g., -08° 10.215' S or 115° 07.968' E
  static String formatDegreesDecimalMinutes(double coord, bool isLatitude) {
    final hemisphere = isLatitude
        ? (coord >= 0 ? 'N' : 'S')
        : (coord >= 0 ? 'E' : 'W');
    final absCoord = coord.abs();
    final degrees = absCoord.floor();
    final decimalMinutes = (absCoord - degrees) * 60.0;
    final prefix = coord < 0 ? '-' : '';
    final degStr = degrees.toString().padLeft(2, '0');
    final minStr = decimalMinutes.toStringAsFixed(3).padLeft(6, '0');

    return '$prefix$degStr° $minStr\' $hemisphere';
  }

  @override
  Widget build(BuildContext context) {
    // Read SafetyProvider without listening to prevent full-screen rebuilds on GPS updates
    final safety = context.read<SafetyProvider>();
    final settings = context.watch<SettingsProvider>();

    final baroAltM = settings.calculateBarometricAltitude();
    final baroAltFt = baroAltM * 3.28084;

    return Container(
      color: CarColors.background,
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // TOP: Isolated Ground Speed readout (ValueListenableBuilder)
          _SpeedCardWidget(safety: safety),

          const SizedBox(height: 10),

          // MIDDLE: 2-column card split for Elevation:
          // Left: Elevation (GPS - WGS84) in Meters and Feet (Isolated ValueListenableBuilder).
          // Right: Altitude (STD / Baro) derived from ambient air pressure.
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _ElevationGpsCardWidget(safety: safety),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildBaroAltitudeCard(baroAltM, baroAltFt, settings.qnhHpa),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // BOTTOM: Monospaced Lat/Long readout (Isolated ValueListenableBuilder)
          _CoordinatesCardWidget(safety: safety),
        ],
      ),
    );
  }

  Widget _buildBaroAltitudeCard(double baroAltM, double baroAltFt, double qnhHpa) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CarColors.cardContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CarColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Row(
            children: [
              const Icon(Icons.air_rounded, size: 14, color: CarColors.primaryAccent),
              const SizedBox(width: 6),
              Text(
                'ALTITUDE (STD / BARO)',
                style: GoogleFonts.robotoMono(
                  color: CarColors.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                baroAltM.toStringAsFixed(0),
                style: GoogleFonts.robotoMono(
                  color: CarColors.textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'M',
                style: GoogleFonts.robotoMono(
                  color: CarColors.primaryAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                baroAltFt.toStringAsFixed(0),
                style: GoogleFonts.robotoMono(
                  color: CarColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'FT',
                style: GoogleFonts.robotoMono(
                  color: CarColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          Text(
            'QNH Datum: ${qnhHpa.toStringAsFixed(1)} hPa',
            style: GoogleFonts.robotoMono(
              color: CarColors.primaryAccent,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Dedicated isolated widget for Ground Speed telemetry
class _SpeedCardWidget extends StatelessWidget {
  final SafetyProvider safety;
  const _SpeedCardWidget({required this.safety});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: safety.speedKmHNotifier,
      builder: (context, speedKmH, _) {
        final speedKmMin = speedKmH / 60.0;
        final isMoving = speedKmH > 0.5;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: CarColors.cardContainer,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isMoving ? CarColors.primaryAccent.withOpacity(0.4) : CarColors.cardBorder,
              width: 1.5,
            ),
            boxShadow: isMoving
                ? [
                    BoxShadow(
                      color: CarColors.primaryAccent.withOpacity(0.08),
                      blurRadius: 12,
                      spreadRadius: 1,
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // KM/H block
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'GROUND SPEED',
                    style: GoogleFonts.robotoMono(
                      color: CarColors.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        speedKmH.toStringAsFixed(1),
                        style: GoogleFonts.robotoMono(
                          color: CarColors.primaryAccent,
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.0,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'KM/H',
                        style: GoogleFonts.robotoMono(
                          color: CarColors.textSecondary,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              Container(
                width: 1.5,
                height: 56,
                color: CarColors.cardBorder,
              ),

              // KM/MIN block
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'VELOCITY RATE',
                    style: GoogleFonts.robotoMono(
                      color: CarColors.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        speedKmMin.toStringAsFixed(2),
                        style: GoogleFonts.robotoMono(
                          color: CarColors.secondaryCyan,
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.0,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'KM/MIN',
                        style: GoogleFonts.robotoMono(
                          color: CarColors.textSecondary,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Dedicated isolated widget for GPS Elevation telemetry
class _ElevationGpsCardWidget extends StatelessWidget {
  final SafetyProvider safety;
  const _ElevationGpsCardWidget({required this.safety});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: safety.altitudeMetersNotifier,
      builder: (context, elevationM, _) {
        final elevationFt = elevationM * 3.28084;

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: CarColors.cardContainer,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: CarColors.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Row(
                children: [
                  const Icon(Icons.satellite_alt_rounded, size: 14, color: CarColors.secondaryCyan),
                  const SizedBox(width: 6),
                  Text(
                    'ELEVATION (GPS - WGS84)',
                    style: GoogleFonts.robotoMono(
                      color: CarColors.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    elevationM.toStringAsFixed(0),
                    style: GoogleFonts.robotoMono(
                      color: CarColors.textPrimary,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'M',
                    style: GoogleFonts.robotoMono(
                      color: CarColors.secondaryCyan,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    elevationFt.toStringAsFixed(0),
                    style: GoogleFonts.robotoMono(
                      color: CarColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'FT',
                    style: GoogleFonts.robotoMono(
                      color: CarColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Text(
                'High-precision multi-constellation GNSS',
                style: GoogleFonts.robotoMono(
                  color: CarColors.textMuted,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Dedicated isolated widget for Coordinates telemetry
class _CoordinatesCardWidget extends StatelessWidget {
  final SafetyProvider safety;
  const _CoordinatesCardWidget({required this.safety});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<({double lat, double lon})>(
      valueListenable: safety.coordinatesNotifier,
      builder: (context, coords, _) {
        final latFormatted = ViewportMetric.formatDegreesDecimalMinutes(coords.lat, true);
        final lonFormatted = ViewportMetric.formatDegreesDecimalMinutes(coords.lon, false);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: CarColors.cardContainer,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: CarColors.cardBorder),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.explore_rounded, size: 14, color: CarColors.secondaryCyan),
                  const SizedBox(width: 6),
                  Text(
                    'COORDS [DDM]:',
                    style: GoogleFonts.robotoMono(
                      color: CarColors.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              Flexible(
                child: Text(
                  '$latFormatted | $lonFormatted',
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.robotoMono(
                    color: CarColors.textPrimary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
