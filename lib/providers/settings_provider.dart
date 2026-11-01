import 'dart:math';
import 'package:flutter/foundation.dart';

enum SpeedDisplayUnit {
  kmh,
  kmMin,
}

class SettingsProvider extends ChangeNotifier {
  // QNH Barometric datum in hPa (standard datum: 1013.25 hPa)
  double _qnhHpa = 1013.25;

  // Dual unit toggle
  SpeedDisplayUnit _speedUnit = SpeedDisplayUnit.kmh;

  // Active rail index (0: RAND, 1: LIST, 2: METRIC, 3: SET)
  int _activeRailIndex = 0;

  double get qnhHpa => _qnhHpa;
  SpeedDisplayUnit get speedUnit => _speedUnit;
  int get activeRailIndex => _activeRailIndex;

  void setActiveRailIndex(int index) {
    if (_activeRailIndex != index) {
      _activeRailIndex = index;
      notifyListeners();
    }
  }

  void incrementQnh() {
    _qnhHpa += 1.0;
    notifyListeners();
  }

  void decrementQnh() {
    _qnhHpa -= 1.0;
    notifyListeners();
  }

  void setQnh(double val) {
    _qnhHpa = val;
    notifyListeners();
  }

  void resetQnhToStandard() {
    _qnhHpa = 1013.25;
    notifyListeners();
  }

  void toggleSpeedUnit() {
    if (_speedUnit == SpeedDisplayUnit.kmh) {
      _speedUnit = SpeedDisplayUnit.kmMin;
    } else {
      _speedUnit = SpeedDisplayUnit.kmh;
    }
    notifyListeners();
  }

  void setSpeedUnit(SpeedDisplayUnit unit) {
    _speedUnit = unit;
    notifyListeners();
  }

  /// Calculates barometric altitude (STD / Baro) derived from ambient air pressure (P)
  /// using the international standard atmosphere barometric formula:
  /// h = 44330.77 * (1 - (P / QNH)^(0.190263))
  /// For simulation/demonstration, we model ambient pressure around 970 - 1020 hPa.
  double calculateBarometricAltitude({double ambientPressureHpa = 975.0}) {
    if (_qnhHpa <= 0) return 0.0;
    final ratio = ambientPressureHpa / _qnhHpa;
    if (ratio <= 0) return 0.0;
    final altMeters = 44330.77 * (1.0 - pow(ratio, 0.190263));
    return altMeters;
  }
}

