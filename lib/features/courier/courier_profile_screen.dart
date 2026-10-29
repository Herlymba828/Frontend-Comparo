import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/async_views.dart';
import 'courier_repository.dart';

/// The courier's availability, vehicle and phone.
class CourierProfileScreen extends ConsumerStatefulWidget {
  const CourierProfileScreen({super.key});

  @override
  ConsumerState<CourierProfileScreen> createState() =>
      CourierProfileScreenState();
}

class CourierProfileScreenState extends ConsumerState<CourierProfileScreen> {
  bool _saving = false;

  Future<void> _update({
    bool? available,
    String? phone,
    String? vehicle,
  }) async {
    setState(() => _saving = true);
    try {
      await ref
          .read(courierRepositoryProvider)
          .updateMyCourierProfile(
            isAvailable: available,
            phone: phone,
            vehicle: vehicle,
          );
      ref
        ..invalidate(myCourierProfileProvider)
        ..invalidate(courierDeliveriesProvider(true));
    } catch (error) {
      if (mounted) {
        showApiError(context, error);
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(myCourierProfileProvider),
      child: AsyncBody<CourierProfile>(
        value: ref.watch(myCourierProfileProvider),
        onRetry: () => ref.invalidate(myCourierProfileProvider),
        builder: (profile) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.space16),
          children: [
            SectionCard(
              title: profile.name,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Disponible pour de nouvelles courses'),
                  value: profile.isAvailable,
                  onChanged: _saving
                      ? null
                      : (value) => _update(available: value),
                ),
                InfoRow(
                  'Courses en cours',
                  '${profile.activeDeliveries} / ${profile.maxActive}',
                ),
                InfoRow(
                  'Zones',
                  profile.zones.isEmpty
                      ? 'Toutes les zones'
                      : profile.zones.join(', '),
                ),
                const SizedBox(height: AppSpacing.space8),
                DropdownButtonFormField<String>(
                  initialValue: vehicleLabels.containsKey(profile.vehicle)
                      ? profile.vehicle
                      : null,
                  decoration: const InputDecoration(labelText: 'Véhicule'),
                  items: [
                    for (final entry in vehicleLabels.entries)
                      DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                  ],
                  onChanged: _saving
                      ? null
                      : (value) => _update(vehicle: value),
                ),
                const SizedBox(height: AppSpacing.space8),
                _PhoneField(
                  initial: profile.phone,
                  enabled: !_saving,
                  onSave: (value) => _update(phone: value),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Phone number with an explicit save button: phone keyboards (iOS) have
/// no "send" key, so submitting alone never saved it.
class _PhoneField extends StatefulWidget {
  const _PhoneField({
    required this.initial,
    required this.enabled,
    required this.onSave,
  });

  final String initial;
  final bool enabled;
  final ValueChanged<String> onSave;

  @override
  State<_PhoneField> createState() => _PhoneFieldState();
}

class _PhoneFieldState extends State<_PhoneField> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() => widget.onSave(_controller.text.trim());

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      keyboardType: TextInputType.phone,
      decoration: InputDecoration(
        labelText: 'Téléphone (visible des marchands)',
        suffixIcon: IconButton(
          tooltip: 'Enregistrer le téléphone',
          icon: const Icon(Icons.check),
          onPressed: widget.enabled ? _save : null,
        ),
      ),
      onSubmitted: (_) => _save(),
    );
  }
}
