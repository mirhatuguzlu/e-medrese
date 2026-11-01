import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/medrese_repository.dart';
import 'package:e_medrese/domain/entities/medrese.dart';
import 'package:e_medrese/presentation/features/medrese/create_medrese_page.dart';
import 'package:e_medrese/presentation/features/medrese/join_medrese_page.dart';
import 'package:e_medrese/presentation/features/medrese/medrese_page.dart';
import 'package:e_medrese/presentation/widgets/result_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Medreselerim sekmesi: medrese listesi. Tek medrese varsa doğrudan o
/// medresenin sayfası açılır.
class HomePage extends ConsumerWidget {
  /// Medreselerim.
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Liste boşken de görünsün diye üst çubukta.
    final actions = [
      IconButton(
        tooltip: 'Koda katıl',
        icon: const Icon(Icons.vpn_key_outlined),
        onPressed: () => context.push(const JoinMedresePage()),
      ),
      IconButton(
        tooltip: 'Medrese kur',
        icon: const Icon(Icons.add),
        onPressed: () => context.push(const CreateMedresePage()),
      ),
    ];
    final value = ref.watch(myMedresesProvider);
    if (value case AsyncData(value: Ok(value: [final m]))) {
      return MedresePage(medrese: m, actions: actions);
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Medreselerim'), actions: actions),
      body: ResultListView<Medrese>(
        value: value,
        onRefresh: () => ref.refresh(myMedresesProvider.future),
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
    );
  }
}
