import 'dart:async';

import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/auth_repository.dart';
import 'package:e_medrese/data/repositories/medrese_repository.dart';
import 'package:e_medrese/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FakeAuthRepository implements AuthRepository {
  final sessions = StreamController<Session?>.broadcast();
  Result<void, AppFailure> signInResult = const Ok(null);
  Result<bool, AppFailure> signUpResult = const Ok(true);
  final calls = <String>[];

  @override
  Stream<Session?> get sessionChanges => sessions.stream;

  @override
  Future<Result<void, AppFailure>> signIn({
    required String email,
    required String password,
  }) async {
    calls.add('signIn $email');
    return signInResult;
  }

  @override
  Future<Result<bool, AppFailure>> signUp({
    required String fullName,
    required String email,
    required String password,
  }) async {
    calls.add('signUp $fullName $email');
    return signUpResult;
  }

  @override
  Future<Result<bool, AppFailure>> signInWithGoogle() async {
    calls.add('signInWithGoogle');
    return const Ok(true);
  }

  @override
  Future<Result<void, AppFailure>> signOut() async {
    calls.add('signOut');
    sessions.add(null);
    return const Ok(null);
  }
}

final _session = Session(
  accessToken: 'token',
  tokenType: 'bearer',
  user: const User(
    id: 'u1',
    appMetadata: {},
    userMetadata: {'full_name': 'Ali Veli'},
    email: 'ali@b.com',
    aud: 'authenticated',
    createdAt: '',
  ),
);

void main() {
  late FakeAuthRepository auth;

  setUp(() => auth = FakeAuthRepository());
  tearDown(() => auth.sessions.close());

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          myMedresesProvider.overrideWith((ref) => const Ok([])),
        ],
        child: const App(),
      ),
    );
    auth.sessions.add(null);
    await tester.pumpAndSettle();
  }

  testWidgets('oturum yokken giriş ekranı, oturum açılınca ana ekran', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.text('Hesabına giriş yap'), findsOneWidget);

    auth.sessions.add(_session);
    await tester.pumpAndSettle();
    expect(find.textContaining('Henüz bir medresen yok'), findsOneWidget);

    expect(find.text('A'), findsOneWidget);
    await tester.tap(find.byTooltip('Profil'));
    await tester.pumpAndSettle();
    expect(find.text('Ali Veli'), findsOneWidget);
    expect(find.text('ali@b.com'), findsOneWidget);
    await tester.tap(find.text('Çıkış yap'));
    await tester.pumpAndSettle();
    expect(find.text('Hesabına giriş yap'), findsOneWidget);
    // Profil sayfası yığında kalmamalı.
    expect(find.text('Profil'), findsNothing);
  });

  testWidgets('geçersiz form gönderilmez', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Giriş yap'));
    await tester.pumpAndSettle();

    expect(find.text('Geçerli bir e-posta yaz.'), findsOneWidget);
    expect(find.text('Şifre en az 6 karakter olmalı.'), findsOneWidget);
    expect(auth.calls, isEmpty);
  });

  testWidgets('hatalı girişte hata mesajı gösterilir', (tester) async {
    auth.signInResult = const Err(InvalidCredentialsFailure());
    await pumpApp(tester);

    await tester.enterText(find.byType(TextFormField).at(0), ' a@b.com');
    await tester.enterText(find.byType(TextFormField).at(1), '123456');
    await tester.tap(find.text('Giriş yap'));
    await tester.pumpAndSettle();

    expect(auth.calls, ['signIn  a@b.com']);
    expect(find.text('Geçersiz e-posta veya şifre.'), findsOneWidget);
  });

  testWidgets('kayıtta e-posta onayı bekleniyorsa bilgi verilir', (
    tester,
  ) async {
    auth.signUpResult = const Ok(false);
    await pumpApp(tester);

    await tester.tap(find.text('Hesabın yok mu? Kayıt ol'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Ali Veli');
    await tester.enterText(find.byType(TextFormField).at(1), 'ali@b.com');
    await tester.enterText(find.byType(TextFormField).at(2), '123456');
    await tester.tap(find.text('Kayıt ol'));
    await tester.pumpAndSettle();

    expect(auth.calls, ['signUp Ali Veli ali@b.com']);
    expect(
      find.textContaining('E-postandaki bağlantıyla onayla'),
      findsOneWidget,
    );
  });
}
