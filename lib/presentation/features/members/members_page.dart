import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/auth_repository.dart';
import 'package:e_medrese/data/repositories/medrese_repository.dart';
import 'package:e_medrese/domain/entities/medrese.dart';
import 'package:e_medrese/domain/entities/member.dart';
import 'package:e_medrese/presentation/features/members/add_member_page.dart';
import 'package:e_medrese/presentation/features/members/member_page.dart';
import 'package:e_medrese/presentation/widgets/confirm_dialog.dart';
import 'package:e_medrese/presentation/widgets/result_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Medrese üyeleri. Hocalar öğrenci çıkarabilir, kurucu hoca da çıkarabilir.
class MembersPage extends ConsumerWidget {
  /// [medrese]'nin üyeleri.
  const MembersPage({required this.medrese, super.key});

  /// Medrese.
  final Medrese medrese;

  /// Veritabanındaki silme kuralıyla aynı.
  bool _canRemove(Member m, String? myId) =>
      m.userId != myId &&
      switch (medrese.myRole) {
        MemberRole.owner => m.role != MemberRole.owner,
        MemberRole.teacher => m.role == MemberRole.student,
        MemberRole.student => false,
      };

  Future<void> _remove(BuildContext context, WidgetRef ref, Member m) async {
    final confirmed = await confirm(
      context,
      title: 'Üyeyi çıkar',
      message:
          '${displayName(m.name)} medreseden çıkarılsın mı? '
          'Medresenin sohbetlerinden de çıkarılır.',
      action: 'Çıkar',
    );
    if (!confirmed) return;

    final result = await ref
        .read(medreseRepositoryProvider)
        .removeMember(medreseId: medrese.id, userId: m.userId);
    if (!context.mounted) return;
    switch (result) {
      case Ok():
        ref.invalidate(membersProvider(medrese.id));
        context.showMessage('${displayName(m.name)} çıkarıldı.');
      case Err(:final error):
        context.showMessage(error.message);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myId = ref.watch(sessionProvider).valueOrNull?.user.id;
    final members = ref.watch(membersProvider(medrese.id));

    return Scaffold(
      appBar: AppBar(title: const Text('Üyeler')),
      body: ResultListView<Member>(
        value: members,
        onRefresh: () => ref.refresh(membersProvider(medrese.id).future),
        emptyIcon: Icons.groups_outlined,
        emptyText: 'Henüz üye yok.',
        itemBuilder: (context, m) => ListTile(
          leading: CircleAvatar(
            child: Text(displayName(m.name).characters.first.toUpperCase()),
          ),
          title: Text(
            m.userId == myId
                ? '${displayName(m.name)} (sen)'
                : displayName(m.name),
          ),
          subtitle: Text(m.role.label),
          // Üye sayfasını kurucu ve hocalar açar.
          onTap: medrese.myRole.isStaff && m.userId != myId
              ? () => context.push(MemberPage(medrese: medrese, member: m))
              : null,
          trailing: _canRemove(m, myId)
              ? IconButton(
                  tooltip: 'Çıkar',
                  icon: const Icon(Icons.person_remove_outlined),
                  onPressed: () => _remove(context, ref, m),
                )
              : null,
        ),
      ),
      floatingActionButton: medrese.myRole.isStaff
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.person_add_alt),
              label: const Text('Üye ekle'),
              onPressed: () => context.push(AddMemberPage(medrese: medrese)),
            )
          : null,
    );
  }
}
