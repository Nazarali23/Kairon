import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/supabase_service.dart';
import '../../models/reminder_model.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SupabaseService>().fetchReminders();
    });
  }

  void _showAddDialog() {
    final textController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.now();
    String recurring = 'none';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF131A26),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;

            return Padding(
              padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottomInset),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Yeni Hatırlatıcı Ekle',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF00E5FF)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Hatırlatıcı Metni
                  TextField(
                    controller: textController,
                    decoration: InputDecoration(
                      labelText: 'Hatırlatılacak Not / Görev',
                      hintText: 'Örn: 12:30\'da sınav için evden çık',
                      prefixIcon: const Icon(Icons.alarm, color: Color(0xFF00E5FF)),
                      filled: true,
                      fillColor: const Color(0xFF18202F),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Tarih ve Saat Seçimi
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: Text(DateFormat('dd.MM.yyyy').format(selectedDate)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(color: Colors.white.withAlpha(40)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime.now().subtract(const Duration(days: 1)),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) {
                              setModalState(() => selectedDate = picked);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.access_time, size: 16),
                          label: Text(
                            '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}',
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(color: Colors.white.withAlpha(40)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: selectedTime,
                            );
                            if (picked != null) {
                              setModalState(() => selectedTime = picked);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Tekrarlama Seçimi
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF18202F),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: recurring,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF18202F),
                        items: const [
                          DropdownMenuItem(value: 'none', child: Text('Tek Seferlik')),
                          DropdownMenuItem(value: 'daily', child: Text('Her Gün Tekrarla')),
                          DropdownMenuItem(value: 'weekly', child: Text('Her Hafta Tekrarla')),
                        ],
                        onChanged: (val) {
                          if (val != null) setModalState(() => recurring = val);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Kaydet Butonu
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00E5FF),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      final text = textController.text.trim();
                      if (text.isEmpty) return;

                      final dueStr =
                          '${DateFormat('yyyy-MM-dd').format(selectedDate)} ${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}';

                      final service = context.read<SupabaseService>();
                      final ok = await service.addReminder(text, dueStr, recurring: recurring);
                      if (mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: ok ? Colors.green : Colors.redAccent,
                            content: Text(ok ? 'Hatırlatıcı robota iletildi!' : 'Kaydedilemedi.'),
                          ),
                        );
                      }
                    },
                    child: const Text('Robot Hafızasına Kaydet', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<SupabaseService>();
    final reminders = service.reminders;

    return Scaffold(
      appBar: AppBar(
        title: const Text('HATIRLATICILAR & ALARMLAR'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => service.fetchReminders(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF00E5FF),
        foregroundColor: Colors.black,
        onPressed: _showAddDialog,
        child: const Icon(Icons.add_alarm),
      ),
      body: service.isRemindersLoading
          ? const Center(child: CircularProgressIndicator())
          : reminders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.notifications_none, size: 56, color: Colors.grey),
                      const SizedBox(height: 12),
                      const Text(
                        'Henüz bir hatırlatıcı eklenmemiş.',
                        style: TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Alttaki butona tıklayarak robotun tam saatinde söyleyeceği bildirimler ekleyin.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00E5FF),
                          foregroundColor: Colors.black,
                        ),
                        onPressed: _showAddDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('Hatırlatıcı Oluştur'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: reminders.length,
                  itemBuilder: (_, idx) {
                    final item = reminders[idx];
                    final isDone = item.asked;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: isDone ? Colors.white12 : const Color(0xFF00E5FF).withAlpha(50),
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: IconButton(
                          icon: Icon(
                            isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                            color: isDone ? Colors.greenAccent : const Color(0xFF00E5FF),
                          ),
                          onPressed: () {
                            if (item.id != null) {
                              service.toggleReminderAsked(item.id!, isDone);
                            }
                          },
                        ),
                        title: Text(
                          item.text,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            decoration: isDone ? TextDecoration.lineThrough : null,
                            color: isDone ? Colors.grey : Colors.white,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Row(
                            children: [
                              Icon(Icons.access_time, size: 14, color: isDone ? Colors.grey : Colors.amberAccent),
                              const SizedBox(width: 4),
                              Text(
                                item.due,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDone ? Colors.grey : Colors.amberAccent,
                                ),
                              ),
                              if (item.recurring != 'none') ...[
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withAlpha(40),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    item.recurring == 'daily' ? 'Her Gün' : 'Haftalık',
                                    style: const TextStyle(fontSize: 10, color: Colors.blueAccent),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                          onPressed: () {
                            if (item.id != null) {
                              service.deleteReminder(item.id!);
                            }
                          },
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
