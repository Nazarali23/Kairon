import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/robot_state_model.dart';
import '../models/reminder_model.dart';
import '../models/inbox_item_model.dart';
import '../core/config.dart';

class SupabaseService extends ChangeNotifier {
  RobotStateModel? _robotState;
  bool _isPcOnline = false;
  bool _isLoading = false;
  String? _errorMessage;
  Timer? _pollingTimer;

  List<ReminderModel> _reminders = [];
  bool _isRemindersLoading = false;

  List<InboxItemModel> _inboxItems = [];
  bool _isInboxLoading = false;

  RobotStateModel? get robotState => _robotState;
  bool get isPcOnline => _isPcOnline;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<ReminderModel> get reminders => _reminders;
  bool get isRemindersLoading => _isRemindersLoading;

  List<InboxItemModel> get inboxItems => _inboxItems;
  bool get isInboxLoading => _isInboxLoading;

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
      await fetchInbox();

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

  /// Robot Çalışma Modları (Çoklu Mod Bitmask: 64: bayrak, 1: normal, 2: focus, 4: sleep, 8: guard, 16: care, 32: office)
  Future<bool> setModes(List<String> modes) async {
    if (!AppConfig.isConfigured || _robotState == null) return false;

    final cleanModes = modes.toSet();
    if (cleanModes.isEmpty) {
      cleanModes.add('normal');
    }

    int modeInt = 64; // Coklu mod bayragi
    if (cleanModes.contains('normal')) modeInt |= 1;
    if (cleanModes.contains('focus')) modeInt |= 2;
    if (cleanModes.contains('sleep')) modeInt |= 4;
    if (cleanModes.contains('guard')) modeInt |= 8;
    if (cleanModes.contains('care')) modeInt |= 16;
    if (cleanModes.contains('office')) modeInt |= 32;

    try {
      await Supabase.instance.client.from('robot_state').update({
        'active_mode': modeInt,
        'config_version': _robotState!.configVersion + 1,
      }).eq('id', 1);

      await fetchRobotState();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('setModes error: $e');
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
    if (currentList.isEmpty) {
      currentList.add('normal');
    }
    return setModes(currentList);
  }

  /// Tekil mod ayarı (eski geriye uyumluluk)
  Future<bool> setMode(String newMode) async {
    return setModes([newMode]);
  }

  /// Robot Kişilik / Karakter Tarzı Ayarı (0: komik, 1: ciddi, 2: zeki, 3: soguk, 4: sevimli, 5: otomatik)
  Future<bool> setStyleMode(String style) async {
    if (!AppConfig.isConfigured || _robotState == null) return false;
    try {
      const styles = ['komik', 'ciddi', 'zeki', 'soguk', 'sevimli', 'otomatik'];
      final idx = styles.indexOf(style.toLowerCase());
      final intVal = idx >= 0 ? idx : 5;

      await Supabase.instance.client.from('robot_state').update({
        'style_mode': intVal,
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

  /// PC Ajanına Doğrudan Otonom Görev İlet (/ajan-yap)
  Future<bool> sendPcCommand(String utterance) async {
    if (!AppConfig.isConfigured) return false;
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final nonce = 'mob_${DateTime.now().microsecondsSinceEpoch}';

      final payload = {
        'kind': 'task',
        'utterance': utterance.trim(),
        'nonce': nonce,
        'ts': nowSec,
        'sig': 'mobile',
        'status': 'pending',
        if (user != null) 'user_id': user.id,
      };

      await Supabase.instance.client.from('pc_commands').insert(payload);
      return true;
    } catch (e) {
      debugPrint('sendPcCommand error: $e');
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
    if (!AppConfig.isConfigured || _robotState == null) return false;
    try {
      await Supabase.instance.client.from('robot_state').update({
        'volume': volume.clamp(0, 100),
        'config_version': _robotState!.configVersion + 1,
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

      // PostgreSQL followups tablosunda id auto-increment olmadığı için max id + 1 atanır
      int newId = 1;
      try {
        final maxRow = await Supabase.instance.client
            .from('followups')
            .select('id')
            .order('id', ascending: false)
            .limit(1)
            .maybeSingle();
        if (maxRow != null && maxRow['id'] != null) {
          newId = (maxRow['id'] as int) + 1;
        } else {
          newId = (DateTime.now().millisecondsSinceEpoch ~/ 1000) % 100000;
        }
      } catch (_) {
        newId = (DateTime.now().millisecondsSinceEpoch ~/ 1000) % 100000;
      }

      final payload = {
        'id': newId,
        'title': text.trim(),
        'text': text.trim(),
        'due': due.trim(),
        'asked': false,
        'recurring': recurring,
        if (user != null) 'user_id': user.id,
      };

      await Supabase.instance.client.from('followups').insert(payload);

      // Robotun yeni hatirlaticiyi hemen algilamasi icin config_version artir
      if (_robotState != null) {
        try {
          await Supabase.instance.client.from('robot_state').update({
            'config_version': _robotState!.configVersion + 1,
          }).eq('id', 1);
        } catch (_) {}
      }

      await fetchReminders();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('addReminder error: $e');
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

      if (_robotState != null) {
        try {
          await Supabase.instance.client.from('robot_state').update({
            'config_version': _robotState!.configVersion + 1,
          }).eq('id', 1);
        } catch (_) {}
      }

      await fetchReminders();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Siber Ofis & PC Ajanı Raporları / Özetleri (app_inbox)
  Future<void> fetchInbox() async {
    if (!AppConfig.isConfigured) return;
    _isInboxLoading = true;
    notifyListeners();

    try {
      final user = Supabase.instance.client.auth.currentUser;
      var query = Supabase.instance.client.from('app_inbox').select();
      if (user != null) {
        query = query.or('user_id.eq.${user.id},user_id.is.null');
      }

      final res = await query.order('created_at', ascending: false).limit(30);
      _inboxItems = (res as List).map((row) => InboxItemModel.fromJson(row)).toList();
    } catch (e) {
      debugPrint('fetchInbox error: $e');
    } finally {
      _isInboxLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteInboxItem(String id) async {
    if (!AppConfig.isConfigured) return false;
    try {
      await Supabase.instance.client.from('app_inbox').delete().eq('id', id);
      _inboxItems.removeWhere((item) => item.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('deleteInboxItem error: $e');
      return false;
    }
  }

  Future<bool> markInboxItemAsRead(String id) async {
    if (!AppConfig.isConfigured) return false;
    try {
      await Supabase.instance.client.from('app_inbox').update({'is_read': true}).eq('id', id);
      final idx = _inboxItems.indexWhere((item) => item.id == id);
      if (idx != -1) {
        _inboxItems[idx] = InboxItemModel(
          id: _inboxItems[idx].id,
          title: _inboxItems[idx].title,
          body: _inboxItems[idx].body,
          source: _inboxItems[idx].source,
          kind: _inboxItems[idx].kind,
          filePath: _inboxItems[idx].filePath,
          isRead: true,
          createdAt: _inboxItems[idx].createdAt,
          userId: _inboxItems[idx].userId,
        );
        notifyListeners();
      }
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
