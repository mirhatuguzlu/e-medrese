import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/domain/entities/course.dart';
import 'package:e_medrese/presentation/widgets/user_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// Kursu bitirenin icazeti: kim, hangi kursu, ne zaman bitirdi.
class CertificatePage extends ConsumerWidget {
  /// Bitmiş [progress] kursunun icazeti.
  const CertificatePage({required this.progress, super.key});

  /// Kurs ve ilerlemesi (bitmiş olmalı).
  final CourseProgress progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final course = progress.course;
    final name = currentUserName(ref);
    final date = progress.lastCompleted;
    final duration = course.durationSeconds;
    return Scaffold(
      appBar: AppBar(title: const Text('İcazet')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: scheme.primary, width: 2),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                children: [
                  Icon(
                    Icons.workspace_premium,
                    size: 64,
                    color: scheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'İCAZET',
                    style: theme.textTheme.titleLarge?.copyWith(
                      letterSpacing: 6,
                      fontWeight: FontWeight.bold,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    displayName(name),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Online Medrese'deki",
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    course.title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'kursunun bütün derslerini tamamladı.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 24,
                    runSpacing: 12,
                    children: [
                      _Info(label: 'Ders', value: '${course.lessons.length}'),
                      if (duration > 0)
                        _Info(label: 'Süre', value: formatLength(duration)),
                      if (date != null)
                        _Info(
                          label: 'Tarih',
                          value: DateFormat('dd.MM.yyyy').format(date),
                        ),
                      if (course.teacher.isNotEmpty)
                        _Info(label: 'Hoca', value: course.teacher),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Bu belge uygulama içinde kursu bitirdiğini gösterir; resmî bir '
            'diploma ya da sertifika değildir.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(label, style: theme.textTheme.labelMedium),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
