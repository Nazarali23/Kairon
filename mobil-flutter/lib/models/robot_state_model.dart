class RobotStateModel {
  final int id;
  final int configVersion;
  final bool powerOn;
  final int volume;
  final double ttsSpeed;
  final double ttsPitch;
  final double robotMix;
  final String styleMode;
  final String activeMode;
  final String faceStyle;
  final bool builtinDaysOn;
  final int quietUntilEpoch;
  final int lastSeenEpoch;
  final String eyeColor;
  final bool aiColorMode;
  final String pendingSay;
  final bool roomOccupied;

  RobotStateModel({
    required this.id,
    required this.configVersion,
    required this.powerOn,
    required this.volume,
    required this.ttsSpeed,
    required this.ttsPitch,
    required this.robotMix,
    required this.styleMode,
    required this.activeMode,
    required this.faceStyle,
    required this.builtinDaysOn,
    required this.quietUntilEpoch,
    required this.lastSeenEpoch,
    required this.eyeColor,
    required this.aiColorMode,
    required this.pendingSay,
    required this.roomOccupied,
  });

  factory RobotStateModel.fromJson(Map<String, dynamic> json) {
    return RobotStateModel(
      id: json['id'] as int? ?? 1,
      configVersion: json['config_version'] as int? ?? 0,
      powerOn: json['power_on'] as bool? ?? true,
      volume: json['volume'] as int? ?? 80,
      ttsSpeed: (json['tts_speed'] as num?)?.toDouble() ?? 1.0,
      ttsPitch: (json['tts_pitch'] as num?)?.toDouble() ?? 1.0,
      robotMix: (json['robot_mix'] as num?)?.toDouble() ?? 0.0,
      styleMode: json['style_mode'] as String? ?? 'normal',
      activeMode: json['active_mode'] as String? ?? 'normal',
      faceStyle: json['face_style'] as String? ?? 'cute',
      builtinDaysOn: json['builtin_days_on'] as bool? ?? true,
      quietUntilEpoch: json['quiet_until_epoch'] as int? ?? 0,
      lastSeenEpoch: json['last_seen_epoch'] as int? ?? 0,
      eyeColor: json['eye_color'] as String? ?? '#00FFFF',
      aiColorMode: json['ai_color_mode'] as bool? ?? false,
      pendingSay: json['pending_say'] as String? ?? '',
      roomOccupied: json['room_occupied'] as bool? ?? false,
    );
  }

  /// Robot son 60 saniye içinde sinyal gönderdiyse çevrimiçi kabul edilir
  bool get isOnline {
    final nowEpoch = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return (nowEpoch - lastSeenEpoch) < 60;
  }
}
