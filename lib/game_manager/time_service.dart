import 'package:flutter/foundation.dart';

import '../component/game_stage/lighting/ambient_lighting_utils.dart';
import '../component/game_stage/lighting/day_night_schedule.dart';

enum TimeOfDayType {
  midnight,
  morning,
  day,
  evening,
  night,
}

class TimeService extends ChangeNotifier {
  int _hour = 3;
  int _minute = 0;
  int _day = 1; // 1: Monday, 2: Tuesday, ..., 7: Sunday
  final List<String> _dayOfWeek = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  int get hour => _hour;
  int get minute => _minute;
  String get dayString => _dayOfWeek[_day -1];
  int get day => _day;

  double _elapsedTime = 0.0;
  double totalPlayTime = 0.0;

  TimeService() {
    // TODO: Implement time progression logic, possibly with a Timer
  }

  void advanceMinutes(int minutes) {
    _minute += minutes;
    while (_minute >= 60) {
      _minute -= 60;
      _hour++;
      if (_hour >= 24) {
        _hour = 0;
        _day++;
        if (_day > 7) {
          _day = 1;
        }
      }
    }
    notifyListeners();
  }

  void rewindMinutes(int minutes) {
    _minute -= minutes;
    while (_minute < 0) {
      _minute += 60;
      _hour--;
      if (_hour < 0) {
        _hour = 23;
        _day--;
        if (_day < 1) {
          _day = 7;
        }
      }
    }
    notifyListeners();
  }

  void advanceTime(int minutes) {
    _minute += minutes;
    while (_minute >= 60) {
      _minute -= 60;
      _hour++;
      if (_hour >= 24) {
        _hour = 0;
        _day++;
        if (_day > 7) {
          _day = 1;
        } 
      }
    }
    notifyListeners();
  }

  void skipToMorning() {
    // 翌朝の 6:00 まで進める
    _hour = 6;
    _minute = 0;
    _day++;
    if (_day > 7) {
      _day = 1;
    }
    _elapsedTime = 0.0;
    notifyListeners();
  }

  // Placeholder for a method that might be called periodically
  void update(double dt) {
    _elapsedTime += dt;
    totalPlayTime += dt; // totalPlayTimeを更新
    if (_elapsedTime >= 1.0) { // 1秒経過したら
      _elapsedTime -= 1.0;
      advanceTime(1); // 1分進める
    }
  }

  String getFormattedTime() {
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  String getFormattedDay() {
    return '($dayString)';
  }

  TimeOfDayType get timeOfDayType {
    final profile = DayNightSchedule.profileFor(_hour, _minute);
    switch (profile) {
      case AmbientLightingProfile.dawnMorning:
        return TimeOfDayType.morning;
      case AmbientLightingProfile.day:
        return TimeOfDayType.day;
      case AmbientLightingProfile.evening:
        return TimeOfDayType.evening;
      case AmbientLightingProfile.night:
        if (_hour >= 23 || _hour < 4) {
          return TimeOfDayType.midnight;
        }
        return TimeOfDayType.night;
    }
  }
} 