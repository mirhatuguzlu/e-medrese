import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/medrese_repository.dart';
import 'package:e_medrese/data/repositories/task_repository.dart';
import 'package:e_medrese/domain/entities/medrese.dart';
import 'package:e_medrese/presentation/features/medrese/create_medrese_page.dart';
import 'package:e_medrese/presentation/features/medrese/join_medrese_page.dart';
import 'package:e_medrese/presentation/features/medrese/medrese_page.dart';
import 'package:e_medrese/presentation/features/tasks/student_tasks_section.dart';
import 'package:e_medrese/presentation/widgets/profile_button.dart';
import 'package:e_medrese/presentation/widgets/result_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ana ekran: öğrencisi olunan medreselerin görevleri, altında medreseler.
class HomePage extends ConsumerWidget {
  /// Ana ekran.
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('e-Medrese'),
        actions: const [ProfileButton()],
      ),
      body: ResultListView<Medrese>(
        value: ref.watch(myMedresesProvider),
        onRefresh: () {
          ref
            ..invalidate(taskProgramProvider)
            ..invalidate(periodEntriesProvider);
          return ref.refresh(myMedresesProvider.future);
        },
        header: (medreses) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final m in medreses)
              if (m.myRole == MemberRole.student)
                StudentTasksSection(medrese: m),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Medreselerim',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
        emptyIcon: Icons.mosque_outlined,
        emptyText:
            'Henüz bir medresen yok.\n'
            'Hocandan aldığın kodla katıl ya da kendi medreseni kur.',
        itemBuilder: (context, m) => ListTile(
          leading: CircleAvatar(
            child: Text(m.name.characters.first.toUpperCase()),
          ),
          title: Text(m.name),
          subtitle: Text(m.myRole.label),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push(MedresePage(medrese: m)),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.vpn_key_outlined),
                  label: const Text('Koda katıl'),
                  onPressed: () => context.push(const JoinMedresePage()),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Medrese kur'),
                  onPressed: () => context.push(const CreateMedresePage()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
