import 'package:flutter/material.dart';

/// İşlem sürerken devre dışı kalıp dönen gösterge çizen ana buton.
class LoadingButton extends StatelessWidget {
  /// Buton.
  const LoadingButton({
    required this.label,
    required this.loading,
    required this.onPressed,
    super.key,
  });

  /// Yazı.
  final String label;

  /// İşlem sürüyor mu.
  final bool loading;

  /// Basılınca.
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: loading ? null : onPressed,
      child: loading
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(label),
    );
  }
}
