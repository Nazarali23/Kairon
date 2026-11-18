import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/supabase_service.dart';
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
            icon: const Icon(Icons.refresh),
            onPressed: () {
              service.fetchRobotState();
              service.fetchPcState();
            },
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

                  // Aktif Çalışma Modu Kartı
                  _buildActiveModeCard(state?.activeMode ?? 'normal'),
                  const SizedBox(height: 16),

                  // Hızlı Konuşturma Kutusu (pending_say)
                  _buildQuickSayCard(),
                  const SizedBox(height: 16),

                  // Hızlı Ses Kontrolü
                  if (state != null) _buildVolumeCard(state.volume),
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

  Widget _buildActiveModeCard(String mode) {
    final title = RobotModes.titles[mode] ?? mode;
    final desc = RobotModes.descriptions[mode] ?? '';
    final color = RobotModes.colors[mode] ?? Colors.cyan;
    final icon = RobotModes.icons[mode] ?? Icons.mode;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withAlpha(40),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('AKTİF ÇALIŞMA MODU', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
                  const SizedBox(height: 2),
                  Text(desc, style: const TextStyle(fontSize: 12, color: Colors.white70)),
                ],
              ),
            ),
          ],
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

  Widget _buildVolumeCard(int currentVol) {
    final service = context.read<SupabaseService>();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Hoparlör Ses Seviyesi', style: TextStyle(fontWeight: FontWeight.w600)),
                Text('%$currentVol', style: const TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold)),
              ],
            ),
            Slider(
              value: currentVol.toDouble(),
              min: 0,
              max: 100,
              divisions: 20,
              activeColor: const Color(0xFF00E5FF),
              onChanged: (val) {
                service.setVolume(val.toInt());
              },
            ),
          ],
        ),
      ),
    );
  }
}
