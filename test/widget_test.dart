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
  Result<bool, AppFailure> googleResult = const Ok(true);
  final calls = <String>[];

  @override
  Stream<Session?> get sessionChanges => sessions.stream;

  @override
  Future<Result<bool, AppFailure>> signInWithGoogle() async {
    calls.add('signInWithGoogle');
    return googleResult;
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


  testWidgets('Google ile giriş düğmesi Google girişini başlatır', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.byType(TextFormField), findsNothing);

    await tester.tap(find.text('Google ile devam et'));
    await tester.pumpAndSettle();
    expect(auth.calls, ['signInWithGoogle']);
  });

  testWidgets('Google girişi hata verirse mesaj gösterilir', (tester) async {
    auth.googleResult = const Err(ConnectionFailure());
    await pumpApp(tester);

    await tester.tap(find.text('Google ile devam et'));
    await tester.pumpAndSettle();
    expect(find.text('İnternet bağlantısı yok.'), findsOneWidget);
  });
}
