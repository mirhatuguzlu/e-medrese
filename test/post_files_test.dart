import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/auth_repository.dart';
import 'package:e_medrese/data/repositories/feed_repository.dart';
import 'package:e_medrese/data/repositories/medrese_repository.dart';
import 'package:e_medrese/domain/entities/feed.dart';
import 'package:e_medrese/presentation/features/posts/new_post_page.dart';
import 'package:e_medrese/presentation/features/posts/post_file_page.dart';
import 'package:e_medrese/presentation/features/posts/posts_page.dart';
import 'package:e_medrese/services/download_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

class _FakeDownloads implements DownloadService {
  final names = <String>[];

  @override
  Future<String> download(
    String url, {
    required String name,
    Map<String, String> headers = const {},
  }) async {
    names.add(name);
    return '/Download/e-Medrese/$name';
  }
}

const _pdf = PostFile(
  id: 'f1',
  position: 1,
  kind: PostFileKind.pdf,
  name: 'ders.pdf',
  path: 'm1/x.pdf',
  size: 3 * 1024 * 1024,
);

void main() {
  test('dosya türü, içerik türü, boyut ve aynı ad', () {
    expect(PostFileKind.of('Not.PDF'), PostFileKind.pdf);
    expect(PostFileKind.of('a.jpeg'), PostFileKind.image);
    expect(PostFileKind.of('a.mp4'), isNull);
    expect(PostFileKind.of('a.mp3'), isNull);
    expect(PostFileKind.of('a.exe'), isNull);
    expect(PostFileKind.mimeOf('a.JPG'), 'image/jpeg');
    expect(PostFileKind.mimeOf('a.png'), 'image/png');
    expect(PostFileKind.mimeOf('a.pdf'), 'application/pdf');
    expect(formatBytes(800 * 1024), '800 KB');
    expect(formatBytes(12 * 1024 * 1024 + 400 * 1024), '12,4 MB');
    final taken = {'a.pdf', 'a (1).pdf'};
    expect(uniquePath('b.pdf', taken.contains), 'b.pdf');
    expect(uniquePath('a.pdf', taken.contains), 'a (2).pdf');
  });

  Widget app(
    Widget home, {
    FakeFeedRepository? feed,
    FakePushService? push,
    List<Override>? extra,
  }) => ProviderScope(
    overrides: [
      sessionProvider.overrideWith((ref) => Stream.value(testSession)),
      medreseRepositoryProvider.overrideWithValue(FakeMedreseRepository()),
      feedRepositoryProvider.overrideWithValue(feed ?? FakeFeedRepository()),
      ...pushOverrides(push: push),
      ...?extra,
    ],
    child: MaterialApp(home: home),
  );

  testWidgets('yazısız ve dosyasız paylaşım yapılmaz', (tester) async {
    final feed = FakeFeedRepository();
    await tester.pumpWidget(
      app(const NewPostPage(medrese: testMedrese), feed: feed),
    );
    await tester.pumpAndSettle();
    expect(find.text('Dosya ekle'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Paylaş'));
    await tester.pumpAndSettle();
    expect(find.text('Bir şeyler yaz ya da dosya ekle.'), findsOneWidget);
    expect(feed.calls, isEmpty);
  });

  testWidgets('akışta dosya görünür', (tester) async {
    final feed = FakeFeedRepository()
      ..postList.add(
        Post(
          id: 'p1',
          body: '',
          authorId: 'u2',
          authorName: 'Hoca',
          createdAt: DateTime(2026),
          edited: false,
          commentCount: 0,
          files: const [_pdf],
        ),
      );
    await tester.pumpWidget(
      app(const PostsPage(medrese: testMedrese), feed: feed),
    );
    await tester.pumpAndSettle();
    expect(find.text('ders.pdf'), findsOneWidget);
    expect(find.text('3,0 MB'), findsOneWidget);
  });

  testWidgets('indirince kaydedilir ve telefonda bildirim çıkar', (
    tester,
  ) async {
    final feed = FakeFeedRepository();
    final downloads = _FakeDownloads();
    final push = FakePushService();
    await tester.pumpWidget(
      app(
        const PostFilePage(file: _pdf),
        feed: feed,
        extra: [downloadServiceProvider.overrideWithValue(downloads)],
        push: push,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('İndir'));
    await tester.pumpAndSettle();
    expect(downloads.names, ['ders.pdf']);
    expect(feed.calls, ['download f1']);
    expect(push.calls, ['local İndirildi']);
  });
}
