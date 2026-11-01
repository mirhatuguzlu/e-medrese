import 'package:e_medrese/data/repositories/auth_repository.dart';
import 'package:e_medrese/data/repositories/medrese_repository.dart';
import 'package:e_medrese/domain/entities/app_notification.dart';
import 'package:e_medrese/presentation/features/home/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  testWidgets('zil okunmamış sayısını gösterir, sayfa hepsini okundu yapar', (
    tester,
  ) async {
    final notifications = FakeNotificationRepository()
      ..list.addAll([
        AppNotification(
          id: 'n1',
          title: 'Görevler başladı',
          body: 'Haftalık görevlerin başladı.',
          createdAt: DateTime(2026, 11),
          read: false,
        ),
        AppNotification(
          id: 'n2',
          title: 'Yeni duyuru: Ders yok',
          body: '',
          createdAt: DateTime(2026, 10, 30),
          read: true,
        ),
      ]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...pushOverrides(notifications: notifications),
          sessionProvider.overrideWith((ref) => Stream.value(testSession)),
          medreseRepositoryProvider.overrideWithValue(FakeMedreseRepository()),
        ],
        child: const MaterialApp(home: HomePage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('1'), findsOneWidget);

    await tester.tap(find.byTooltip('Bildirimler'));
    await tester.pumpAndSettle();
    expect(find.text('Görevler başladı'), findsOneWidget);
    expect(find.text('Yeni duyuru: Ders yok'), findsOneWidget);
    expect(notifications.calls, ['markAllRead']);
  });
}
