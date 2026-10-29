import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/async_views.dart';
import '../commerce/commerce_models.dart';
import '../stores/stores_repository.dart';
import 'courier_repository.dart';

/// One delivery seen by the courier, with its next actions.
class CourierDeliveryScreen extends ConsumerStatefulWidget {
  const CourierDeliveryScreen({super.key, required this.deliveryId});

  final int deliveryId;

  @override
  ConsumerState<CourierDeliveryScreen> createState() =>
      _CourierDeliveryScreenState();
}

class _CourierDeliveryScreenState extends ConsumerState<CourierDeliveryScreen> {
  bool _busy = false;

  CourierRepository get _repo => ref.read(courierRepositoryProvider);

  Future<void> _run(Future<void> Function() action, String success) async {
    setState(() => _busy = true);
    try {
      await action();
      ref
        ..invalidate(courierDeliveryProvider(widget.deliveryId))
        ..invalidate(courierDeliveriesProvider(false))
        ..invalidate(courierDeliveriesProvider(true));
      if (mounted) {
        showInfo(context, success);
      }
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

  @override
  Widget build(BuildContext context) {
    final delivery = ref.watch(courierDeliveryProvider(widget.deliveryId));
    return Scaffold(
      appBar: AppBar(title: const Text('Course')),
      body: SignedInGate(
        role: 'courier',
        builder: (user) => AsyncBody<Delivery>(
          value: delivery,
          onRetry: () =>
              ref.invalidate(courierDeliveryProvider(widget.deliveryId)),
          builder: (delivery) {
            final mine = delivery.courierId == user.id;
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.space16),
              children: [
                SectionCard(
                  title: delivery.number,
                  trailing: StatusStamp(delivery.status),
                  children: [
                    InfoRow('Destinataire', delivery.recipientName ?? 'Masqué'),
                    InfoRow('Téléphone', delivery.recipientPhone ?? 'Masqué'),
                    InfoRow(
                      'Adresse',
                      [delivery.street, delivery.city, delivery.additionalInfo]
                          .whereType<String>()
                          .where((s) => s.isNotEmpty)
                          .join(', '),
                    ),
                    if (delivery.failureReason.isNotEmpty)
                      InfoRow('Incident', delivery.failureReason),
                    InfoRow(
                      'Preuve',
                      delivery.hasProof ? 'Enregistrée' : 'Aucune',
                    ),
                    if (!mine && delivery.status == 'pending')
                      const Padding(
                        padding: EdgeInsets.only(top: AppSpacing.space8),
                        child: Text(
                          'L’adresse et le téléphone s’affichent une fois la '
                          'course prise en charge.',
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.space12),
                ..._actions(delivery, mine),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _actions(Delivery delivery, bool mine) {
    final id = delivery.id;
    Widget button(
      String label,
      IconData icon,
      VoidCallback onPressed, {
      bool primary = true,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.space8),
      child: primary
          ? FilledButton.icon(
              onPressed: _busy ? null : onPressed,
              icon: Icon(icon),
              label: Text(label),
            )
          : OutlinedButton.icon(
              onPressed: _busy ? null : onPressed,
              icon: Icon(icon),
              label: Text(label),
            ),
    );
    if (!mine) {
      return [
        if (delivery.status == 'pending')
          button('Prendre cette course', Icons.pan_tool_alt, () {
            _run(() => _repo.claim(id), 'Course prise en charge.');
          }),
      ];
    }
    return switch (delivery.status) {
      'assigned' => [
        button('Colis récupéré, en route', Icons.directions_bike, () {
          _run(() => _repo.updateStatus(id, 'in_transit'), 'En route.');
        }),
        button(
          'Signaler un échec',
          Icons.report_problem_outlined,
          () => _fail(id),
          primary: false,
        ),
      ],
      'in_transit' => [
        button(
          'Enregistrer la preuve',
          Icons.verified_outlined,
          () => _proof(id),
          primary: !delivery.hasProof,
        ),
        if (delivery.hasProof)
          button('Marquer comme livrée', Icons.check_circle_outline, () {
            _run(
              () => _repo.updateStatus(id, 'delivered'),
              'Livraison terminée.',
            );
          }),
        button(
          'Partager ma position',
          Icons.my_location,
          () => _location(id),
          primary: false,
        ),
        button(
          'Signaler un échec',
          Icons.report_problem_outlined,
          () => _fail(id),
          primary: false,
        ),
      ],
      'failed' => [
        button('Colis retourné au marchand', Icons.keyboard_return, () {
          _run(() => _repo.updateStatus(id, 'returned'), 'Retour enregistré.');
        }),
      ],
      _ => const <Widget>[],
    };
  }

  Future<void> _fail(int id) async {
    final reason = await _ask('Motif de l’échec', [
      'Motif (client absent, adresse introuvable…)',
    ]);
    if (reason != null) {
      await _run(
        () => _repo.updateStatus(id, 'failed', note: reason.first),
        'Échec enregistré.',
      );
    }
  }

  Future<void> _proof(int id) async {
    final values = await _ask('Preuve de livraison', [
      'Lien de la photo (https://…)',
      'Lien de la signature (facultatif)',
    ], requireAll: false);
    if (values != null) {
      await _run(
        () =>
            _repo.recordProof(id, photoUrl: values[0], signatureUrl: values[1]),
        'Preuve enregistrée.',
      );
    }
  }

  /// Shares the device position (GPS), no coordinates to type.
  Future<void> _location(int id) async {
    final position = await locateUser();
    final lat = position.latitude;
    final lon = position.longitude;
    if (lat == null || lon == null) {
      if (mounted) {
        showInfo(context, position.problem ?? 'Position indisponible.');
      }
      return;
    }
    await _run(() => _repo.updateLocation(id, lat, lon), 'Position partagée.');
  }

  Future<List<String>?> _ask(
    String title,
    List<String> labels, {
    bool requireAll = true,
  }) {
    final controllers = [for (final _ in labels) TextEditingController()];
    return showDialog<List<String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < labels.length; i++)
              TextField(
                controller: controllers[i],
                decoration: InputDecoration(labelText: labels[i]),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              final values = [for (final c in controllers) c.text.trim()];
              final ok = requireAll
                  ? values.every((v) => v.isNotEmpty)
                  : values.first.isNotEmpty ||
                        values.skip(1).any((v) => v.isNotEmpty);
              if (ok) {
                Navigator.pop(context, values);
              }
            },
            child: const Text('Valider'),
          ),
        ],
      ),
    );
  }
}
