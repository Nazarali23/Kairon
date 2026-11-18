import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/supabase_service.dart';
import '../../services/auth_service.dart';
import '../console/console_modal.dart';
import '../pairing/pairing_dialog.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<SupabaseService>();
    final auth = context.watch<AuthService>();
    final state = service.robotState;

    final styles = [
      {'key': 'komik', 'name': 'Şakacı (Komik)', 'desc': 'Espri yapar, neşeli ve mizah dolu yanıtlar verir.', 'icon': Icons.sentiment_very_satisfied},
      {'key': 'ciddi', 'name': 'Ciddi', 'desc': 'Kısa, resmi ve doğrudan amaca yönelik konuşur.', 'icon': Icons.business_center_outlined},
      {'key': 'zeki', 'name': 'Zeki & Bilimsel', 'desc': 'Analitik, detaylı ve bilgi ağırlıklı yaklaşır.', 'icon': Icons.psychology_outlined},
      {'key': 'soguk', 'name': 'Soğuk (Az Konuşan)', 'desc': 'Gereksiz konuşmaz, az ve öz bilgi verir.', 'icon': Icons.ac_unit_outlined},
      {'key': 'sevimli', 'name': 'Sevimli & Duygusal', 'desc': 'Sıcakkanlı, empatik ve şefkatli bir dil kullanır.', 'icon': Icons.favorite_border},
      {'key': 'otomatik', 'name': 'Otomatik (Dinamik)', 'desc': 'Ortama, saate ve ruh haline göre kendi belirler.', 'icon': Icons.auto_awesome_outlined},
    ];

    final currentStyle = state?.styleMode ?? 'otomatik';

    return Scaffold(
      appBar: AppBar(
        title: const Text('ROBOT & CİHAZ AYARLARI'),
        actions: [
          IconButton(
            icon: const Icon(Icons.terminal, color: Color(0xFF00E5FF)),
            tooltip: 'Kairon IDE Test Konsolu',
            onPressed: () => ConsoleModal.show(context),
          ),
        ],
      ),
      body: state == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 1. KİŞİLİK VE KARAKTER SEÇİMİ
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.theater_comedy, color: Color(0xFF00E5FF), size: 22),
                            SizedBox(width: 8),
                            Text('Robot Karakter & Kişilik Tarzı', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Kairon\'un sesli konuşma üslubunu ve benimsediği karakteri mobilden anında değiştirin.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const Divider(height: 24),
                        ...styles.map((st) {
                          final isSelected = (currentStyle.toLowerCase() == st['key']);
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF00E5FF).withAlpha(30) : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? const Color(0xFF00E5FF) : Colors.white.withAlpha(15),
                              ),
                            ),
                            child: ListTile(
                              dense: true,
                              leading: Icon(
                                st['icon'] as IconData,
                                color: isSelected ? const Color(0xFF00E5FF) : Colors.white70,
                              ),
                              title: Text(
                                st['name'] as String,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? const Color(0xFF00E5FF) : Colors.white,
                                ),
                              ),
                              subtitle: Text(
                                st['desc'] as String,
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                              trailing: isSelected
                                  ? const Icon(Icons.check_circle, color: Color(0xFF00E5FF), size: 20)
                                  : null,
                              onTap: () => service.setStyleMode(st['key'] as String),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 2. DONANIM VE SES KONTROLÜ
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.volume_up, color: Color(0xFF00E5FF), size: 22),
                            SizedBox(width: 8),
                            Text('Ses & Hoparlör Seviyesi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Icon(Icons.volume_mute, size: 20, color: Colors.grey),
                            Expanded(
                              child: Slider(
                                value: state.volume.toDouble(),
                                min: 0,
                                max: 100,
                                divisions: 20,
                                activeColor: const Color(0xFF00E5FF),
                                label: '%${state.volume}',
                                onChanged: (val) => service.setVolume(val.round()),
                              ),
                            ),
                            Text('%${state.volume}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 3. EKRAN & TFT PARLAKLIK KONTROLÜ
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.brightness_medium, color: Color(0xFF00E5FF), size: 22),
                            SizedBox(width: 8),
                            Text('ST7789 TFT Ekran & Görünüm', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            const Icon(Icons.brightness_low, size: 20, color: Colors.grey),
                            Expanded(
                              child: Slider(
                                value: state.screenBrightness.toDouble(),
                                min: 0,
                                max: 100,
                                divisions: 10,
                                activeColor: Colors.amberAccent,
                                label: '%${state.screenBrightness}',
                                onChanged: (val) => service.setScreenBrightness(val.round()),
                              ),
                            ),
                            Text('%${state.screenBrightness}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.access_time, size: 16),
                                label: const Text('Saat Ekranına Geç'),
                                style: OutlinedButton.styleFrom(foregroundColor: Colors.white70),
                                onPressed: () => service.executeConsoleCommand('/saat'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.qr_code, size: 16),
                                label: const Text('QR Göster / Gizle'),
                                style: OutlinedButton.styleFrom(foregroundColor: Colors.white70),
                                onPressed: () => service.executeConsoleCommand('/qr'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 4. HESAP VE CİHAZ EŞLEŞTİRME BİLGİSİ
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.fingerprint, color: Color(0xFF00E5FF), size: 22),
                            SizedBox(width: 8),
                            Text('Hesap ve Cihaz Güvenliği', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const Divider(height: 24),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Giriş Yapan Kullanıcı'),
                          subtitle: Text(auth.currentUser?.email ?? 'Bilinmiyor'),
                          leading: const Icon(Icons.person_pin, color: Colors.grey),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Kullanıcı UUID'),
                          subtitle: Text(auth.currentUser?.id ?? '-', style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
                          leading: const Icon(Icons.key, color: Colors.grey),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF00E5FF),
                                  foregroundColor: Colors.black,
                                ),
                                icon: const Icon(Icons.qr_code_scanner, size: 18),
                                label: const Text('Yeni Cihaz Bağla'),
                                onPressed: () => PairingDialog.show(context),
                              ),
                            ),
                            const SizedBox(width: 10),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.redAccent,
                                side: const BorderSide(color: Colors.redAccent),
                              ),
                              icon: const Icon(Icons.logout, size: 18),
                              label: const Text('Çıkış'),
                              onPressed: () => auth.signOut(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
