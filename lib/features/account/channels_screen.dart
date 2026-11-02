import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/async_views.dart';
import 'channels_repository.dart';

const _channelIcons = {
  'telegram': Icons.send_outlined,
  'whatsapp': Icons.chat_outlined,
  'sms': Icons.sms_outlined,
};

const _channelHints = {
  'telegram': 'Alertes et bot de prix',
  'whatsapp': 'Alertes et bot de prix',
  'sms': 'Alertes uniquement (peut être facturé)',
};

/// Channels outside the app: linking (the user's consent), preferred and
/// fallback channels, frequency and alert types.
class ChannelsScreen extends ConsumerWidget {
  const ChannelsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Canaux de notification')),
      body: SignedInGate(builder: (user) => const _ChannelsBody()),
    );
  }
}

class _ChannelsBody extends ConsumerStatefulWidget {
  const _ChannelsBody();

  @override
  ConsumerState<_ChannelsBody> createState() => _ChannelsBodyState();
}

class _ChannelsBodyState extends ConsumerState<_ChannelsBody> {
  bool _busy = false;

  ChannelsRepository get _repo => ref.read(channelsRepositoryProvider);

  void _refresh() {
    ref
      ..invalidate(messagingChannelsProvider)
      ..invalidate(channelPreferencesProvider);
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      _refresh();
    } catch (error) {
      if (mounted) {
        showApiError(context, error);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _link(MessagingChannel channel) async {
    if (channel.channel == 'sms') {
      await _linkSms();
      return;
    }
    await _run(() async {
      final started = await _repo.startLink(channel.channel);
      if (mounted) {
        await _showBotLink(channel, started);
      }
    });
  }

  /// The bot receives the code from the user's own chat: the app only opens it.
  Future<void> _showBotLink(
    MessagingChannel channel,
    StartedChannelLink started,
  ) async {
    final uri = Uri.tryParse(started.deepLink);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Lier ${channel.label}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              channel.channel == 'whatsapp'
                  ? 'Envoyez ce message au bot depuis WhatsApp :'
                  : 'Démarrez le bot depuis Telegram, ou envoyez-lui :',
            ),
            const SizedBox(height: AppSpacing.space8),
            SelectableText(
              '${channel.channel == 'whatsapp' ? 'LIER' : '/start'} '
              '${started.code}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.space8),
            const Text('Ce code expire dans 15 minutes.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: started.code));
              showInfo(context, 'Code copié.');
            },
            child: const Text('Copier le code'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
          if (uri != null && uri.hasScheme)
            FilledButton(
              onPressed: () =>
                  launchUrl(uri, mode: LaunchMode.externalApplication),
              child: Text('Ouvrir ${channel.label}'),
            ),
        ],
      ),
    );
  }

  Future<void> _linkSms() async {
    final phone = await _ask(
      title: 'Lier mon numéro',
      label: 'Numéro (ex. +241 06 12 34 56)',
      keyboard: TextInputType.phone,
    );
    if (phone == null || phone.isEmpty || !mounted) {
      return;
    }
    await _run(() async {
      final started = await _repo.startLink('sms', phone: phone);
      if (!mounted) {
        return;
      }
      final code = await _ask(
        title: 'Code reçu par SMS',
        label: 'Code à 6 chiffres',
        keyboard: TextInputType.number,
      );
      if (code != null && code.isNotEmpty) {
        await _repo.confirmSms(started.id, code);
      }
    });
  }

  Future<String?> _ask({
    required String title,
    required String label,
    required TextInputType keyboard,
  }) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: keyboard,
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Valider'),
          ),
        ],
      ),
    );
    controller.dispose();
    return value;
  }

  Future<void> _unlink(MessagingChannel channel) async {
    final ok = await confirmAction(
      context,
      title: 'Délier ${channel.label} ?',
      message: 'Vous ne recevrez plus aucun message sur ce canal.',
      confirmLabel: 'Délier',
    );
    final linkId = channel.linkId;
    if (ok && linkId != null) {
      await _run(() => _repo.unlink(linkId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => _refresh(),
      child: AsyncBody<List<MessagingChannel>>(
        value: ref.watch(messagingChannelsProvider),
        onRetry: _refresh,
        builder: (channels) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.space16),
          children: [
            SectionCard(
              title: 'Mes canaux',
              children: [
                const Text(
                  'Rien n’est envoyé sur un canal que vous n’avez pas lié. '
                  'Écrivez STOP au bot pour tout arrêter.',
                ),
                for (final channel in channels) _channelTile(channel),
              ],
            ),
            const SizedBox(height: AppSpacing.space12),
            _PreferencesCard(
              linked: channels.where((c) => c.isLinked).toList(),
              enabled: !_busy,
              onChange: _run,
            ),
          ],
        ),
      ),
    );
  }

  Widget _channelTile(MessagingChannel channel) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(
      _channelIcons[channel.channel] ?? Icons.forum_outlined,
      color: AppColors.primary,
    ),
    title: Text(channel.label),
    subtitle: Text(
      channel.isAvailable
          ? _channelHints[channel.channel] ?? ''
          : 'Bientôt disponible',
    ),
    trailing: !channel.isAvailable && !channel.isLinked
        ? null
        : channel.isLinked
        ? TextButton(
            onPressed: _busy ? null : () => _unlink(channel),
            child: const Text('Délier'),
          )
        : OutlinedButton(
            onPressed: _busy ? null : () => _link(channel),
            child: const Text('Lier'),
          ),
  );
}

class _PreferencesCard extends ConsumerWidget {
  const _PreferencesCard({
    required this.linked,
    required this.enabled,
    required this.onChange,
  });

  final List<MessagingChannel> linked;
  final bool enabled;
  final Future<void> Function(Future<void> Function()) onChange;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(channelsRepositoryProvider);
    return AsyncBody<ChannelPreferences>(
      value: ref.watch(channelPreferencesProvider),
      onRetry: () => ref.invalidate(channelPreferencesProvider),
      builder: (preferences) {
        final labels = {for (final c in linked) c.channel: c.label};
        return SectionCard(
          title: 'Mes préférences',
          children: [
            _ChannelPicker(
              label: 'Canal préféré',
              noneLabel: 'Application seulement',
              value: preferences.preferred,
              options: labels,
              onChanged: enabled
                  ? (value) => onChange(
                      () => repo.updatePreferences(
                        preferred: value,
                        fallback: value == preferences.fallback || value.isEmpty
                            ? ''
                            : preferences.fallback,
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: AppSpacing.space8),
            _ChannelPicker(
              label: 'Canal de secours',
              noneLabel: 'Aucun',
              value: preferences.fallback,
              options: {...labels}..remove(preferences.preferred),
              onChanged: enabled && preferences.preferred.isNotEmpty
                  ? (value) =>
                        onChange(() => repo.updatePreferences(fallback: value))
                  : null,
            ),
            const SizedBox(height: AppSpacing.space8),
            DropdownButtonFormField<String>(
              initialValue: preferences.frequency,
              decoration: const InputDecoration(labelText: 'Fréquence'),
              items: [
                for (final entry in notificationFrequencies.entries)
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)),
              ],
              onChanged: enabled
                  ? (value) =>
                        onChange(() => repo.updatePreferences(frequency: value))
                  : null,
            ),
            const SizedBox(height: AppSpacing.space8),
            for (final entry in mutableNotificationTypes.entries)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(entry.value),
                value: !preferences.mutedTypes.contains(entry.key),
                onChanged: enabled
                    ? (on) => onChange(
                        () => repo.updatePreferences(
                          mutedTypes: on
                              ? (preferences.mutedTypes.toList()
                                  ..remove(entry.key))
                              : [...preferences.mutedTypes, entry.key],
                        ),
                      )
                    : null,
              ),
          ],
        );
      },
    );
  }
}

class _ChannelPicker extends StatelessWidget {
  const _ChannelPicker({
    required this.label,
    required this.noneLabel,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String noneLabel;
  final String value;
  final Map<String, String> options;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    // A channel unlinked since: the saved value is shown as "none".
    final current = options.containsKey(value) ? value : '';
    return DropdownButtonFormField<String>(
      key: ValueKey('$label-$current-${options.length}'),
      initialValue: current,
      decoration: InputDecoration(labelText: label),
      items: [
        DropdownMenuItem(value: '', child: Text(noneLabel)),
        for (final entry in options.entries)
          DropdownMenuItem(value: entry.key, child: Text(entry.value)),
      ],
      onChanged: onChanged == null ? null : (value) => onChanged!(value ?? ''),
    );
  }
}
