import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/feed_repository.dart';
import 'package:e_medrese/domain/entities/feed.dart';
import 'package:e_medrese/presentation/widgets/loading_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bir paylaşımı ya da yorumu şikayet etme sayfası (5651, 5846).
class ReportPage extends ConsumerStatefulWidget {
  /// [postId] ya da [commentId]'den tam biri verilir.
  const ReportPage({this.postId, this.commentId, super.key})
    : assert((postId == null) != (commentId == null), 'tam biri verilmeli');

  /// Şikayet edilen paylaşım.
  final String? postId;

  /// Şikayet edilen yorum.
  final String? commentId;

  @override
  ConsumerState<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends ConsumerState<ReportPage> {
  final _note = TextEditingController();
  ReportReason? _reason;
  bool _loading = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final reason = _reason;
    if (reason == null) {
      context.showMessage('Bir neden seç.');
      return;
    }
    setState(() => _loading = true);
    final result = await ref
        .read(feedRepositoryProvider)
        .report(
          postId: widget.postId,
          commentId: widget.commentId,
          reason: reason,
          note: _note.text,
        );
    if (!mounted) return;
    setState(() => _loading = false);
    switch (result) {
      case Ok():
        Navigator.of(context).pop();
        context.showMessage('Şikayetin alındı, incelenecek.');
      case Err(:final error):
        context.showMessage(error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Şikayet et')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('Bu içerikte sorun ne?'),
          ),
          RadioGroup<ReportReason>(
            groupValue: _reason,
            onChanged: (v) => setState(() => _reason = v),
            child: Column(
              children: [
                for (final r in ReportReason.values)
                  RadioListTile<ReportReason>(value: r, title: Text(r.label)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _note,
              decoration: const InputDecoration(
                labelText: 'Açıklama (isteğe bağlı)',
              ),
              maxLength: 2000,
              minLines: 2,
              maxLines: 5,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: LoadingButton(
              label: 'Gönder',
              loading: _loading,
              onPressed: _send,
            ),
          ),
        ],
      ),
    );
  }
}
