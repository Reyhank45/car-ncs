import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/safety_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/car_theme.dart';

class ViewportSettings extends StatefulWidget {
  const ViewportSettings({super.key});

  @override
  State<ViewportSettings> createState() => _ViewportSettingsState();
}

class _ViewportSettingsState extends State<ViewportSettings> with SingleTickerProviderStateMixin {
  late AnimationController _holdController;
  bool _isHolding = false;

  @override
  void initState() {
    super.initState();
    // 2-second hold controller
    _holdController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _holdController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _triggerExitApp();
      }
    });
  }

  void _triggerExitApp() {
    // Show exit confirmation banner or exit platform
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: CarColors.dangerRed,
        content: Text(
          'CAR NCS PIN TERMINATED / APPLICATION EXITING...',
          style: GoogleFonts.robotoMono(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        duration: const Duration(seconds: 2),
      ),
    );

    Future.delayed(const Duration(milliseconds: 1200), () {
      SystemNavigator.pop();
    });
  }

  void _onHoldStart(TapDownDetails _) {
    setState(() => _isHolding = true);
    _holdController.forward();
  }

  void _onHoldEnd() {
    setState(() => _isHolding = false);
    if (_holdController.status != AnimationStatus.completed) {
      _holdController.reverse();
    }
  }

  @override
  void dispose() {
    _holdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final safety = context.watch<SafetyProvider>();

    return Container(
      color: CarColors.background,
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'SYSTEM CONFIGURATION & SENSOR CALIBRATION',
            style: GoogleFonts.robotoMono(
              color: CarColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 10),

          // Main Controls Split Row
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. QNH Calibration Card (+ / - buttons in 1 hPa steps)
                Expanded(
                  flex: 3,
                  child: _buildQnhCalibrationCard(settings),
                ),

                const SizedBox(width: 10),

                // 2. Dual Unit Toggle & Sensor Simulation Card
                Expanded(
                  flex: 3,
                  child: _buildUnitsAndSafetyCard(settings, safety),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // 3. Red hold-to-confirm button: [ EXIT APP / UNPIN (HOLD 2s) ] with circular progress animation
          _buildHoldToExitButton(),
        ],
      ),
    );
  }

  Widget _buildQnhCalibrationCard(SettingsProvider settings) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CarColors.cardContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CarColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune_rounded, size: 15, color: CarColors.secondaryCyan),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'BARO / QNH',
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.robotoMono(
                    color: CarColors.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => settings.resetQnhToStandard(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: CarColors.background,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: CarColors.cardBorder),
                  ),
                  child: Text(
                    'STD (1013)',
                    style: GoogleFonts.robotoMono(
                      color: CarColors.secondaryCyan,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Altimeter pressure datum in 1 hPa increments',
            style: GoogleFonts.robotoMono(color: CarColors.textMuted, fontSize: 10),
          ),
          const Spacer(),
          // Center Big Readout + Step buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Minus 1 hPa
              _buildStepButton(
                icon: Icons.remove_rounded,
                onTap: () => settings.decrementQnh(),
              ),
              const SizedBox(width: 14),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    settings.qnhHpa.toStringAsFixed(1),
                    style: GoogleFonts.robotoMono(
                      color: CarColors.secondaryCyan,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    'HECTOPASCALS (hPa)',
                    style: GoogleFonts.robotoMono(
                      color: CarColors.textSecondary,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              // Plus 1 hPa
              _buildStepButton(
                icon: Icons.add_rounded,
                onTap: () => settings.incrementQnh(),
              ),
            ],
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildStepButton({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFF1B1B24),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: CarColors.secondaryCyan.withOpacity(0.4)),
          ),
          child: Icon(icon, color: CarColors.secondaryCyan, size: 28),
        ),
      ),
    );
  }

  Widget _buildUnitsAndSafetyCard(SettingsProvider settings, SafetyProvider safety) {
    final isKmh = settings.speedUnit == SpeedDisplayUnit.kmh;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CarColors.cardContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CarColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.speed_rounded, size: 15, color: CarColors.primaryAccent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'SPEED UNITS & SAFETY',
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.robotoMono(
                    color: CarColors.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Dual Unit Toggle (km/h vs km/min)
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => settings.setSpeedUnit(SpeedDisplayUnit.kmh),
                  child: Container(
                    height: 38,
                    decoration: BoxDecoration(
                      color: isKmh ? CarColors.primaryAccent.withOpacity(0.15) : CarColors.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isKmh ? CarColors.primaryAccent : CarColors.cardBorder,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'KM/H PRIMARY',
                        style: GoogleFonts.robotoMono(
                          color: isKmh ? CarColors.primaryAccent : CarColors.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => settings.setSpeedUnit(SpeedDisplayUnit.kmMin),
                  child: Container(
                    height: 38,
                    decoration: BoxDecoration(
                      color: !isKmh ? CarColors.secondaryCyan.withOpacity(0.15) : CarColors.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: !isKmh ? CarColors.secondaryCyan : CarColors.cardBorder,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'KM/MIN PRIMARY',
                        style: GoogleFonts.robotoMono(
                          color: !isKmh ? CarColors.secondaryCyan : CarColors.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const Spacer(),

          // Safety Lock Quick Test Bar (Allows simulating movement to test automotive lock)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: CarColors.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: CarColors.cardBorder),
            ),
            child: Row(
              children: [
                Icon(
                  safety.isMotionLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
                  size: 16,
                  color: safety.isMotionLocked ? CarColors.amberWarning : CarColors.primaryAccent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    safety.isMotionLocked ? 'MOTION LOCK ACTIVE (>0 KM/H)' : 'STATIONARY (0 KM/H SEEK OK)',
                    style: GoogleFonts.robotoMono(
                      color: safety.isMotionLocked ? CarColors.amberWarning : CarColors.primaryAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                // Toggle simulation speed buttons
                GestureDetector(
                  onTap: () {
                    if (safety.groundSpeedKmH > 0) {
                      safety.setSimulatedSpeed(0.0);
                    } else {
                      safety.setSimulatedSpeed(74.5);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1F1F2A),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: CarColors.cardBorder),
                    ),
                    child: Text(
                      safety.groundSpeedKmH > 0 ? 'SIMULATE STOP (0)' : 'SIMULATE DRIVE (75)',
                      style: GoogleFonts.robotoMono(
                        color: CarColors.textPrimary,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHoldToExitButton() {
    return GestureDetector(
      onTapDown: _onHoldStart,
      onTapUp: (_) => _onHoldEnd(),
      onTapCancel: () => _onHoldEnd(),
      child: AnimatedBuilder(
        animation: _holdController,
        builder: (context, child) {
          final progress = _holdController.value;

          return Container(
            height: 52,
            decoration: BoxDecoration(
              color: CarColors.dangerRed.withOpacity(0.12 + (progress * 0.4)),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: CarColors.dangerRed,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: CarColors.dangerRed.withOpacity(0.2 + (progress * 0.4)),
                  blurRadius: 10 + (progress * 10),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Horizontal fill progress
                FractionallySizedBox(
                  widthFactor: progress,
                  child: Container(
                    decoration: BoxDecoration(
                      color: CarColors.dangerRed.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),

                // Button Contents
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Circular progress animation indicator
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          value: _isHolding ? progress : 0.0,
                          strokeWidth: 2.5,
                          backgroundColor: CarColors.dangerRed.withOpacity(0.3),
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _isHolding
                            ? 'HOLDING... ${(2 - (progress * 2)).toStringAsFixed(1)}s'
                            : 'EXIT APP / UNPIN (HOLD 2s)',
                        style: GoogleFonts.robotoMono(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.power_settings_new_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

