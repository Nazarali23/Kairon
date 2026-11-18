import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isSignUp = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  double _calculatePasswordStrength(String password) {
    if (password.isEmpty) return 0.0;
    double score = 0.0;
    if (password.length >= 6) score += 0.3;
    if (password.length >= 8) score += 0.2;
    if (RegExp(r'[0-9]').hasMatch(password)) score += 0.25;
    if (RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(password)) score += 0.25;
    return score.clamp(0.0, 1.0);
  }

  void _handleSubmit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen tüm zorunlu alanları doldurun.')),
      );
      return;
    }

    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Şifre en az 6 karakter olmalıdır.')),
      );
      return;
    }

    if (_isSignUp) {
      if (name.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lütfen adınızı veya kullanıcı adınızı girin.')),
        );
        return;
      }

      if (password != confirmPassword) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('Şifreler birbiriyle eşleşmiyor!'),
          ),
        );
        return;
      }
    }

    final auth = context.read<AuthService>();
    bool success;

    if (_isSignUp) {
      success = await auth.signUp(email, password, displayName: name);
    } else {
      success = await auth.signIn(email, password);
    }

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text(auth.errorMessage ?? 'İşlem gerçekleştirilemedi.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final strength = _calculatePasswordStrength(_passwordController.text);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E17),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              color: const Color(0xFF131A26),
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(color: const Color(0xFF00E5FF).withAlpha(50), width: 1.2),
              ),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Siber Robot Logosu ve Başlık
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF00E5FF).withAlpha(60),
                            const Color(0xFF0077FF).withAlpha(30),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00E5FF).withAlpha(40),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.smart_toy, size: 48, color: Color(0xFF00E5FF)),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'KAIRON ASİSTAN',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shield_outlined, size: 14, color: Colors.cyanAccent.withAlpha(200)),
                        const SizedBox(width: 4),
                        Flexible(
                          child: const Text(
                            'Kişisel Güvenli IoT & Robot Ekosistemi',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Sekme Butonları (Giriş / Güçlendirilmiş Kayıt)
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0B1019),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _isSignUp = false),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: !_isSignUp ? const Color(0xFF00E5FF) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Text(
                                    'Giriş Yap',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: !_isSignUp ? Colors.black : Colors.white70,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _isSignUp = true),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: _isSignUp ? const Color(0xFF00E5FF) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Text(
                                    'Kayıt Ol',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: _isSignUp ? Colors.black : Colors.white70,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Kayıt Ol ekranında Ad Soyad / Kullanıcı Adı
                    if (_isSignUp) ...[
                      TextField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Kullanıcı Adı / İsim',
                          prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF00E5FF)),
                          filled: true,
                          fillColor: const Color(0xFF18202F),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // E-posta Girişi
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'E-posta Adresi',
                        prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF00E5FF)),
                        filled: true,
                        fillColor: const Color(0xFF18202F),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Şifre Girişi
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Parola',
                        prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF00E5FF)),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off : Icons.visibility,
                            size: 20,
                            color: Colors.grey,
                          ),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                        filled: true,
                        fillColor: const Color(0xFF18202F),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),

                    // Parola Gücü Göstergesi (Kayıt ekranında)
                    if (_isSignUp && _passwordController.text.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: strength,
                                backgroundColor: Colors.white10,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  strength < 0.4
                                      ? Colors.redAccent
                                      : (strength < 0.7 ? Colors.orangeAccent : Colors.greenAccent),
                                ),
                                minHeight: 4,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            strength < 0.4
                                ? 'Zayıf'
                                : (strength < 0.7 ? 'Orta' : 'Güçlü'),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: strength < 0.4
                                  ? Colors.redAccent
                                  : (strength < 0.7 ? Colors.orangeAccent : Colors.greenAccent),
                            ),
                          ),
                        ],
                      ),
                    ],

                    // Kayıt Ol ekranında Şifre Doğrulama
                    if (_isSignUp) ...[
                      const SizedBox(height: 14),
                      TextField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmPassword,
                        decoration: InputDecoration(
                          labelText: 'Parola Tekrar',
                          prefixIcon: const Icon(Icons.lock_reset, color: Color(0xFF00E5FF)),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                              size: 20,
                              color: Colors.grey,
                            ),
                            onPressed: () =>
                                setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                          ),
                          filled: true,
                          fillColor: const Color(0xFF18202F),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Gönder Butonu
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: auth.isLoading ? null : _handleSubmit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00E5FF),
                          foregroundColor: Colors.black,
                          elevation: 4,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: auth.isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                              )
                            : Text(
                                _isSignUp ? 'GÜVENLİ HESAP OLUŞTUR' : 'GİRİŞ YAP',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1),
                              ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Supabase E-posta Doğrulama Bilgilendirme Notu
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(8),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white.withAlpha(15)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline, size: 16, color: Colors.amber.shade300),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Supabase E-Posta İpucu: Eğer gelen e-posta linki localhost açıyorsa, Supabase Dashboard -> Auth -> Providers -> Email altından "Confirm email" kapatılarak e-posta onaysız anında giriş yapılabilir.',
                              style: TextStyle(fontSize: 11, color: Colors.white.withAlpha(180), height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
