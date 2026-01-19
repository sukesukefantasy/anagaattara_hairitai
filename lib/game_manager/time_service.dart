import 'package:flutter/foundation.dart';

enum TimeOfDayType {
  midnight,
  morning,
  day,
  evening,
  night,
}

class TimeService extends ChangeNotifier {
  int _hour = 5;
  int _minute = 30;
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
    if (_hour >= 4 && _hour < 6) {
      return TimeOfDayType.morning; // 日の出 4:00 - 5:59
    } else if (_hour >= 6 && _hour < 15) {
      return TimeOfDayType.day; // 朝と昼 6:00 - 14:59
    } else if (_hour >= 15 && _hour < 18) {
      return TimeOfDayType.evening; // 日の入り 15:00 - 17:59
    } else if (_hour >= 18 && _hour < 23) {
      return TimeOfDayType.night; // 夜 18:00 - 22:59
    } else { // 23:00 - 3:59
      return TimeOfDayType.midnight; // 夜中 23:00 - 3:59
    }
  }
} 