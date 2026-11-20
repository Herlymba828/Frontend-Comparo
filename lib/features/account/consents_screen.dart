import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/async_views.dart';
import 'consents_repository.dart';

/// Privacy choices: what the person lets the app do with their data. Each
/// switch is dated and can be turned back off at any time.
class ConsentsScreen extends ConsumerWidget {
  const ConsentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Confidentialité')),
    body: SignedInGate(builder: (user) => const _ConsentsBody()),
  );
}

class _ConsentsBody extends ConsumerStatefulWidget {
  const _ConsentsBody();

  @override
  ConsumerState<_ConsentsBody> createState() => _ConsentsBodyState();
}

class _ConsentsBodyState extends ConsumerState<_ConsentsBody> {
  final _busy = <String>{};

  Future<void> _toggle(Consent consent, bool granted) async {
    setState(() => _busy.add(consent.purpose));
    try {
      await ref
          .read(consentsRepositoryProvider)
          .set(consent.purpose, granted: granted);
      ref.invalidate(consentsProvider);
      await ref.read(consentsProvider.future);
    } catch (error) {
      if (mounted) {
        showApiError(context, error);
      }
    } finally {
      if (mounted) {
        setState(() => _busy.remove(consent.purpose));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final consents = ref.watch(consentsProvider);
    return AsyncBody<List<Consent>>(
      value: consents,
      onRetry: () => ref.invalidate(consentsProvider),
      builder: (items) => ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Rien n’est activé sans votre accord. Vous pouvez le retirer '
              'à tout moment.',
            ),
          ),
          for (final consent in items)
            SwitchListTile(
              title: Text(consent.label),
              subtitle: Text(consentExplanations[consent.purpose] ?? ''),
              value: consent.granted,
              onChanged: _busy.contains(consent.purpose)
                  ? null
                  : (value) => _toggle(consent, value),
            ),
        ],
      ),
    );
  }
}
