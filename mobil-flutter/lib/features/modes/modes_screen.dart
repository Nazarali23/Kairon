import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/supabase_service.dart';
import '../../core/constants.dart';

class ModesScreen extends StatelessWidget {
  const ModesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<SupabaseService>();
    final currentMode = service.robotState?.activeMode ?? 'normal';

    final modeKeys = [
      RobotModes.normal,
      RobotModes.focus,
      RobotModes.guard,
      RobotModes.sleep,
      RobotModes.care,
      RobotModes.office,
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('AKILLI MODLAR'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Çalışma Modu Seçimi',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Mod değiştiğinde robotun sensör kontrol ve davranış kuralları anında güncellenir.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          ...modeKeys.map((mode) {
            final isSelected = (mode == currentMode);
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
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withAlpha(isSelected ? 60 : 30),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                title: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isSelected ? color : Colors.white,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(desc, style: const TextStyle(fontSize: 12, color: Colors.white70)),
                ),
                trailing: isSelected
                    ? Icon(Icons.check_circle, color: color, size: 24)
                    : OutlinedButton(
                        onPressed: () => service.setMode(mode),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: color,
                          side: BorderSide(color: color.withAlpha(120)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Seç'),
                      ),
                onTap: () => service.setMode(mode),
              ),
            );
          }),
        ],
      ),
    );
  }
}
