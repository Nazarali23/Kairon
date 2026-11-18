import 'package:flutter/material.dart';

class RobotModes {
  static const String normal = 'normal';
  static const String focus = 'focus';
  static const String guard = 'guard';
  static const String sleep = 'sleep';
  static const String care = 'care';
  static const String office = 'office';

  static const Map<String, String> titles = {
    normal: 'Standart Asistan',
    focus: 'Derin Odak & Ergonomi',
    guard: 'Bekçi & Alan Güvenliği',
    sleep: 'Gece & Uyku Analizi',
    care: 'Sağlık & Refakatçi',
    office: 'Siber Ofis & PC',
  };

  static const Map<String, String> descriptions = {
    normal: 'Sohbet, genel sorular ve günlük asistanlık.',
    focus: 'Pomodoro sayacı ve 35 cm postür/ekran mesafesi takibi.',
    guard: 'PIR ve sonar hareket alarmları, anlık caydırıcı tepkiler.',
    sleep: 'Ekran saat modunda, sessiz gece hareket analizi.',
    care: 'İlaç/su hatırlatıcıları ve uzun süreli hareketsizlik uyarısı.',
    office: 'PC ajanı bağlantısı ve gelen belge özetleri.',
  };

  static const Map<String, IconData> icons = {
    normal: Icons.smart_toy_outlined,
    focus: Icons.timer_outlined,
    guard: Icons.security_outlined,
    sleep: Icons.bedtime_outlined,
    care: Icons.favorite_outline,
    office: Icons.desktop_windows_outlined,
  };

  static const Map<String, Color> colors = {
    normal: Color(0xFF00ADB5),
    focus: Color(0xFFFF5722),
    guard: Color(0xFFE91E63),
    sleep: Color(0xFF673AB7),
    care: Color(0xFF4CAF50),
    office: Color(0xFF2196F3),
  };
}
