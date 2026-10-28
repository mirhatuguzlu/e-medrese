import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/feed_repository.dart';
import 'package:e_medrese/data/repositories/medrese_repository.dart';
import 'package:e_medrese/domain/entities/medrese.dart';
import 'package:e_medrese/domain/entities/member.dart';
import 'package:e_medrese/presentation/widgets/confirm_dialog.dart';
import 'package:e_medrese/presentation/widgets/loading_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bir üyenin bilgileri; kurucu buradan öğrenciyi hocalığa yükseltir.
class MemberPage extends ConsumerStatefulWidget {
  /// [member] sayfası.
  const MemberPage({required this.medrese, required this.member, super.key});

  /// Medrese.
  final Medrese medrese;

  /// Üye.
  final Member member;

  @override
  ConsumerState<MemberPage> createState() => _MemberPageState();
}

class _MemberPageState extends ConsumerState<MemberPage> {
  bool _loading = false;

  Future<void> _promote() async {
    final name = displayName(widget.member.name);
    final confirmed = await confirm(
      context,
      title: 'Hocalığa yükselt',
      message:
          '$name hoca olsun mu? Duyuru yazabilir ve öğrenci ekleyip '
          'çıkarabilir.',
      action: 'Yükselt',
    );
    if (!confirmed || !mounted) return;

    setState(() => _loading = true);
    final result = await ref
        .read(medreseRepositoryProvider)
        .promoteToTeacher(
          medreseId: widget.medrese.id,
          userId: widget.member.userId,
        );
    if (!mounted) return;
    setState(() => _loading = false);

    switch (result) {
      case Ok():
        ref.invalidate(membersProvider(widget.medrese.id));
        Navigator.of(context).pop();
        context.showMessage('$name artık hoca.');
      case Err(:final error):
        context.showMessage(error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final m = widget.member;
    final postCount = ref.watch(
      postCountProvider((medreseId: widget.medrese.id, userId: m.userId)),
    );
    final canPromote =
        widget.medrese.myRole == MemberRole.owner &&
        m.role == MemberRole.student;

    return Scaffold(
      appBar: AppBar(title: const Text('Üye')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 32),
        children: [
          Center(
            child: CircleAvatar(
              radius: 48,
              child: Text(
                displayName(m.name).characters.first.toUpperCase(),
                style: const TextStyle(fontSize: 40),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            displayName(m.name),
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge,
          ),
          Text(
            m.role.label,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.event_outlined),
            title: const Text('Katılma tarihi'),
            trailing: Text(formatDateTime(m.joinedAt)),
          ),
          ListTile(
            leading: const Icon(Icons.forum_outlined),
            title: const Text('Paylaşım sayısı'),
            trailing: Text(switch (postCount) {
              AsyncData(value: Ok(:final value)) => '$value',
              AsyncData(value: Err()) || AsyncError() => '-',
              _ => '…',
            }),
          ),
          if (canPromote)
            Padding(
              padding: const EdgeInsets.all(24),
              child: LoadingButton(
                label: 'Hocalığa yükselt',
                loading: _loading,
                onPressed: _promote,
              ),
            ),
        ],
      ),
    );
  }
}
