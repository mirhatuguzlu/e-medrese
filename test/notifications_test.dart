import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/auth_repository.dart';
import 'package:e_medrese/data/repositories/feed_repository.dart';
import 'package:e_medrese/data/repositories/medrese_repository.dart';
import 'package:e_medrese/domain/entities/app_notification.dart';
import 'package:e_medrese/domain/entities/feed.dart';
import 'package:e_medrese/presentation/features/home/home_page.dart';
import 'package:e_medrese/presentation/features/notifications/notifications_page.dart';
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
          kind: 'task_started',
          title: 'Görevler başladı',
          body: 'Haftalık görevlerin başladı.',
          createdAt: DateTime(2026, 11),
          read: false,
        ),
        AppNotification(
          id: 'n2',
          kind: 'announcement',
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

    // Görev bildirimi ana ekrandaki görevlere döndürür.
    await tester.tap(find.text('Görevler başladı'));
    await tester.pumpAndSettle();
    expect(find.text('e-Medrese'), findsOneWidget);
    expect(find.text('Bildirimler'), findsNothing);
  });

  testWidgets('telefondaki duyuru bildirimine dokununca duyurular açılır', (
    tester,
  ) async {
    final push = FakePushService();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...pushOverrides(push: push),
          sessionProvider.overrideWith((ref) => Stream.value(testSession)),
          medreseRepositoryProvider.overrideWithValue(FakeMedreseRepository()),
          myMedresesProvider.overrideWith((ref) => const Ok([testMedrese])),
          feedRepositoryProvider.overrideWithValue(FakeFeedRepository()),
        ],
        child: const MaterialApp(home: HomePage()),
      ),
    );
    await tester.pumpAndSettle();

    push.taps.add(
      AppNotification.fromPush({
        'kind': 'announcement',
        'medrese_id': testMedrese.id,
        'post_id': '',
        'created_at': '2026-11-01T10:00:00Z',
      }),
    );
    await tester.pumpAndSettle();
    expect(find.text('Duyurular'), findsOneWidget);
  });

  testWidgets('yorum bildirimine dokununca paylaşım açılır', (tester) async {
    final notifications = FakeNotificationRepository()
      ..list.add(
        AppNotification(
          id: 'n1',
          kind: 'comment',
          title: 'Paylaşımına yorum geldi',
          body: 'Ali: Güzel',
          createdAt: DateTime(2026, 11),
          read: false,
          medreseId: testMedrese.id,
          postId: 'p1',
        ),
      );
    final feed = FakeFeedRepository()
      ..postList.add(
        Post(
          id: 'p1',
          body: 'Selam herkese',
          authorId: 'u1',
          authorName: 'Ben',
          createdAt: DateTime(2026),
          edited: false,
          commentCount: 1,
        ),
      );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...pushOverrides(notifications: notifications),
          sessionProvider.overrideWith((ref) => Stream.value(testSession)),
          myMedresesProvider.overrideWith((ref) => const Ok([testMedrese])),
          feedRepositoryProvider.overrideWithValue(feed),
        ],
        child: const MaterialApp(home: NotificationsPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Paylaşımına yorum geldi'));
    await tester.pumpAndSettle();
    expect(find.text('Selam herkese'), findsOneWidget);
  });
}
