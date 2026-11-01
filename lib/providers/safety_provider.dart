import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../services/stream_throttle.dart';

class SafetyProvider extends ChangeNotifier {
  // Ground speed in km/h
  double _groundSpeedKmH = 0.0;
  
  // Motion locked state
  bool _isMotionLocked = false;

  // Lat / Long coordinates
  double _latitude = -8.17025; // Default demo: -08° 10.215' S
  double _longitude = 115.1328;
  double _altitudeMeters = 345.0; // Elevation GPS WGS84

  // Isolated ValueNotifiers for high-frequency telemetry (Ground Speed, Altitude, Coordinates, Lock)
  final ValueNotifier<double> speedKmHNotifier = ValueNotifier<double>(0.0);
  final ValueNotifier<double> altitudeMetersNotifier = ValueNotifier<double>(345.0);
  final ValueNotifier<({double lat, double lon})> coordinatesNotifier =
      ValueNotifier((lat: -8.17025, lon: 115.1328));
  final ValueNotifier<bool> motionLockedNotifier = ValueNotifier<bool>(false);

  // Debounce timer for stopping (2-second stoplight debounce)
  Timer? _stoplightTimer;
  StreamSubscription<Position>? _positionSubscription;

  // Manual simulation mode for testing when GPS is stationary or on desktop/emulator
  bool _isSimulating = false;

  SafetyProvider() {
    _initGeolocator();
  }

  double get groundSpeedKmH => _groundSpeedKmH;
  double get groundSpeedKmMin => _groundSpeedKmH / 60.0;
  bool get isMotionLocked => _isMotionLocked;
  double get latitude => _latitude;
  double get longitude => _longitude;
  double get altitudeMeters => _altitudeMeters;
  double get altitudeFeet => _altitudeMeters * 3.28084;
  bool get isSimulating => _isSimulating;

  Future<void> _initGeolocator() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Location services disabled, keep defaults
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      if (permission == LocationPermission.deniedForever) return;

      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 1,
      );

      // Throttle telemetry stream to max 2 Hz (500ms interval) to eliminate UI thread congestion & phone heating
      _positionSubscription = Geolocator.getPositionStream(locationSettings: locationSettings)
          .transform(StreamThrottle<Position>(const Duration(milliseconds: 500)))
          .listen(
        (Position position) {
          if (_isSimulating) return; // Simulated speed takes precedence if enabled

          // speed is in m/s from geolocator -> convert to km/h
          final rawSpeed = position.speed; // m/s
          final speedKmH = rawSpeed < 0 ? 0.0 : (rawSpeed * 3.6);

          _latitude = position.latitude;
          _longitude = position.longitude;
          _altitudeMeters = position.altitude;

          updatePosition(position.latitude, position.longitude, position.altitude);
          updateSpeed(speedKmH);
        },
        onError: (err) {
          debugPrint('Geolocator error: $err');
        },
      );
    } catch (e) {
      debugPrint('Geolocator initialization error: $e');
    }
  }

  void updatePosition(double lat, double lon, double altM) {
    _latitude = lat;
    _longitude = lon;
    _altitudeMeters = altM;
    coordinatesNotifier.value = (lat: lat, lon: lon);
    altitudeMetersNotifier.value = altM;
  }

  void updateSpeed(double speedKmH) {
    _groundSpeedKmH = speedKmH;
    speedKmHNotifier.value = speedKmH;

    if (speedKmH > 0.5) {
      // Vehicle in motion - immediate lock
      _stoplightTimer?.cancel();
      _stoplightTimer = null;
      if (!_isMotionLocked) {
        _isMotionLocked = true;
        motionLockedNotifier.value = true;
        notifyListeners(); // Notify state consumers only on motion lock status transition
      }
    } else {
      // Vehicle stopped / idle: 2-second stoplight debounce before unlocking seek gestures
      if (_isMotionLocked && _stoplightTimer == null) {
        _stoplightTimer = Timer(const Duration(seconds: 2), () {
          if (_groundSpeedKmH <= 0.5) {
            _isMotionLocked = false;
            motionLockedNotifier.value = false;
            notifyListeners(); // Notify state consumers only on motion lock status transition
          }
          _stoplightTimer = null;
        });
      }
    }
  }

  // Simulation controls for testing automotive motion lock & flightdeck metrics
  void toggleSimulation(bool enable) {
    _isSimulating = enable;
    if (!enable) {
      updateSpeed(0.0);
    }
    notifyListeners();
  }

  void setSimulatedSpeed(double speedKmH) {
    _isSimulating = true;
    updateSpeed(speedKmH);
  }

  void setSimulatedTelemetry({
    required double speedKmH,
    required double lat,
    required double lng,
    required double altitudeM,
  }) {
    _isSimulating = true;
    updatePosition(lat, lng, altitudeM);
    updateSpeed(speedKmH);
  }

  @override
  void dispose() {
    _stoplightTimer?.cancel();
    _positionSubscription?.cancel();
    speedKmHNotifier.dispose();
    altitudeMetersNotifier.dispose();
    coordinatesNotifier.dispose();
    motionLockedNotifier.dispose();
    super.dispose();
  }
}
