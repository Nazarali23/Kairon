import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/robot_state_model.dart';
import '../models/reminder_model.dart';
import '../core/config.dart';

class SupabaseService extends ChangeNotifier {
  RobotStateModel? _robotState;
  bool _isPcOnline = false;
  bool _isLoading = false;
  String? _errorMessage;
  Timer? _pollingTimer;

  List<ReminderModel> _reminders = [];
  bool _isRemindersLoading = false;

  RobotStateModel? get robotState => _robotState;
  bool get isPcOnline => _isPcOnline;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<ReminderModel> get reminders => _reminders;
  bool get isRemindersLoading => _isRemindersLoading;

  SupabaseService() {
    init();
  }

  Future<void> init() async {
    if (!AppConfig.isConfigured) {
      _errorMessage = 'Supabase URL ve Anon Key henüz yapılandırılmadı.';
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      await fetchRobotState();
      await fetchPcState();
      await fetchReminders();

      // Periyodik kontrol (10 saniye)
      _pollingTimer?.cancel();
      _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        fetchRobotState();
        fetchPcState();
      });

      // Supabase Realtime aboneliği (robot_state)
      Supabase.instance.client
          .from('robot_state')
          .stream(primaryKey: ['id'])
          .eq('id', 1)
          .listen((data) {
            if (data.isNotEmpty) {
              _robotState = RobotStateModel.fromJson(data.first);
              notifyListeners();
            }
          });
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchRobotState() async {
    if (!AppConfig.isConfigured) return;
    try {
      final res = await Supabase.instance.client
          .from('robot_state')
          .select()
          .eq('id', 1)
          .maybeSingle();

      if (res != null) {
        _robotState = RobotStateModel.fromJson(res);
        _errorMessage = null;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Robot state fetch error: $e');
    }
  }

  Future<void> fetchPcState() async {
    if (!AppConfig.isConfigured) return;
    try {
      final res = await Supabase.instance.client
          .from('pc_agent_state')
          .select()
          .eq('id', 1)
          .maybeSingle();

      if (res != null) {
        final lastSeen = DateTime.tryParse(res['last_seen'] ?? '');
        if (lastSeen != null) {
          final diff = DateTime.now().toUtc().difference(lastSeen).inSeconds;
          _isPcOnline = (res['online'] == true) && diff < 60;
        } else {
          _isPcOnline = false;
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('PC state fetch error: $e');
    }
  }

  /// Çoklu mod listesini virgülle ayrılmış şekilde kaydeder
  Future<bool> setModes(List<String> modes) async {
    if (!AppConfig.isConfigured || _robotState == null) return false;
    final modesStr = modes.isEmpty ? 'normal' : modes.join(',');
    try {
      await Supabase.instance.client.from('robot_state').update({
        'active_mode': modesStr,
        'config_version': _robotState!.configVersion + 1,
      }).eq('id', 1);

      await fetchRobotState();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Belirli bir modu açıp kapatır (çoklu mod)
  Future<bool> toggleMode(String mode) async {
    if (_robotState == null) return false;
    final currentList = List<String>.from(_robotState!.activeModesList);
    if (currentList.contains(mode)) {
      currentList.remove(mode);
    } else {
      currentList.add(mode);
    }
    return setModes(currentList);
  }

  /// Tekil mod ayarı (eski geriye uyumluluk)
  Future<bool> setMode(String newMode) async {
    return setModes([newMode]);
  }

  /// Robot Kişilik / Karakter Tarzı Ayarı
  Future<bool> setStyleMode(String style) async {
    if (!AppConfig.isConfigured || _robotState == null) return false;
    try {
      await Supabase.instance.client.from('robot_state').update({
        'style_mode': style,
        'config_version': _robotState!.configVersion + 1,
      }).eq('id', 1);

      await fetchRobotState();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Ekran Parlaklığı Ayarı (0 - 100)
  Future<bool> setScreenBrightness(int brightness) async {
    if (!AppConfig.isConfigured || _robotState == null) return false;
    try {
      await Supabase.instance.client.from('robot_state').update({
        'screen_brightness': brightness.clamp(0, 100),
        'config_version': _robotState!.configVersion + 1,
      }).eq('id', 1);

      await fetchRobotState();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Kairon IDE Konsol Komutu Gönder (Geçici terminal, DB şişirmez)
  Future<bool> executeConsoleCommand(String command) async {
    if (!AppConfig.isConfigured || _robotState == null) return false;
    final cmd = command.trim();
    if (cmd.isEmpty) return false;

    try {
      await Supabase.instance.client.from('robot_state').update({
        'console_cmd': cmd,
      }).eq('id', 1);

      await fetchRobotState();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Konsol Çıktısını Temizle
  Future<bool> clearConsoleOutput() async {
    if (!AppConfig.isConfigured) return false;
    try {
      await Supabase.instance.client.from('robot_state').update({
        'console_cmd': '',
        'console_output': '',
      }).eq('id', 1);

      await fetchRobotState();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> sendPendingSay(String text) async {
    if (!AppConfig.isConfigured) return false;
    // Kısıt: En fazla 250 karakter, emoji ve markdown olmadan
    final cleanText = text.replaceAll(RegExp(r'[^\w\s\.,!?üğışöçÜĞİŞÖÇ]'), '').trim();
    final finalText = cleanText.length > 250 ? cleanText.substring(0, 250) : cleanText;

    try {
      await Supabase.instance.client.from('robot_state').update({
        'pending_say': finalText,
      }).eq('id', 1);

      await fetchRobotState();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> setVolume(int volume) async {
    if (!AppConfig.isConfigured) return false;
    try {
      await Supabase.instance.client.from('robot_state').update({
        'volume': volume.clamp(0, 100),
      }).eq('id', 1);

      await fetchRobotState();
      return true;
    } catch (e) {
      return false;
    }
  }

  // ================= HATIRLATICI & FOLLOWUPS =================

  Future<void> fetchReminders() async {
    if (!AppConfig.isConfigured) return;
    _isRemindersLoading = true;
    notifyListeners();

    try {
      final user = Supabase.instance.client.auth.currentUser;
      var query = Supabase.instance.client.from('followups').select();
      if (user != null) {
        query = query.or('user_id.eq.${user.id},user_id.is.null');
      }

      final res = await query.order('id', ascending: false).limit(20);
      _reminders = (res as List).map((row) => ReminderModel.fromJson(row)).toList();
    } catch (e) {
      debugPrint('Reminders fetch error: $e');
    } finally {
      _isRemindersLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addReminder(String text, String due, {String recurring = 'none'}) async {
    if (!AppConfig.isConfigured) return false;
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final payload = {
        'text': text.trim(),
        'due': due.trim(),
        'asked': false,
        'recurring': recurring,
        if (user != null) 'user_id': user.id,
      };

      await Supabase.instance.client.from('followups').insert(payload);
      await fetchReminders();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> toggleReminderAsked(int id, bool currentAsked) async {
    if (!AppConfig.isConfigured) return false;
    try {
      await Supabase.instance.client
          .from('followups')
          .update({'asked': !currentAsked})
          .eq('id', id);

      await fetchReminders();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteReminder(int id) async {
    if (!AppConfig.isConfigured) return false;
    try {
      await Supabase.instance.client.from('followups').delete().eq('id', id);
      await fetchReminders();
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }
}
