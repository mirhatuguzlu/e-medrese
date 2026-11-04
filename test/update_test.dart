import 'package:e_medrese/data/repositories/auth_repository.dart';
import 'package:e_medrese/main.dart';
import 'package:e_medrese/services/update_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('yeni sürüm karşılaştırması', () {
    expect(isNewerVersion('v2.4.0', '2.3.3'), isTrue);
    expect(isNewerVersion('v2.3.10', '2.3.9'), isTrue);
    expect(isNewerVersion('v3.0.0', '2.9.9'), isTrue);
    expect(isNewerVersion('v2.3.3', '2.3.3'), isFalse);
    expect(isNewerVersion('v2.3.2', '2.3.3'), isFalse);
    expect(isNewerVersion('2.4.0+22', '2.4.0'), isFalse);
  });

  Future<void> pumpApp(WidgetTester tester, {required bool update}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith((ref) => Stream<Session?>.value(null)),
          updateRequiredProvider.overrideWith((ref) async => update),
        ],
        child: const App(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('yeni sürüm varsa uygulama yerine güncelleme sayfası', (
    tester,
  ) async {
    await pumpApp(tester, update: true);
    expect(find.text('Yeni sürüm hazır'), findsOneWidget);
    expect(find.text('Uygulamayı güncelle'), findsOneWidget);
    expect(find.text('Hesabına giriş yap'), findsNothing);
  });

  testWidgets('güncelse uygulama açılır', (tester) async {
    await pumpApp(tester, update: false);
    expect(find.text('Yeni sürüm hazır'), findsNothing);
    expect(find.text('Hesabına giriş yap'), findsOneWidget);
  });
}
