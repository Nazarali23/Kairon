import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/supabase_service.dart';

class ConsoleModal extends StatefulWidget {
  const ConsoleModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ConsoleModal(),
    );
  }

  @override
  State<ConsoleModal> createState() => _ConsoleModalState();
}

class _ConsoleModalState extends State<ConsoleModal> {
  final TextEditingController _cmdController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<String> _localLogs = [];
  String _lastSeenOutput = '';
  bool _isExecuting = false;

  @override
  void initState() {
    super.initState();
    _localLogs.add('[SİSTEM] Kairon IDE Test Terminaline bağlanıldı.');
    _localLogs.add('[BİLGİ] Komutlar doğrudan donanım seri hattında (Console.h) çalıştırılır.');
    _localLogs.add('[BİLGİ] Veritabanında kalıcı kayıt oluşturulmaz (Geçici oturum).');
  }

  @override
  void dispose() {
    _cmdController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendCommand(String cmd) async {
    final text = cmd.trim();
    if (text.isEmpty || _isExecuting) return;

    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    setState(() {
      _localLogs.add('[$timestamp] > $text');
      _isExecuting = true;
    });
    _scrollToBottom();
    _cmdController.clear();

    final service = context.read<SupabaseService>();
    final ok = await service.executeConsoleCommand(text);
    if (!ok && mounted) {
      setState(() {
        _localLogs.add('[$timestamp] [HATA] Komut iletilemedi.');
        _isExecuting = false;
      });
      _scrollToBottom();
    }
  }

  void _showCommandPalette() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF131A26),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final categories = [
          {
            'title': '📡 Sensör ve Çevre',
            'commands': [
              {'cmd': '/sonar', 'desc': 'Mesafe ve kullanıcı algılama durumunu sorgula'},
              {'cmd': '/sonar test', 'desc': 'Ultrasonik sensör self-test çalıştır'},
              {'cmd': '/time', 'desc': 'Robot donanım sistem saatini oku'},
            ],
          },
          {
            'title': '🧠 Yapay Zeka ve Hafıza',
            'commands': [
              {'cmd': '/brain', 'desc': 'LLM, hafıza ve karar motoru durumu'},
              {'cmd': '/mem', 'desc': 'Kayıtlı hafıza / anı listesini dök'},
              {'cmd': '/days', 'desc': 'Takvim ve kayıtlı özel günleri listele'},
              {'cmd': '/models', 'desc': 'Kullanılabilir Groq LLM modellerini listele'},
            ],
          },
          {
            'title': '🤖 Kafa & Servo Mekaniği',
            'commands': [
              {'cmd': '/kafa evet', 'desc': 'Kafayı onaylar şekilde salla'},
              {'cmd': '/kafa hayir', 'desc': 'Kafayı reddeder şekilde salla'},
              {'cmd': '/kafa uyu', 'desc': 'Başlangıç merkez açısına dön'},
              {'cmd': '/kafa sol', 'desc': 'Sola bak'},
              {'cmd': '/kafa sag', 'desc': 'Sağa bak'},
            ],
          },
          {
            'title': '🔊 Ses & Konuşma',
            'commands': [
              {'cmd': '/say Test mesajı, Kairon donanım sesi çalışıyor.', 'desc': 'Hoparlör ses testi'},
              {'cmd': '/vol 0.8', 'desc': 'Ses seviyesini %80 olarak ayarla'},
            ],
          },
          {
            'title': '🎭 Kişilik & Karakter',
            'commands': [
              {'cmd': '/style komik', 'desc': 'Şakacı / Mizahi karakter'},
              {'cmd': '/style ciddi', 'desc': 'Ciddi ve net karakter'},
              {'cmd': '/style zeki', 'desc': 'Bilimsel ve zeki karakter'},
              {'cmd': '/style sevimli', 'desc': 'Duygusal ve sevimli karakter'},
              {'cmd': '/style otomatik', 'desc': 'Dinamik ortama göre uyarlanan karakter'},
            ],
          },
          {
            'title': '⚡ Sistem & Güvenlik',
            'commands': [
              {'cmd': '/saat', 'desc': 'ST7789 TFT Saat ekranına geç'},
              {'cmd': '/qr', 'desc': 'Eşleştirme QR / PIN ekranını aç/kapat'},
              {'cmd': '/owner', 'desc': 'Eşleşen sahip kullanıcı UUID bilgisini göster'},
              {'cmd': '/restart', 'desc': 'ESP32 donanımını yeniden başlat'},
            ],
          },
        ];

        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Hazır Komut Listesi (Console.h)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF00E5FF)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(color: Colors.white12),
              Expanded(
                child: ListView.builder(
                  itemCount: categories.length,
                  itemBuilder: (_, catIdx) {
                    final cat = categories[catIdx];
                    final cmds = cat['commands'] as List<Map<String, String>>;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 12, bottom: 6),
                          child: Text(
                            cat['title'] as String,
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amberAccent),
                          ),
                        ),
                        ...cmds.map((c) => ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                c['cmd']!,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  color: Color(0xFF00E5FF),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(c['desc']!, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                              trailing: const Icon(Icons.play_arrow, size: 18, color: Color(0xFF00E5FF)),
                              onTap: () {
                                Navigator.pop(ctx);
                                _sendCommand(c['cmd']!);
                              },
                            )),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<SupabaseService>();
    final currentOutput = service.robotState?.consoleOutput ?? '';

    // Yeni çıktı gelmişse loga ekle
    if (currentOutput.isNotEmpty && currentOutput != _lastSeenOutput) {
      _lastSeenOutput = currentOutput;
      _isExecuting = false;
      final timestamp = DateTime.now().toIso8601String().substring(11, 19);
      _localLogs.add('[$timestamp] [ROBOT] $currentOutput');
      _scrollToBottom();
    }

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottomInset),
      decoration: const BoxDecoration(
        color: Color(0xFF070B12),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Tutamaç
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Başlık ve Eylemler
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Colors.greenAccent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'KAIRON IDE TERMİNAL',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: Color(0xFF00E5FF),
                ),
              ),
              const Spacer(),
              // Komut Listesi Açma Butonu
              TextButton.icon(
                onPressed: _showCommandPalette,
                icon: const Icon(Icons.list_alt, size: 16, color: Colors.amberAccent),
                label: const Text('Komutlar', style: TextStyle(fontSize: 12, color: Colors.amberAccent)),
              ),
              // Temizle Butonu
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20, color: Colors.grey),
                tooltip: 'Terminali Temizle',
                onPressed: () {
                  setState(() => _localLogs.clear());
                  service.clearConsoleOutput();
                },
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Terminal Çıktı Ekranı
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0B1019),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withAlpha(20)),
              ),
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _localLogs.length + (_isExecuting ? 1 : 0),
                itemBuilder: (_, idx) {
                  if (_isExecuting && idx == _localLogs.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00E5FF)),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Komut robot tarafından işleniyor...',
                            style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }

                  final log = _localLogs[idx];
                  Color color = Colors.white70;
                  if (log.contains('>')) color = const Color(0xFF00E5FF);
                  else if (log.contains('[ROBOT]')) color = Colors.greenAccent;
                  else if (log.contains('[HATA]')) color = Colors.redAccent;
                  else if (log.contains('[BİLGİ]')) color = Colors.grey;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: SelectableText(
                      log,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: color,
                        height: 1.3,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Komut Giriş Alanı
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _cmdController,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 14,
                    color: Color(0xFF00E5FF),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Komut yazın (örn: /sonar, /brain, /time)...',
                    hintStyle: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.grey),
                    prefixIcon: const Icon(Icons.terminal, color: Color(0xFF00E5FF)),
                    filled: true,
                    fillColor: const Color(0xFF131A26),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  onSubmitted: _sendCommand,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF00E5FF),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.all(12),
                ),
                icon: const Icon(Icons.send, size: 20),
                onPressed: () => _sendCommand(_cmdController.text),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
