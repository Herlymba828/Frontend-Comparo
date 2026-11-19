import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/widgets/text_entry_dialog.dart';

/// A button that opens the dialog and keeps what it returned.
Future<ValueNotifier<Object?>> _open(
  WidgetTester tester, {
  String initialText = '',
  bool obscureText = false,
  bool trim = true,
  Widget? intro,
  Widget? footer,
}) async {
  final result = ValueNotifier<Object?>('not answered');
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async => result.value = await showTextEntry(
              context,
              title: 'Motif',
              label: 'Votre texte',
              confirmLabel: 'Envoyer',
              initialText: initialText,
              obscureText: obscureText,
              trim: trim,
              intro: intro,
              footer: footer,
            ),
            child: const Text('Ouvrir'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Ouvrir'));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  testWidgets('returns what was typed, trimmed', (tester) async {
    final result = await _open(tester);

    await tester.enterText(find.byType(TextField), '  Prix erroné  ');
    await tester.tap(find.text('Envoyer'));
    await tester.pumpAndSettle();

    expect(result.value, 'Prix erroné');
  });

  testWidgets('returns null when cancelled', (tester) async {
    final result = await _open(tester);

    await tester.enterText(find.byType(TextField), 'abandonné');
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();

    expect(result.value, isNull);
  });

  testWidgets('an empty confirmation is an empty text, not a cancellation', (
    tester,
  ) async {
    final result = await _open(tester);

    await tester.tap(find.text('Envoyer'));
    await tester.pumpAndSettle();

    expect(result.value, '');
  });

  testWidgets('a password is returned exactly as typed', (tester) async {
    final result = await _open(tester, obscureText: true, trim: false);

    await tester.enterText(find.byType(TextField), ' secret ');
    await tester.tap(find.text('Envoyer'));
    await tester.pumpAndSettle();

    expect(result.value, ' secret ');
  });

  testWidgets('starts with the given text, an intro and a footer', (
    tester,
  ) async {
    await _open(
      tester,
      initialText: '1800',
      intro: const Text('Le montant restant est remboursé.'),
      footer: const Text('L’ancien prix reste dans l’historique.'),
    );

    expect(find.text('1800'), findsOneWidget);
    expect(find.text('Le montant restant est remboursé.'), findsOneWidget);
    expect(find.text('L’ancien prix reste dans l’historique.'), findsOneWidget);
  });

  testWidgets('closing leaves no error behind, however many times it opens', (
    tester,
  ) async {
    // The dialog used to be closed with its controller already disposed:
    // an exception while it animated out.
    final result = await _open(tester);
    for (var round = 0; round < 3; round++) {
      await tester.enterText(find.byType(TextField), 'tour $round');
      await tester.tap(find.text('Envoyer'));
      // Mid-animation: the closing dialog still draws its field.
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(result.value, 'tour $round');
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();
    }
  });
}
