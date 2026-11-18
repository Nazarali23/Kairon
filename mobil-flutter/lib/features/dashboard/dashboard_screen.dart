import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/supabase_service.dart';
import '../../services/auth_service.dart';
import '../pairing/pairing_dialog.dart';
import '../console/console_modal.dart';
import '../../core/constants.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final TextEditingController _sayController = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _sayController.dispose();
    super.dispose();
  }

  void _handleSend() async {
    final text = _sayController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);
    final service = context.read<SupabaseService>();
    final ok = await service.sendPendingSay(text);
    setState(() => _isSending = false);

    if (mounted) {
      if (ok) {
        _sayController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Konuşma metni robota iletildi!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: ${service.errorMessage ?? "İletilemedi"}')),
        );
      }
    }
  }

  void _showPersonalitySelector(BuildContext context, String currentStyle) {
    final service = context.read<SupabaseService>();
    final styles = [
      {'key': 'komik', 'name': 'Şakacı (Komik)', 'desc': 'Espri yapar, mizah doludur', 'icon': Icons.sentiment_very_satisfied},
      {'key': 'ciddi', 'name': 'Ciddi', 'desc': 'Kısa, resmi ve doğrudan amaca yönelik', 'icon': Icons.business_center_outlined},
      {'key': 'zeki', 'name': 'Zeki & Bilimsel', 'desc': 'Analitik ve detaylı yanıtlar verir', 'icon': Icons.psychology_outlined},
      {'key': 'soguk', 'name': 'Soğuk (Az Konuşan)', 'desc': 'Az ve öz bilgi verir', 'icon': Icons.ac_unit_outlined},
      {'key': 'sevimli', 'name': 'Sevimli & Duygusal', 'desc': 'Şefkatli ve empatik bir dil kullanır', 'icon': Icons.favorite_border},
      {'key': 'otomatik', 'name': 'Otomatik (Dinamik)', 'desc': 'Ortama ve duruma göre uyarlar', 'icon': Icons.auto_awesome_outlined},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF131A26),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Robot Karakter / Kişilik Seç',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF00E5FF)),
              ),
              const SizedBox(height: 12),
              ...styles.map((st) {
                final isSelected = currentStyle.toLowerCase() == st['key'];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF00E5FF).withAlpha(30) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isSelected ? const Color(0xFF00E5FF) : Colors.white12),
                  ),
                  child: ListTile(
                    dense: true,
                    leading: Icon(st['icon'] as IconData, color: isSelected ? const Color(0xFF00E5FF) : Colors.grey),
                    title: Text(st['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(st['desc'] as String, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    trailing: isSelected ? const Icon(Icons.check, color: Color(0xFF00E5FF)) : null,
                    onTap: () {
                      service.setStyleMode(st['key'] as String);
                      Navigator.pop(ctx);
                    },
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<SupabaseService>();
    final state = service.robotState;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.bolt, color: Color(0xFF00E5FF)),
            SizedBox(width: 8),
            Text('KAIRON PANEL'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.terminal, color: Color(0xFF00E5FF)),
            tooltip: 'Kairon IDE Test Terminali',
            onPressed: () => ConsoleModal.show(context),
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner, color: Color(0xFF00E5FF)),
            tooltip: 'Cihaz Eşleştir (Robot & PC)',
            onPressed: () => PairingDialog.show(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Yenile',
            onPressed: () {
              service.fetchRobotState();
              service.fetchPcState();
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, size: 20),
            tooltip: 'Oturumu Kapat',
            onPressed: () => context.read<AuthService>().signOut(),
          ),
        ],
      ),
      body: service.isLoading && state == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Durum Rozetleri (Robot, Oda, PC)
                  _buildStatusBadges(state, service.isPcOnline),
                  const SizedBox(height: 16),

                  // Kairon IDE Test Terminali Hızlı Buton & Durum Kartı
                  _buildTerminalQuickCard(),
                  const SizedBox(height: 16),

                  // Aktif Çalışma Modları (Çoklu Mod)
                  _buildActiveModesCard(state?.activeModesList ?? ['normal']),
                  const SizedBox(height: 16),

                  // Robot Kişilik / Karakter Kartı
                  _buildPersonalityCard(state?.styleMode ?? 'otomatik'),
                  const SizedBox(height: 16),

                  // Hızlı Konuşturma Kutusu (pending_say)
                  _buildQuickSayCard(),
                  const SizedBox(height: 16),

                  // Hızlı Ses & Ekran Kontrolleri
                  if (state != null) _buildHardwareControlCard(state),
                ],
              ),
            ),
    );
  }

  Widget _buildStatusBadges(dynamic state, bool isPcOnline) {
    final bool isRobotOnline = state?.isOnline ?? false;
    final bool isRoomOccupied = state?.roomOccupied ?? false;

    return Row(
      children: [
        Expanded(
          child: _badgeCard(
            label: 'Robot',
            status: isRobotOnline ? 'Çevrimiçi' : 'Çevrimdışı',
            color: isRobotOnline ? Colors.greenAccent : Colors.redAccent,
            icon: Icons.smart_toy,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _badgeCard(
            label: 'Oda',
            status: isRoomOccupied ? 'Dolu' : 'Boş',
            color: isRoomOccupied ? Colors.amberAccent : Colors.blueGrey,
            icon: Icons.meeting_room,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _badgeCard(
            label: 'PC Ajanı',
            status: isPcOnline ? 'Bağlı' : 'Kapalı',
            color: isPcOnline ? Colors.cyanAccent : Colors.grey,
            icon: Icons.desktop_windows,
          ),
        ),
      ],
    );
  }

  Widget _badgeCard({
    required String label,
    required String status,
    required Color color,
    required IconData icon,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 2),
            Text(
              status,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTerminalQuickCard() {
    return Card(
      color: const Color(0xFF0F1522),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: const Color(0xFF00E5FF).withAlpha(40)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => ConsoleModal.show(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E5FF).withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.terminal, color: Color(0xFF00E5FF), size: 28),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'KAIRON IDE TEST KONSOLU',
                      style: TextStyle(fontFamily: 'monospace', fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF00E5FF)),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Console.h komutlarını çalıştırın (/sonar, /brain, /kafa, /time) ve yanıtları anında izleyin.',
                      style: TextStyle(fontSize: 11, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: Color(0xFF00E5FF)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveModesCard(List<String> activeModes) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.tune, size: 18, color: Color(0xFF00E5FF)),
                    SizedBox(width: 6),
                    Text('ETKİN MODLAR (ÇOKLU)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E5FF).withAlpha(30),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${activeModes.length} Aktif',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF00E5FF)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: activeModes.map((mode) {
                final title = RobotModes.titles[mode] ?? mode;
                final color = RobotModes.colors[mode] ?? Colors.cyan;
                final icon = RobotModes.icons[mode] ?? Icons.settings;

                return Chip(
                  avatar: Icon(icon, size: 16, color: color),
                  label: Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
                  backgroundColor: color.withAlpha(30),
                  side: BorderSide(color: color.withAlpha(80)),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalityCard(String currentStyle) {
    final styleMap = {
      'komik': 'Şakacı (Komik)',
      'ciddi': 'Ciddi',
      'zeki': 'Zeki & Bilimsel',
      'soguk': 'Soğuk (Az Konuşan)',
      'sevimli': 'Sevimli & Duygusal',
      'otomatik': 'Otomatik (Dinamik)',
    };
    final styleName = styleMap[currentStyle.toLowerCase()] ?? currentStyle;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.purpleAccent.withAlpha(30),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.theater_comedy, color: Colors.purpleAccent, size: 24),
        ),
        title: const Text('ROBOT KİŞİLİĞİ', style: TextStyle(fontSize: 11, color: Colors.grey)),
        subtitle: Text(
          styleName,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.purpleAccent),
        ),
        trailing: OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.purpleAccent,
            side: BorderSide(color: Colors.purpleAccent.withAlpha(120)),
          ),
          onPressed: () => _showPersonalitySelector(context, currentStyle),
          child: const Text('Değiştir'),
        ),
      ),
    );
  }

  Widget _buildQuickSayCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.record_voice_over, color: Color(0xFF00E5FF), size: 20),
                SizedBox(width: 8),
                Text('Kairon\'a Söylet (pending_say)', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _sayController,
              maxLength: 250,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Robota seslendirmek istediğiniz Türkçe cümleyi yazın...',
                hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFF131A26),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: _isSending ? null : _handleSend,
                icon: _isSending
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send, size: 16),
                label: const Text('Seslendir'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E5FF),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHardwareControlCard(dynamic state) {
    final service = context.read<SupabaseService>();
    final int vol = state.volume;
    final int bright = state.screenBrightness;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Hızlı Donanım Kontrolleri', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            // Ses Seviyesi
            Row(
              children: [
                const Icon(Icons.volume_up, size: 18, color: Color(0xFF00E5FF)),
                const SizedBox(width: 8),
                Text('Ses: %$vol', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                Expanded(
                  child: Slider(
                    value: vol.toDouble(),
                    min: 0,
                    max: 100,
                    divisions: 20,
                    activeColor: const Color(0xFF00E5FF),
                    onChanged: (val) => service.setVolume(val.toInt()),
                  ),
                ),
              ],
            ),
            // Ekran Parlaklığı
            Row(
              children: [
                const Icon(Icons.brightness_medium, size: 18, color: Colors.amberAccent),
                const SizedBox(width: 8),
                Text('Ekran: %$bright', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                Expanded(
                  child: Slider(
                    value: bright.toDouble(),
                    min: 0,
                    max: 100,
                    divisions: 10,
                    activeColor: Colors.amberAccent,
                    onChanged: (val) => service.setScreenBrightness(val.toInt()),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
