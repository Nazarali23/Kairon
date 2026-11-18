import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/robot_state_model.dart';
import '../core/config.dart';

class SupabaseService extends ChangeNotifier {
  RobotStateModel? _robotState;
  bool _isPcOnline = false;
  bool _isLoading = false;
  String? _errorMessage;
  Timer? _pollingTimer;

  RobotStateModel? get robotState => _robotState;
  bool get isPcOnline => _isPcOnline;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

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

      // Periyodik kontrol (10 saniye)
      _pollingTimer?.cancel();
      _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        fetchRobotState();
        fetchPcState();
      });

      // Supabase Realtime aboneliği
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

  Future<bool> setMode(String newMode) async {
    if (!AppConfig.isConfigured || _robotState == null) return false;
    try {
      await Supabase.instance.client.from('robot_state').update({
        'active_mode': newMode,
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

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }
}
