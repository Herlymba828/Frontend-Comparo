import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/contributions/report_outbox.dart';
import 'app.dart';

void bootstrap() {
  runApp(const ProviderScope(child: _OfflineSync(child: ComparateurPrixApp())));
}

/// Keeps the offline queue alive for the whole session: reports left from a
/// previous session leave at start, the others when the network is back.
class _OfflineSync extends ConsumerStatefulWidget {
  const _OfflineSync({required this.child});

  final Widget child;

  @override
  ConsumerState<_OfflineSync> createState() => _OfflineSyncState();
}

class _OfflineSyncState extends ConsumerState<_OfflineSync> {
  @override
  void initState() {
    super.initState();
    ref.read(reportOutboxProvider.notifier).sync();
  }

  @override
  Widget build(BuildContext context) {
    // Watching keeps the queue (and its reconnection listener) alive.
    ref.watch(reportOutboxProvider);
    return widget.child;
  }
}
