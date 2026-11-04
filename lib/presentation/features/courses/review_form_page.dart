import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/course_repository.dart';
import 'package:e_medrese/domain/entities/course.dart';
import 'package:e_medrese/presentation/widgets/loading_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Kursa 1–5 yıldız ve isteğe bağlı yorumla isimsiz değerlendirme yazma.
class ReviewFormPage extends ConsumerStatefulWidget {
  /// [courseId] kursunu değerlendirir; [review] verilirse düzenler.
  const ReviewFormPage({required this.courseId, this.review, super.key});

  /// Kurs.
  final String courseId;

  /// Kullanıcının önceki değerlendirmesi.
  final CourseReview? review;

  @override
  ConsumerState<ReviewFormPage> createState() => _ReviewFormPageState();
}

class _ReviewFormPageState extends ConsumerState<ReviewFormPage> {
  late int _rating = widget.review?.rating ?? 0;
  late final _body = TextEditingController(text: widget.review?.body);
  bool _loading = false;

  static const _labels = [
    '',
    'Zayıf',
    'Fena değil',
    'İyi',
    'Çok iyi',
    'Mükemmel',
  ];

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      context.showMessage('Yıldızlardan birini seç.');
      return;
    }
    setState(() => _loading = true);
    final result = await ref
        .read(courseRepositoryProvider)
        .saveReview(
          courseId: widget.courseId,
          rating: _rating,
          body: _body.text,
        );
    if (!mounted) return;
    setState(() => _loading = false);
    switch (result) {
      case Ok():
        ref
          ..invalidate(courseReviewsProvider(widget.courseId))
          ..invalidate(courseRatingsProvider);
        Navigator.of(context).pop();
        context.showMessage('Değerlendirmen kaydedildi. Teşekkürler!');
      case Err(:final error):
        context.showMessage(error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Kursu değerlendir')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  tooltip: '$i yıldız',
                  iconSize: 44,
                  onPressed: () => setState(() => _rating = i),
                  icon: Icon(
                    i <= _rating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: const Color(0xFFF5A623),
                  ),
                ),
            ],
          ),
          Text(
            _labels[_rating],
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _body,
            decoration: const InputDecoration(
              labelText: 'Yorumun (isteğe bağlı)',
              hintText: 'Kurs sana ne kattı? Kimlere önerirsin?',
              helperText:
                  'Adın gösterilmez. Kişisel bilgi ve başkalarının adını '
                  'yazma.',
              helperMaxLines: 2,
              alignLabelWithHint: true,
            ),
            textCapitalization: TextCapitalization.sentences,
            maxLength: 2000,
            minLines: 3,
            maxLines: 8,
          ),
          const SizedBox(height: 24),
          LoadingButton(label: 'Kaydet', loading: _loading, onPressed: _submit),
        ],
      ),
    );
  }
}
