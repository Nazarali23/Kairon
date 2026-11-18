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
  final String consoleCmd;
  final String consoleOutput;
  final int screenBrightness;

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
    this.consoleCmd = '',
    this.consoleOutput = '',
    this.screenBrightness = 100,
  });

  factory RobotStateModel.fromJson(Map<String, dynamic> json) {
    // style_mode int ya da string gelebilir (0: komik, 1: ciddi, ...)
    String parseStyle(dynamic val) {
      if (val == null) return 'otomatik';
      if (val is int) {
        const styles = ['komik', 'ciddi', 'zeki', 'soguk', 'sevimli', 'otomatik'];
        if (val >= 0 && val < styles.length) return styles[val];
        return 'otomatik';
      }
      return val.toString();
    }

    // volume hem 0-1.0 double hem 0-100 int gelebilir
    int parseVolume(dynamic val) {
      if (val == null) return 80;
      if (val is num) {
        if (val <= 1.0 && val > 0) return (val * 100).round();
        return val.toInt().clamp(0, 100);
      }
      return 80;
    }

    return RobotStateModel(
      id: json['id'] as int? ?? 1,
      configVersion: json['config_version'] as int? ?? 0,
      powerOn: json['power_on'] as bool? ?? true,
      volume: parseVolume(json['volume']),
      ttsSpeed: (json['tts_speed'] as num?)?.toDouble() ?? 1.0,
      ttsPitch: (json['tts_pitch'] as num?)?.toDouble() ?? 1.0,
      robotMix: (json['robot_mix'] as num?)?.toDouble() ?? 0.0,
      styleMode: parseStyle(json['style_mode']),
      activeMode: json['active_mode']?.toString() ?? 'normal',
      faceStyle: json['face_style']?.toString() ?? 'cute',
      builtinDaysOn: json['builtin_days_on'] as bool? ?? true,
      quietUntilEpoch: json['quiet_until_epoch'] as int? ?? 0,
      lastSeenEpoch: json['last_seen_epoch'] as int? ?? 0,
      eyeColor: json['eye_color']?.toString() ?? '#00FFFF',
      aiColorMode: json['ai_color_mode'] as bool? ?? false,
      pendingSay: json['pending_say']?.toString() ?? '',
      roomOccupied: json['room_occupied'] as bool? ?? false,
      consoleCmd: json['console_cmd']?.toString() ?? '',
      consoleOutput: json['console_output']?.toString() ?? '',
      screenBrightness: (json['screen_brightness'] as num?)?.toInt() ?? 100,
    );
  }

  /// Aktif modlar listesi (virgülle ayrılmış çoklu mod desteği)
  List<String> get activeModesList {
    if (activeMode.isEmpty) return ['normal'];
    return activeMode
        .split(',')
        .map((m) => m.trim())
        .where((m) => m.isNotEmpty)
        .toList();
  }

  bool isModeActive(String mode) {
    return activeModesList.contains(mode);
  }

  /// Robot son 60 saniye içinde sinyal gönderdiyse çevrimiçi kabul edilir
  bool get isOnline {
    final nowEpoch = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return (nowEpoch - lastSeenEpoch) < 60;
  }
}
