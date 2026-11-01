import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../theme/car_theme.dart';
import 'viewport_metric.dart';
import 'viewport_rand.dart';
import 'viewport_list.dart';
import 'viewport_settings.dart';

class DynamicViewportCol3 extends StatelessWidget {
  const DynamicViewportCol3({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Container(
      color: CarColors.background,
      child: SafeArea(
        left: false,
        child: IndexedStack(
          index: settings.activeRailIndex,
          children: const [
            // Index 0: RAND (Genre Selector & Dispatcher)
            ViewportRand(),

            // Index 1: LIST (Queue / Recently Played & Genre Pool)
            ViewportList(),

            // Index 2: METRIC (Flight-deck Telemetry)
            ViewportMetric(),

            // Index 3: SET (Settings & Calibration)
            ViewportSettings(),
          ],
        ),
      ),
    );
  }
}

