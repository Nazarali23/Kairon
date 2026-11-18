import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService extends ChangeNotifier {
  User? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  User? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  AuthService() {
    try {
      _currentUser = Supabase.instance.client.auth.currentUser;
      Supabase.instance.client.auth.onAuthStateChange.listen((data) {
        _currentUser = data.session?.user;
        notifyListeners();
      });
    } catch (_) {
      // Test veya çevrimdışı ortamda sessizce devam et
    }
  }

  Future<bool> signIn(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await Supabase.instance.client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      _currentUser = res.user;
      if (_currentUser != null) {
        _claimOrphanDataSafe(_currentUser!.id);
      }
      return true;
    } on AuthException catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (e) {
      _errorMessage = 'Giriş yapılamadı: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> signUp(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await Supabase.instance.client.auth.signUp(
        email: email.trim(),
        password: password,
      );
      _currentUser = res.user;
      if (_currentUser != null) {
        _claimOrphanDataSafe(_currentUser!.id);
      }
      return true;
    } on AuthException catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (e) {
      _errorMessage = 'Kayıt oluşturulamadı: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await Supabase.instance.client.auth.signOut();
    _currentUser = null;
    notifyListeners();
  }

  /// 6 Haneli PIN veya QR kod ile gelen cihazı sahiplenme (Device Claiming)
  Future<Map<String, dynamic>> claimDevice(String code) async {
    if (!isAuthenticated) {
      return {'success': false, 'message': 'Önce giriş yapmalısınız.'};
    }

    final token = code.trim().toUpperCase();
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Eşleşme oturumunu sorgula
      final session = await Supabase.instance.client
          .from('pairing_sessions')
          .select()
          .eq('pairing_token', token)
          .maybeSingle();

      if (session == null) {
        return {'success': false, 'message': 'Geçersiz veya süresi dolmuş eşleşme kodu.'};
      }

      if (session['claimed_by'] != null) {
        return {'success': false, 'message': 'Bu cihaz zaten başka bir hesaba eşleştirilmiş.'};
      }

      final deviceType = session['device_type'] as String; // 'robot' veya 'pc'
      final userId = _currentUser!.id;
      final nowStr = DateTime.now().toUtc().isoformat();

      // 2. pairing_sessions tablosunda sahiplenildi olarak işaretle
      await Supabase.instance.client.from('pairing_sessions').update({
        'claimed_by': userId,
        'claimed_at': nowStr,
      }).eq('id', session['id']);

      // 3. İlgili cihaz tablosuna sahip ID'sini yaz
      if (deviceType == 'robot') {
        await Supabase.instance.client.from('robot_state').update({
          'owner_id': userId,
        }).eq('id', 1);
        _claimOrphanDataSafe(userId);
      } else if (deviceType == 'pc') {
        await Supabase.instance.client.from('pc_agent_state').update({
          'owner_id': userId,
        }).eq('id', 1);
      }

      return {
        'success': true,
        'deviceType': deviceType,
        'message': '${deviceType == "pc" ? "Bilgisayar Ajanı" : "Kairon Robotu"} başarıyla hesabınıza bağlandı!',
      };
    } catch (e) {
      return {'success': false, 'message': 'Eşleştirme hatası: $e'};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Sahipsiz tüm önceki verileri (hafızalar, özel günler, takip) kullanıcıya bağlar
  Future<void> _claimOrphanDataSafe(String userId) async {
    try {
      await Supabase.instance.client.rpc('claim_all_unassigned_data_to_user', params: {
        'target_user_id': userId,
      });
    } catch (e) {
      debugPrint('Mevcut veri sahiplendirme atlandı: $e');
    }
  }
}

extension DateTimeIso on DateTime {
  String isoformat() => toIso8601String();
}
