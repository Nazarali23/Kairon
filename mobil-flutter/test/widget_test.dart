import 'package:flutter_test/flutter_test.dart';
import 'package:kairon_mobile/main.dart';

void main() {
  testWidgets('KaironApp temel açılış testi (Giriş Ekranı)', (WidgetTester tester) async {
    await tester.pumpWidget(const KaironApp());
    expect(find.text('KAIRON ASİSTAN'), findsOneWidget);
    expect(find.text('Giriş Yap'), findsWidgets);
  });
}
