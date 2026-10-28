import 'package:e_medrese/data/repositories/auth_repository.dart';
import 'package:e_medrese/data/repositories/feed_repository.dart';
import 'package:e_medrese/data/repositories/medrese_repository.dart';
import 'package:e_medrese/domain/entities/feed.dart';
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

final _joined = DateTime(2026, 10, 28);

final _members = [
  Member(
    userId: 'u1',
    name: 'Kurucu Hoca',
    role: MemberRole.owner,
    joinedAt: _joined,
  ),
  Member(
    userId: 'u2',
    name: 'Diğer Hoca',
    role: MemberRole.teacher,
    joinedAt: _joined,
  ),
  Member(
    userId: 'u3',
    name: 'Öğrenci Ali',
    role: MemberRole.student,
    joinedAt: _joined,
  ),
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
        key: UniqueKey(),
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

  Post post(String id, String authorId, String name) => Post(
    id: id,
    body: '$name paylaşımı',
    authorId: authorId,
    authorName: name,
    createdAt: DateTime(2026),
    edited: false,
    commentCount: 0,
  );

  Announcement announcement(String id, String authorId, String title) =>
      Announcement(
        id: id,
        title: title,
        body: '',
        authorId: authorId,
        authorName: 'Diğer Hoca',
        createdAt: DateTime(2026),
        edited: false,
      );

  testWidgets('kurucu öğrencinin sayfasından hocalığa yükseltir', (
    tester,
  ) async {
    await pumpMedrese(tester, MemberRole.owner);
    feed.postList.add(post('p1', 'u3', 'Öğrenci Ali'));
    await open(tester, 'Üyeler');
    await open(tester, 'Öğrenci Ali');

    expect(find.text('Katılma tarihi'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);

    await tester.tap(find.text('Hocalığa yükselt'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Yükselt'));
    await tester.pumpAndSettle();

    expect(medreses.calls, ['role u3 teacher']);
    expect(find.text('Öğrenci Ali artık hoca.'), findsOneWidget);
    expect(find.text('Öğrenci'), findsNothing);
  });

  testWidgets('kurucu hocayı öğrenciliğe düşürür', (tester) async {
    await pumpMedrese(tester, MemberRole.owner);
    await open(tester, 'Üyeler');
    await open(tester, 'Diğer Hoca');
    expect(find.text('Hocalığa yükselt'), findsNothing);

    await tester.tap(find.text('Öğrenciliğe düşür'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Düşür'));
    await tester.pumpAndSettle();

    expect(medreses.calls, ['role u2 student']);
    expect(find.text('Diğer Hoca artık öğrenci.'), findsOneWidget);
  });

  testWidgets('hoca üye sayfasını görür ama rol değiştiremez', (tester) async {
    await pumpMedrese(tester, MemberRole.teacher);
    await open(tester, 'Üyeler');
    await open(tester, 'Öğrenci Ali');
    expect(find.text('Katılma tarihi'), findsOneWidget);
    expect(find.text('Hocalığa yükselt'), findsNothing);
  });

  testWidgets('öğrenci üye sayfası açamaz', (tester) async {
    await pumpMedrese(tester, MemberRole.student);
    await open(tester, 'Üyeler');
    await open(tester, 'Diğer Hoca');
    expect(find.text('Katılma tarihi'), findsNothing);
  });

  // testSession kullanıcısı u1 olduğu için başka hoca (u2) ile denenir;
  // kurucu durumu veritabanı testinde.
  testWidgets('hoca başka hocanın paylaşımını silemez', (tester) async {
    await pumpMedrese(tester, MemberRole.teacher);
    feed.postList.add(post('p1', 'u2', 'Diğer Hoca'));
    await open(tester, 'Paylaşımlar');
    await open(tester, 'Diğer Hoca paylaşımı');
    expect(find.byTooltip('Sil'), findsNothing);
  });

  testWidgets('ayrılan üyenin adı etiketle gösterilir', (tester) async {
    await pumpMedrese(tester, MemberRole.student);
    feed.postList.addAll([
      post('p1', 'u3', 'Öğrenci Ali'),
      post('p2', 'u9', 'Eski Öğrenci'),
    ]);
    await open(tester, 'Paylaşımlar');

    expect(find.text('Öğrenci Ali'), findsOneWidget);
    expect(
      find.text('Eski Öğrenci (artık bu medresede değil)'),
      findsOneWidget,
    );
  });

  testWidgets('kurucu başkasının duyurusunu siler ama düzenleyemez', (
    tester,
  ) async {
    await pumpMedrese(tester, MemberRole.owner);
    feed.announcementList.add(announcement('a1', 'u2', 'Sınav'));
    await open(tester, 'Duyurular');

    expect(find.byTooltip('Düzenle'), findsNothing);
    await tester.tap(find.byTooltip('Sil'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Sil'));
    await tester.pumpAndSettle();

    expect(feed.calls, ['delete announcement a1']);
    expect(find.text('Sınav'), findsNothing);
  });

  testWidgets('yazan duyurusunu düzenler, başka hoca silemez', (tester) async {
    await pumpMedrese(tester, MemberRole.teacher);
    feed.announcementList.addAll([
      announcement('a1', 'u1', 'Ders iptal'),
      announcement('a2', 'u2', 'Başkasının'),
    ]);
    await open(tester, 'Duyurular');

    // Yalnızca kendi duyurusunda düzenle/sil var.
    expect(find.byTooltip('Düzenle'), findsOneWidget);
    expect(find.byTooltip('Sil'), findsOneWidget);

    await tester.tap(find.byTooltip('Düzenle'));
    await tester.pumpAndSettle();
    expect(find.text('Duyuruyu düzenle'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'Ders ertelendi');
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    expect(feed.calls, ['edit announcement Ders ertelendi']);
    expect(find.text('Ders ertelendi'), findsOneWidget);
    expect(find.textContaining('düzenlendi'), findsOneWidget);
  });

  testWidgets('yazan paylaşımını düzenler', (tester) async {
    await pumpMedrese(tester, MemberRole.student);
    feed.postList.add(post('p1', 'u1', 'Kurucu Hoca'));
    await open(tester, 'Paylaşımlar');
    await open(tester, 'Kurucu Hoca paylaşımı');

    await tester.tap(find.byTooltip('Düzenle'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Düzeltildi');
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    expect(feed.calls, ['edit post Düzeltildi']);
    expect(find.text('Düzeltildi'), findsOneWidget);
    expect(find.textContaining('düzenlendi'), findsOneWidget);
  });

  testWidgets('öğrenci başkasının paylaşımını silemez, hoca siler', (
    tester,
  ) async {
    await pumpMedrese(tester, MemberRole.student);
    feed.postList.add(post('p1', 'u3', 'Öğrenci Ali'));
    await open(tester, 'Paylaşımlar');
    await open(tester, 'Öğrenci Ali paylaşımı');
    expect(find.byTooltip('Sil'), findsNothing);
    expect(find.byTooltip('Düzenle'), findsNothing);

    await pumpMedrese(tester, MemberRole.teacher);
    feed.postList.add(post('p1', 'u3', 'Öğrenci Ali'));
    await open(tester, 'Paylaşımlar');
    await open(tester, 'Öğrenci Ali paylaşımı');
    await tester.tap(find.byTooltip('Sil'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Sil'));
    await tester.pumpAndSettle();

    expect(feed.calls, ['delete post p1']);
    expect(find.text('Paylaşım silindi.'), findsOneWidget);
    expect(find.text('Öğrenci Ali paylaşımı'), findsNothing);
  });
}
