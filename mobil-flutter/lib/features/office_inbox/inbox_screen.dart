import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/supabase_service.dart';
import '../../models/inbox_item_model.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SupabaseService>().fetchInbox();
    });
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<SupabaseService>();
    final items = service.inboxItems;

    return Scaffold(
      appBar: AppBar(
        title: const Text('GELEN KUTUSU & ÖZETLER'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Yenile',
            onPressed: () => service.fetchInbox(),
          ),
        ],
      ),
      body: service.isInboxLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF)))
          : items.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  color: const Color(0xFF00E5FF),
                  onRefresh: () => service.fetchInbox(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return _buildInboxCard(context, item, service);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF00E5FF).withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.mark_email_unread_outlined, size: 64, color: Color(0xFF00E5FF)),
            ),
            const SizedBox(height: 20),
            const Text(
              'Henüz Özet veya Rapor Yok',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'PC Ajanına verdiğiniz Word/PDF özetleme, dosya analizi ve ekran kontrolü sonuçları otomatik olarak buraya kaydedilecektir.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Kutuyu Yenile'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF00E5FF),
                side: const BorderSide(color: Color(0xFF00E5FF)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => context.read<SupabaseService>().fetchInbox(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInboxCard(BuildContext context, InboxItemModel item, SupabaseService service) {
    final dateStr = item.createdAt != null
        ? DateFormat('dd.MM.yyyy HH:mm').format(item.createdAt!.toLocal())
        : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withAlpha(25)),
      ),
      color: const Color(0xFF131A26),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Üst Başlık ve Tarih
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E5FF).withAlpha(30),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.article_outlined, color: Color(0xFF00E5FF), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (dateStr.isNotEmpty)
                        Text(
                          dateStr,
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blueAccent.withAlpha(80)),
                  ),
                  child: const Text(
                    'PC Ajanı',
                    style: TextStyle(fontSize: 11, color: Colors.blueAccent, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: Colors.white12),
            const SizedBox(height: 12),

            // Özet / Rapor Metni
            SelectableText(
              item.body,
              style: const TextStyle(fontSize: 13, height: 1.45, color: Colors.white),
            ),
            const SizedBox(height: 14),

            // Aksiyon Butonları (Kopyala & Sil)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.copy, size: 16, color: Color(0xFF00E5FF)),
                  label: const Text('Kopyala', style: TextStyle(color: Color(0xFF00E5FF), fontSize: 12)),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: item.body));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Özet panoya kopyalandı!'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                  label: const Text('Sil', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: const Color(0xFF18202F),
                        title: const Text('Raporu Sil'),
                        content: const Text('Bu özeti gelen kutusundan silmek istediğinize emin misiniz?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Sil'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await service.deleteInboxItem(item.id);
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
