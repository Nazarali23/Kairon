import 'package:flutter/material.dart';

class TelemetryScreen extends StatelessWidget {
  const TelemetryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('IOT TELEMETRİ & GRAFİKLER'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.show_chart, size: 64, color: Colors.cyan.withAlpha(150)),
              const SizedBox(height: 16),
              const Text(
                'IoT Sensör Analizi & Grafikler (V2)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Postür mesafesi (HC-SR04), PIR hareketlilik ve uyku grafikleri V2 aşamasında fl_chart ile burada canlı çizilecektir.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
