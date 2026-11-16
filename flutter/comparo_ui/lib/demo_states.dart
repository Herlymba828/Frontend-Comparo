/// Planche des états et limites (chargement, vide, erreur, hors connexion, limites).
library;

import 'package:flutter/material.dart';

import 'comparo_ui.dart';

class EtatsDemo extends StatelessWidget {
  const EtatsDemo({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.comparo;
    Widget lab(String t) => Padding(padding: const EdgeInsets.only(top: 14, bottom: 6), child: Text(t, style: ComparoText.label.copyWith(color: c.inkMuted)));
    final many = [for (final p in [4950, 4950, 4950, 4950, 5000, 5100, 5200, 5600, 5800, 6000]) p];
    return Scaffold(
      backgroundColor: c.canvas,
      body: ListView(padding: const EdgeInsets.all(ComparoDims.space5), children: [
        lab('Corde · 10 offres dont 4 au même prix → 8 affichées'),
        PriceLine(size: PriceLineSize.large, offers: [for (var i = 0; i < many.length; i++) PriceLineOffer(price: many[i], vendor: 'Vendeur ${String.fromCharCode(65 + i)} du quartier')]),
        lab('Corde · prix longs'),
        const PriceLine(size: PriceLineSize.large, offers: [
          PriceLineOffer(price: 118500, vendor: 'Dépôt Owendo Gros'),
          PriceLineOffer(price: 125000, vendor: 'Grossiste du Port-Môle'),
          PriceLineOffer(price: 131250, vendor: 'Supérette Bel-Air'),
        ]),
        lab('Corde · chargement'),
        const PriceLine(offers: [], size: PriceLineSize.large, loading: true),
        lab('Ardoise · erreur'),
        MarketSlate(title: 'Prix du jour', rows: const [], error: true, onRetry: () {}),
        lab('Ardoise · hors connexion, libellé long coupé'),
        const MarketSlate(title: 'Prix du jour', offline: 'prix du 3 nov., 18:40', rows: [
          SlateRow(label: 'Lait concentré sucré en boîte de 397 grammes', value: 1950),
          SlateRow(label: 'Huile végétale 1 L', value: 1350),
        ]),
        lab('Ardoise · vide'),
        const MarketSlate(title: 'Prix du jour', rows: []),
        lab('Ma liste · hors connexion'),
        const ListSummary(count: 5, best: 13950, save: 800, offline: '3 nov., 18:40'),
        lab('Ma liste · vide'),
        const ListSummary(count: 0),
        lab('Ma liste · chargement'),
        const ListSummary.loading(),
        lab('Preuve · hors connexion et chargement'),
        const ProofLine(level: ProofLevel.high, age: 'il y a 3 j', source: ProofSource.vendor, offline: true),
        const SizedBox(height: 8),
        const Align(alignment: Alignment.centerLeft, child: ProofLine.loading()),
      ]),
    );
  }
}
