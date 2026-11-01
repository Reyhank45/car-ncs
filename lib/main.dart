import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:audio_service/audio_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'providers/audio_provider.dart';
import 'providers/safety_provider.dart';
import 'providers/settings_provider.dart';
import 'services/car_audio_handler.dart';
import 'theme/car_theme.dart';
import 'widgets/nav_rail_col1.dart';
import 'widgets/persistent_deck_col2.dart';
import 'views/dynamic_viewport_col3.dart';

late CarAudioHandler _audioHandler;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && Platform.isLinux) {
    try {
      JustAudioMediaKit.ensureInitialized();
    } catch (e) {
      debugPrint('MediaKit initialization deferred: $e');
    }
  }

  // Strict landscape-only orientation lock via SystemChrome
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Immersive automotive edge-to-edge UI
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.immersiveSticky,
  );

  // Initialize AudioService with CarAudioHandler
  _audioHandler = await AudioService.init(
    builder: () => CarAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.carncs.audio',
      androidNotificationChannelName: 'Car NCS Playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      androidNotificationIcon: 'mipmap/ic_launcher',
    ),
  );

  runApp(CarNcsApp(audioHandler: _audioHandler));
}

class CarNcsApp extends StatelessWidget {
  final CarAudioHandler audioHandler;

  const CarNcsApp({super.key, required this.audioHandler});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AudioProvider(audioHandler)),
        ChangeNotifierProvider(create: (_) => SafetyProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ],
      child: MaterialApp(
        title: 'Car NCS',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: CarColors.background,
          primaryColor: CarColors.primaryAccent,
          colorScheme: const ColorScheme.dark(
            primary: CarColors.primaryAccent,
            secondary: CarColors.secondaryCyan,
            surface: CarColors.cardContainer,
          ),
          textTheme: GoogleFonts.robotoMonoTextTheme(),
        ),
        home: const CarNcsDashboardScreen(),
      ),
    );
  }
}

class CarNcsDashboardScreen extends StatelessWidget {
  const CarNcsDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      backgroundColor: CarColors.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.maxWidth - 88;
          final deckWidth = availableWidth * 0.38;
          final viewportWidth = availableWidth - deckWidth;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // COL 1: NAV RAIL (Fixed 88dp width)
              RepaintBoundary(
                child: NavRailCol1(
                  selectedIndex: settings.activeRailIndex,
                  onTileSelected: (index) {
                    settings.setActiveRailIndex(index);
                  },
                ),
              ),

              // COL 2: PERSISTENT DECK (Width: ~38%)
              SizedBox(
                width: deckWidth,
                child: const RepaintBoundary(
                  child: PersistentDeckCol2(),
                ),
              ),

              // COL 3: DYNAMIC VIEWPORT (Width: ~54%)
              SizedBox(
                width: viewportWidth,
                child: const DynamicViewportCol3(),
              ),
            ],
          );
        },
      ),
    );
  }
}
