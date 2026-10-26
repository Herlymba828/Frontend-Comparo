import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Accès réseau de l'appareil (Wi-Fi, mobile, Ethernet…), sans garantie que
/// le serveur soit joignable.
abstract interface class ConnectivityService {
  Future<bool> hasNetwork();

  Stream<bool> get networkChanges;
}

class PluginConnectivityService implements ConnectivityService {
  PluginConnectivityService([Connectivity? connectivity])
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  static bool _isConnected(List<ConnectivityResult> results) =>
      results.any((result) => result != ConnectivityResult.none);

  @override
  Future<bool> hasNetwork() async {
    try {
      return _isConnected(await _connectivity.checkConnectivity());
    } on Exception catch (error) {
      // Plateforme sans plugin : l'erreur HTTP reste « serveur injoignable ».
      debugPrint('Connectivity check unavailable: $error');
      return true;
    }
  }

  @override
  Stream<bool> get networkChanges => _connectivity.onConnectivityChanged
      .map(_isConnected)
      .handleError((Object error) {
        debugPrint('Connectivity updates unavailable: $error');
      });
}

final connectivityServiceProvider = Provider<ConnectivityService>(
  (ref) => PluginConnectivityService(),
);

/// Délai avant d'actualiser au retour du réseau, pour absorber les
/// basculements rapides et limiter les requêtes.
const reconnectDebounce = Duration(seconds: 2);

/// Incrémenté à chaque retour du réseau (après une coupure).
class ReconnectNotifier extends Notifier<int> {
  Timer? _debounce;

  @override
  int build() {
    var wasOnline = true;
    final subscription = ref
        .watch(connectivityServiceProvider)
        .networkChanges
        .listen((online) {
          if (online && !wasOnline) {
            _debounce?.cancel();
            _debounce = Timer(reconnectDebounce, () => state++);
          } else if (!online) {
            _debounce?.cancel();
          }
          wasOnline = online;
        });
    ref.onDispose(() {
      _debounce?.cancel();
      subscription.cancel();
    });
    return 0;
  }
}

final reconnectProvider = NotifierProvider<ReconnectNotifier, int>(
  ReconnectNotifier.new,
);

/// Rafraîchit le provider au retour du réseau, uniquement si sa dernière
/// valeur venait du cache ou avait échoué. Les données affichées restent
/// visibles pendant l'actualisation.
void refreshOnReconnect(Ref ref, bool Function() needsRefresh) {
  ref.listen(reconnectProvider, (_, _) {
    if (needsRefresh()) {
      ref.invalidateSelf();
    }
  });
}
