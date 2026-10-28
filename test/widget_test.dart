import 'package:e_medrese/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App smoke test', (tester) async {
    await tester.pumpWidget(const App());
    expect(find.text('e-Medrese'), findsOneWidget);
  });
}
