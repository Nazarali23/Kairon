import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/supabase_service.dart';

class PairingDialog extends StatefulWidget {
  const PairingDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const PairingDialog(),
    );
  }

  @override
  State<PairingDialog> createState() => _PairingDialogState();
}

class _PairingDialogState extends State<PairingDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _codeController = TextEditingController();
  MobileScannerController? _scannerController;
  bool _isClaiming = false;
  bool _hasScanned = false;
  String? _statusMessage;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    try {
      _scannerController = MobileScannerController(
        detectionSpeed: DetectionSpeed.normal,
        facing: CameraFacing.back,
      );
    } catch (_) {
      _scannerController = null;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _codeController.dispose();
    _scannerController?.dispose();
    super.dispose();
  }

  void _handlePair([String? rawToken]) async {
    final code = (rawToken ?? _codeController.text).trim();
    if (code.isEmpty || _isClaiming) return;

    setState(() {
      _isClaiming = true;
      _statusMessage = null;
    });

    final auth = context.read<AuthService>();
    final supa = context.read<SupabaseService>();
    final result = await auth.claimDevice(code);

    if (!mounted) return;

    setState(() {
      _isClaiming = false;
      _statusMessage = result['message'] as String? ?? '';
      _isSuccess = result['success'] == true;
    });

    if (_isSuccess) {
      // Robot ve PC durumunu hemen güncelle
      await supa.fetchRobotState();
      await supa.fetchPcState();

      await Future.delayed(const Duration(milliseconds: 1200));
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF00E676),
            content: Text(_statusMessage ?? 'Eşleştirme başarılı!'),
          ),
        );
      }
    } else {
      setState(() => _hasScanned = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
      decoration: const BoxDecoration(
        color: Color(0xFF131A26),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
          const SizedBox(height: 14),
          const Row(
            children: [
              Icon(Icons.qr_code_scanner, color: Color(0xFF00E5FF), size: 24),
              SizedBox(width: 10),
              Text(
                'Cihaz Eşleştirme (Robot & PC)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Robotun ekranındaki veya PC ajanındaki QR kodu kamerayla tarayın ya da 6 haneli PIN kodunu girin.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 14),

          // Durum / Geri Bildirim Banner'ı (Görünür Inline Bildirim)
          if (_statusMessage != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _isSuccess
                    ? const Color(0xFF00E676).withAlpha(40)
                    : const Color(0xFFFF5252).withAlpha(40),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _isSuccess ? const Color(0xFF00E676) : const Color(0xFFFF5252),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isSuccess ? Icons.check_circle : Icons.error_outline,
                    color: _isSuccess ? const Color(0xFF00E676) : const Color(0xFFFF5252),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _statusMessage!,
                      style: TextStyle(
                        fontSize: 13,
                        color: _isSuccess ? const Color(0xFF00E676) : const Color(0xFFFF5252),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Sekmeler: Kamera ile Tara & Manuel Kod
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0B1019),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFF00E5FF),
              labelColor: const Color(0xFF00E5FF),
              unselectedLabelColor: Colors.grey,
              tabs: const [
                Tab(icon: Icon(Icons.camera_alt_outlined), text: 'Kamera ile Tara'),
                Tab(icon: Icon(Icons.pin_outlined), text: 'Manuel PIN'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Tab Bar Görünümleri
          Flexible(
            child: SizedBox(
              height: 310,
              child: TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildCameraScannerTab(),
                  _buildManualPinTab(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraScannerTab() {
    if (_scannerController == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.videocam_off_outlined, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            const Text(
              'Kamera bu ortamda kullanılamıyor.',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => _tabController.animateTo(1),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E5FF)),
              child: const Text('Manuel PIN Sekmesine Geç', style: TextStyle(color: Colors.black)),
            ),
          ],
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        alignment: Alignment.center,
        children: [
          MobileScanner(
            controller: _scannerController!,
            onDetect: (capture) {
              if (_hasScanned || _isClaiming) return;
              for (final barcode in capture.barcodes) {
                final code = barcode.rawValue;
                if (code != null && code.isNotEmpty) {
                  _hasScanned = true;
                  _handlePair(code);
                  break;
                }
              }
            },
          ),
          // Cyberpunk Hedef Çerçevesi (Reticle)
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF00E5FF), width: 2),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00E5FF).withAlpha(50),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'QR Kodu karenin içine getirin',
                style: TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ),
          ),
          if (_isClaiming)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xFF00E5FF)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildManualPinTab() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _codeController,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            letterSpacing: 6,
            color: Color(0xFF00E5FF),
          ),
          decoration: InputDecoration(
            hintText: '849201',
            hintStyle: const TextStyle(fontSize: 18, letterSpacing: 4, color: Colors.grey),
            filled: true,
            fillColor: const Color(0xFF18202F),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Hızlı PIN Doldurma Yardımcısı
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Hızlı PIN: ', style: TextStyle(color: Colors.grey, fontSize: 12)),
            ActionChip(
              label: const Text('849201 (Varsayılan PIN)', style: TextStyle(fontSize: 12, color: Color(0xFF00E5FF))),
              backgroundColor: const Color(0xFF18202F),
              side: const BorderSide(color: Color(0xFF00E5FF), width: 0.8),
              onPressed: () {
                _codeController.text = '849201';
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _isClaiming ? null : () => _handlePair(),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00E5FF),
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _isClaiming
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                )
              : const Text(
                  'Cihazı Hesabıma Bağla',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
        ),
      ],
    );
  }
}
