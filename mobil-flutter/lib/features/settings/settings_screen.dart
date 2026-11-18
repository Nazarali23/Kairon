import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/supabase_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<SupabaseService>();
    final state = service.robotState;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ROBOT AYARLARI'),
      ),
      body: state == null
          ? const Center(child: Text('Robot durumu yükleniyor...'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Görünüm ve Yüz', style: TextStyle(fontWeight: FontWeight.bold)),
                        const Divider(height: 24),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Göz Rengi'),
                          subtitle: Text(state.eyeColor),
                          leading: CircleAvatar(
                            backgroundColor: Color(int.parse(state.eyeColor.replaceFirst('#', '0xFF'))),
                            radius: 14,
                          ),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Yüz Stili'),
                          subtitle: Text(state.faceStyle),
                          leading: const Icon(Icons.face),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Ses ve TTS Parametreleri', style: TextStyle(fontWeight: FontWeight.bold)),
                        const Divider(height: 24),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('TTS Konuşma Hızı'),
                          subtitle: Text('${state.ttsSpeed}x'),
                          leading: const Icon(Icons.speed),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('TTS Ses Tonu (Pitch)'),
                          subtitle: Text('${state.ttsPitch}'),
                          leading: const Icon(Icons.graphic_eq),
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
