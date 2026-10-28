import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/medrese_repository.dart';
import 'package:e_medrese/presentation/features/medrese/create_medrese_page.dart';
import 'package:e_medrese/presentation/features/medrese/join_medrese_page.dart';
import 'package:e_medrese/presentation/widgets/profile_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ana ekran: kullanıcının medreseleri.
class HomePage extends ConsumerWidget {
  /// Ana ekran.
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final medreses = ref.watch(myMedresesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Medreselerim'),
        actions: const [ProfileButton()],
      ),
      body: switch (medreses) {
        AsyncData(value: Ok(value: final list)) when list.isNotEmpty =>
          RefreshIndicator(
            onRefresh: () => ref.refresh(myMedresesProvider.future),
            child: ListView.separated(
              itemCount: list.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) => ListTile(
                leading: CircleAvatar(
                  child: Text(list[i].name.characters.first.toUpperCase()),
                ),
                title: Text(list[i].name),
                subtitle: Text(list[i].myRole.label),
              ),
            ),
          ),
        AsyncData(value: Ok()) => const _EmptyState(),
        AsyncData(value: Err(:final error)) => _ErrorState(
          message: error.message,
          onRetry: () => ref.invalidate(myMedresesProvider),
        ),
        AsyncError(:final error) => _ErrorState(
          message: error.toString(),
          onRetry: () => ref.invalidate(myMedresesProvider),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.vpn_key_outlined),
                  label: const Text('Koda katıl'),
                  onPressed: () => _open(context, const JoinMedresePage()),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Medrese kur'),
                  onPressed: () => _open(context, const CreateMedresePage()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> _open(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.mosque_outlined, size: 64, color: theme.hintColor),
            const SizedBox(height: 16),
            Text('Henüz bir medresen yok', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text(
              'Hocandan aldığın kodla katıl ya da kendi medreseni kur.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onRetry,
              child: const Text('Tekrar dene'),
            ),
          ],
        ),
      ),
    );
  }
}
