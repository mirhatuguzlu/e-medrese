import 'package:e_medrese/data/repositories/auth_repository.dart';
import 'package:e_medrese/data/repositories/feed_repository.dart';
import 'package:e_medrese/data/repositories/medrese_repository.dart';
import 'package:e_medrese/domain/entities/medrese.dart';
import 'package:e_medrese/domain/entities/member.dart';
import 'package:e_medrese/presentation/features/medrese/medrese_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

Medrese _as(MemberRole role) => Medrese(
  id: 'm1',
  name: 'Süleymaniye',
  description: 'Hafızlık',
  inviteCode: 'AB12CD34',
  myRole: role,
);

const _members = [
  Member(userId: 'u1', name: 'Kurucu Hoca', role: MemberRole.owner),
  Member(userId: 'u2', name: 'Diğer Hoca', role: MemberRole.teacher),
  Member(userId: 'u3', name: 'Öğrenci Ali', role: MemberRole.student),
];

void main() {
  late FakeMedreseRepository medreses;
  late FakeFeedRepository feed;

  // testSession kullanıcısı u1.
  Future<void> pumpMedrese(WidgetTester tester, MemberRole role) async {
    medreses = FakeMedreseRepository()..memberList.addAll(_members);
    feed = FakeFeedRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith((ref) => Stream.value(testSession)),
          medreseRepositoryProvider.overrideWithValue(medreses),
          feedRepositoryProvider.overrideWithValue(feed),
        ],
        child: MaterialApp(home: MedresePage(medrese: _as(role))),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester, String title) async {
    await tester.tap(find.text(title));
    await tester.pumpAndSettle();
  }

  testWidgets('davet kodu girişi yalnızca hocalara görünür', (tester) async {
    await pumpMedrese(tester, MemberRole.student);
    expect(find.text('Davet kodu'), findsNothing);

    await pumpMedrese(tester, MemberRole.teacher);
    expect(find.text('Davet kodu'), findsOneWidget);
  });

  testWidgets('kurucu hocayı ve öğrenciyi çıkarabilir, kendini değil', (
    tester,
  ) async {
    await pumpMedrese(tester, MemberRole.owner);
    await open(tester, 'Üyeler');

    expect(find.text('Kurucu Hoca (sen)'), findsOneWidget);
    expect(find.byTooltip('Çıkar'), findsNWidgets(2));

    await tester.tap(find.byTooltip('Çıkar').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Çıkar'));
    await tester.pumpAndSettle();

    expect(medreses.calls, ['remove u3']);
    expect(find.text('Öğrenci Ali'), findsNothing);
  });

  testWidgets('hoca yalnızca öğrenciyi çıkarabilir', (tester) async {
    await pumpMedrese(tester, MemberRole.teacher);
    await open(tester, 'Üyeler');
    expect(find.byTooltip('Çıkar'), findsOneWidget);
  });

  testWidgets('öğrenci üye ekleyemez ve çıkaramaz', (tester) async {
    await pumpMedrese(tester, MemberRole.student);
    await open(tester, 'Üyeler');
    expect(find.byTooltip('Çıkar'), findsNothing);
    expect(find.text('Üye ekle'), findsNothing);
  });

  testWidgets('kurucu e-postayla hoca ekler', (tester) async {
    await pumpMedrese(tester, MemberRole.owner);
    await open(tester, 'Üyeler');
    await open(tester, 'Üye ekle');

    await tester.enterText(find.byType(TextFormField), 'hoca@b.com');
    await tester.tap(find.text('Hoca'));
    await tester.pump();
    await tester.tap(find.text('Ekle'));
    await tester.pumpAndSettle();

    expect(medreses.calls, ['add hoca@b.com teacher']);
    expect(find.text('Hoca eklendi.'), findsOneWidget);
  });

  testWidgets('hoca rol seçemez, yalnızca öğrenci ekler', (tester) async {
    await pumpMedrese(tester, MemberRole.teacher);
    await open(tester, 'Üyeler');
    await open(tester, 'Üye ekle');
    expect(find.byType(SegmentedButton<MemberRole>), findsNothing);
  });

  testWidgets('öğrenci duyuru yazamaz', (tester) async {
    await pumpMedrese(tester, MemberRole.student);
    await open(tester, 'Duyurular');
    expect(find.text('Henüz duyuru yok.'), findsOneWidget);
    expect(find.text('Duyuru yaz'), findsNothing);
  });

  testWidgets('hoca duyuru yazar, akışta görünür', (tester) async {
    await pumpMedrese(tester, MemberRole.teacher);
    await open(tester, 'Duyurular');
    await open(tester, 'Duyuru yaz');

    await tester.tap(find.text('Yayınla'));
    await tester.pumpAndSettle();
    expect(find.text('Bir başlık yaz.'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, 'Ders iptal');
    await tester.tap(find.text('Yayınla'));
    await tester.pumpAndSettle();

    expect(feed.calls, ['announcement Ders iptal']);
    expect(find.text('Ders iptal'), findsOneWidget);
  });

  testWidgets('öğrenci paylaşır ve yorum yapar', (tester) async {
    await pumpMedrese(tester, MemberRole.student);
    await open(tester, 'Paylaşımlar');
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'Selamün aleyküm');
    await tester.tap(find.widgetWithText(FilledButton, 'Paylaş'));
    await tester.pumpAndSettle();
    expect(find.text('Selamün aleyküm'), findsOneWidget);

    await open(tester, 'Selamün aleyküm');
    expect(find.text('Henüz yorum yok.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Aleyküm selam');
    await tester.tap(find.byTooltip('Gönder'));
    await tester.pumpAndSettle();

    expect(feed.calls, ['post Selamün aleyküm', 'comment Aleyküm selam']);
    expect(find.text('Aleyküm selam'), findsOneWidget);
  });
}
