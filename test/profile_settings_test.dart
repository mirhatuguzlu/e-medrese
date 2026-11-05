import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/auth_repository.dart';
import 'package:e_medrese/data/repositories/medrese_repository.dart';
import 'package:e_medrese/data/repositories/settings_repository.dart';
import 'package:e_medrese/presentation/features/profile/profile_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fakes.dart';
import 'widget_test.dart' show FakeAuthRepository;

final _session = Session(
  accessToken: 't',
  tokenType: 'bearer',
  user: const User(
    id: 'u1',
    appMetadata: {},
    userMetadata: {'full_name': 'Google Adı'},
    aud: 'authenticated',
    email: 'ali@example.com',
    createdAt: '2026-10-28',
  ),
);

void main() {
  late FakeAuthRepository auth;
  late FakeProfileRepository profile;

  setUp(() {
    auth = FakeAuthRepository();
    profile = FakeProfileRepository(photoPath: 'u1/1.jpg');
  });

  Future<ProviderContainer> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...pushOverrides(profile: profile),
          await prefsOverride(),
          authRepositoryProvider.overrideWithValue(auth),
          sessionProvider.overrideWith((ref) => Stream.value(_session)),
          myMedresesProvider.overrideWith((ref) => const Ok([testMedrese])),
        ],
        child: const MaterialApp(home: ProfilePage()),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(ProfilePage)));
  }

  testWidgets('profilde sunucudaki ad, e-posta ve medreseler görünür', (
    tester,
  ) async {
    await pump(tester);
    // Google'daki ad değil, profilde değiştirilen ad.
    expect(find.text('Ali Veli'), findsWidgets);
    expect(find.text('Google Adı'), findsNothing);
    expect(find.text('ali@example.com · Google ile giriş'), findsOneWidget);
    expect(find.text('Süleymaniye (Kurucu)'), findsOneWidget);
    expect(find.text('28.10.2026'), findsOneWidget);
    // Hukuki sayfalar Ayarlar'a taşındı.
    expect(find.text('Aydınlatma metni'), findsNothing);
  });

  testWidgets('ad değiştirilir', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Ad soyad'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '  ');
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();
    expect(find.text('Adını yaz.'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), ' Ahmet Yılmaz ');
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();
    expect(profile.calls, ['name Ahmet Yılmaz']);
    expect(find.text('Ahmet Yılmaz'), findsWidgets);
  });

  testWidgets('ayarlarda tema seçilir ve kaydedilir', (tester) async {
    final container = await pump(tester);
    await tester.tap(find.byTooltip('Ayarlar'));
    await tester.pumpAndSettle();
    expect(find.text('Aydınlatma metni'), findsOneWidget);

    await tester.tap(find.text('Tema'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Koyu'));
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).themeMode, ThemeMode.dark);
    expect(
      container.read(sharedPreferencesProvider).getString('theme_mode'),
      'dark',
    );
  });

  testWidgets('hesap silinirken önce fotoğraf silinir', (tester) async {
    await pump(tester);
    await tester.tap(find.byTooltip('Ayarlar'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Hesabı sil'), 200);
    await tester.tap(find.text('Hesabı sil'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hesabımı kalıcı olarak sil'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sil'));
    await tester.pumpAndSettle();
    expect(profile.calls, ['removePhoto']);
    expect(auth.calls, ['deleteAccount']);
  });
}
