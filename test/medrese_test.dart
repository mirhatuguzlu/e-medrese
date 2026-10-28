import 'package:e_medrese/data/repositories/auth_repository.dart';
import 'package:e_medrese/data/repositories/medrese_repository.dart';
import 'package:e_medrese/presentation/features/home/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'fakes.dart';

void main() {
  late FakeMedreseRepository repo;

  Future<void> pumpHome(WidgetTester tester) async {
    repo = FakeMedreseRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith((ref) => Stream.value(testSession)),
          medreseRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(home: HomePage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('medrese yokken boş durum gösterilir', (tester) async {
    await pumpHome(tester);
    expect(find.textContaining('Henüz bir medresen yok'), findsOneWidget);
  });

  testWidgets('koda katılınca liste yenilenir', (tester) async {
    await pumpHome(tester);
    await tester.tap(find.text('Koda katıl'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'KISA');
    await tester.tap(find.text('Katıl'));
    await tester.pumpAndSettle();
    expect(find.text('Kod 8 karakter olmalı.'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'XXXXXXXX');
    await tester.tap(find.text('Katıl'));
    await tester.pumpAndSettle();
    expect(find.text('Bu kodla bir medrese bulunamadı.'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'AB12CD34');
    await tester.tap(find.text('Katıl'));
    await tester.pumpAndSettle();
    expect(find.text('Medreselerim'), findsOneWidget);
    expect(find.text('Süleymaniye'), findsOneWidget);
  });

  testWidgets('medrese kurulunca davet kodu sayfası açılır', (tester) async {
    await pumpHome(tester);
    await tester.tap(find.text('Medrese kur'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Kur'));
    await tester.pumpAndSettle();
    expect(find.text('Medreseye bir ad ver.'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, 'Süleymaniye');
    await tester.tap(find.text('Kur'));
    await tester.pumpAndSettle();
    expect(find.text('Davet kodu'), findsOneWidget);
    expect(find.text('AB12CD34'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Süleymaniye'), findsOneWidget);
    expect(find.text('Kurucu'), findsOneWidget);
  });
}
