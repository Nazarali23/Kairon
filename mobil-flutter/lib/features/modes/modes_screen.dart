import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/supabase_service.dart';
import '../../core/constants.dart';

class ModesScreen extends StatelessWidget {
  const ModesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<SupabaseService>();
    final activeModes = service.robotState?.activeModesList ?? ['normal'];

    final modeKeys = [
      RobotModes.normal,
      RobotModes.office,
      RobotModes.focus,
      RobotModes.guard,
      RobotModes.care,
      RobotModes.sleep,
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('AKILLI MODLAR'),
        actions: [
          TextButton.icon(
            onPressed: () => service.setModes([RobotModes.normal]),
            icon: const Icon(Icons.restart_alt, size: 16, color: Colors.grey),
            label: const Text('Sıfırla', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Çoklu Çalışma Modları',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E5FF).withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF00E5FF).withAlpha(80)),
                ),
                child: Text(
                  '${activeModes.length} Mod Aktif',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00E5FF),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'İstediğiniz modları aynı anda etkinleştirebilirsiniz (Örn: Siber Ofis + Derin Odak, veya Asistan + Bekçi).',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          ...modeKeys.map((mode) {
            final isSelected = activeModes.contains(mode);
            final title = RobotModes.titles[mode] ?? mode;
            final desc = RobotModes.descriptions[mode] ?? '';
            final color = RobotModes.colors[mode] ?? Colors.cyan;
            final icon = RobotModes.icons[mode] ?? Icons.settings;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isSelected ? color : Colors.white.withAlpha(20),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => service.toggleMode(mode),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: color.withAlpha(isSelected ? 60 : 30),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: color, size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: isSelected ? color : Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              desc,
                              style: const TextStyle(fontSize: 12, color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Switch(
                        value: isSelected,
                        activeColor: color,
                        onChanged: (_) => service.toggleMode(mode),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
