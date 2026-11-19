import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Asks the user for one line of text. Returns the text (trimmed unless
/// [trim] is false, as for a password), or null when cancelled.
///
/// The dialog owns its text field: the controller lives as long as the
/// dialog, closing animation included. Disposing a controller right after
/// `showDialog` returns would leave the closing dialog using a dead one.
Future<String?> showTextEntry(
  BuildContext context, {
  required String title,
  required String label,
  String confirmLabel = 'Valider',
  String initialText = '',
  TextInputType? keyboardType,
  bool obscureText = false,
  bool trim = true,
  int? maxLength,
  String? suffixText,

  /// Shown above the field.
  Widget? intro,

  /// Shown below the field.
  Widget? footer,
}) => showDialog<String>(
  context: context,
  builder: (context) => _TextEntryDialog(
    title: title,
    label: label,
    confirmLabel: confirmLabel,
    initialText: initialText,
    keyboardType: keyboardType,
    obscureText: obscureText,
    trim: trim,
    maxLength: maxLength,
    suffixText: suffixText,
    intro: intro,
    footer: footer,
  ),
);

class _TextEntryDialog extends StatefulWidget {
  const _TextEntryDialog({
    required this.title,
    required this.label,
    required this.confirmLabel,
    required this.initialText,
    required this.keyboardType,
    required this.obscureText,
    required this.trim,
    required this.maxLength,
    required this.suffixText,
    required this.intro,
    required this.footer,
  });

  final String title;
  final String label;
  final String confirmLabel;
  final String initialText;
  final TextInputType? keyboardType;
  final bool obscureText;
  final bool trim;
  final int? maxLength;
  final String? suffixText;
  final Widget? intro;
  final Widget? footer;

  @override
  State<_TextEntryDialog> createState() => _TextEntryDialogState();
}

class _TextEntryDialogState extends State<_TextEntryDialog> {
  late final _controller = TextEditingController(text: widget.initialText);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirm() => Navigator.pop(
    context,
    widget.trim ? _controller.text.trim() : _controller.text,
  );

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.intro != null) ...[
          widget.intro!,
          const SizedBox(height: AppSpacing.space8),
        ],
        TextField(
          controller: _controller,
          autofocus: true,
          keyboardType: widget.keyboardType,
          obscureText: widget.obscureText,
          maxLength: widget.maxLength,
          decoration: InputDecoration(
            labelText: widget.label,
            suffixText: widget.suffixText,
          ),
        ),
        if (widget.footer != null) ...[
          const SizedBox(height: AppSpacing.space8),
          widget.footer!,
        ],
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Annuler'),
      ),
      FilledButton(onPressed: _confirm, child: Text(widget.confirmLabel)),
    ],
  );
}
