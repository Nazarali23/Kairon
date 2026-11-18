import 'package:flutter_test/flutter_test.dart';
import 'package:kairon_mobile/main.dart';

void main() {
  testWidgets('KaironApp temel açılış testi', (WidgetTester tester) async {
    await tester.pumpWidget(const KaironApp());
    expect(find.text('Panel'), findsOneWidget);
  });
}
