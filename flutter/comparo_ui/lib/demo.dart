/// Écrans de démonstration, composés uniquement des widgets de `comparo_ui`.
/// Ils servent aux captures de référence et de point de départ aux écrans de l'app.
library;

import 'package:flutter/material.dart';

import 'comparo_ui.dart';

const _offers = [
  PriceLineOffer(price: 4950, vendor: 'Épicerie du Rond-Point'),
  PriceLineOffer(price: 5100, vendor: 'Dépôt Owendo Gros'),
  PriceLineOffer(price: 5350, vendor: 'Supérette Bel-Air'),
  PriceLineOffer(price: 5600, vendor: 'Boutique Sainte-Anne'),
];

/// Fiche produit : meilleur prix, corde, liste des offres.
class FicheDemo extends StatelessWidget {
  const FicheDemo({super.key, this.onSelect});
  final ValueChanged<PriceLineOffer>? onSelect;

  @override
  Widget build(BuildContext context) {
    final c = context.comparo;
    return Scaffold(
      backgroundColor: c.canvas,
      bottomNavigationBar: ComparoNavigationBar(
        currentIndex: 1,
        onTap: (_) {},
        items: const [
          ComparoNavItem(icon: Icons.home_outlined, label: 'Accueil'),
          ComparoNavItem(icon: Icons.search_rounded, label: 'Recherche'),
          ComparoNavItem(icon: Icons.checklist_rounded, label: 'Ma liste', badge: 5),
          ComparoNavItem(icon: Icons.person_outline_rounded, label: 'Profil'),
        ],
      ),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(ComparoDims.space5), children: [
          Row(children: [
            const ProductPicto(kind: PictoKind.riz, brand: 'Marque A', large: true),
            const SizedBox(width: ComparoDims.space3),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Riz parfumé 5 kg', style: ComparoText.title.copyWith(color: c.ink)),
                Text('Marque A · 4 offres', style: ComparoText.caption.copyWith(color: c.inkMuted)),
              ]),
            ),
          ]),
          const SizedBox(height: ComparoDims.space4),
          Container(
            padding: const EdgeInsets.all(ComparoDims.space4),
            decoration: BoxDecoration(
              color: c.paper,
              borderRadius: BorderRadius.circular(ComparoDims.radiusLg),
              border: Border.all(color: c.lineSoft),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Le moins cher', style: ComparoText.label.copyWith(color: c.primary)),
              const SizedBox(height: ComparoDims.space2),
              const PriceTag.amount(4950, large: true),
              const SizedBox(height: ComparoDims.space2),
              Text('Épicerie du Rond-Point · le kilo revient à 990 F', style: ComparoText.caption.copyWith(color: c.inkMuted)),
              const SizedBox(height: ComparoDims.space2),
              const ProofLine(level: ProofLevel.high, age: 'hier', source: ProofSource.vendor),
            ]),
          ),
          const SizedBox(height: ComparoDims.space4),
          const SectionTitle('Toutes les offres'),
          const SizedBox(height: ComparoDims.space3),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
            decoration: BoxDecoration(color: c.paper, borderRadius: BorderRadius.circular(ComparoDims.radiusCard), border: Border.all(color: c.lineSoft)),
            child: PriceLine(offers: _offers, size: PriceLineSize.large, onSelect: onSelect ?? (_) {}),
          ),
          const SizedBox(height: ComparoDims.space3),
          OfferTile(vendor: 'Dépôt Owendo Gros', price: 5100, bestPrice: 4950, onAdd: () {}, proof: const ProofLine(level: ProofLevel.medium, age: 'il y a 1 j', source: ProofSource.field)),
          OfferTile(vendor: 'Supérette Bel-Air', price: 5350, bestPrice: 4950, stockLimited: true, onAdd: () {}, proof: const ProofLine(level: ProofLevel.medium, age: 'il y a 9 j')),
          OfferTile(vendor: 'Boutique Sainte-Anne', price: 5600, bestPrice: 4950, onAdd: () {}, proof: const ProofLine(level: ProofLevel.low, age: "aujourd'hui", source: ProofSource.field)),
        ]),
      ),
    );
  }
}

/// Accueil et Ma liste : ardoise, résultat avec petite corde, choix d'achat, saisie en étiquette.
class ListeDemo extends StatefulWidget {
  const ListeDemo({super.key});
  @override
  State<ListeDemo> createState() => _ListeDemoState();
}

class _ListeDemoState extends State<ListeDemo> {
  final _price = TextEditingController(text: '7200');
  int _choice = 0;

  @override
  void dispose() {
    _price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.comparo;
    return Scaffold(
      backgroundColor: c.canvas,
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(ComparoDims.space5), children: [
          MarketSlate(
            title: 'Prix du jour',
            meta: 'Libreville · le moins cher vérifié',
            footer: 'En FCFA · mis à jour il y a 2 h',
            rows: [
              SlateRow(label: 'Riz parfumé 5 kg', value: 4950, onTap: () {}),
              SlateRow(label: 'Huile végétale 1 L', value: 1350, onTap: () {}),
              const SlateRow(label: 'Sucre en poudre 1 kg', missing: 'manque 1'),
            ],
          ),
          const SizedBox(height: ComparoDims.space4),
          const SectionTitle('Résultat'),
          const SizedBox(height: ComparoDims.space3),
          Container(
            padding: const EdgeInsets.all(ComparoDims.space3),
            decoration: BoxDecoration(color: c.paper, borderRadius: BorderRadius.circular(ComparoDims.radiusCard), border: Border.all(color: c.lineSoft)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const ProductPicto(kind: PictoKind.huile, brand: 'Marque D', large: true),
                const SizedBox(width: ComparoDims.space3),
                Expanded(child: Text('Huile végétale 1 L', style: ComparoText.subtitle.copyWith(color: c.ink))),
                const PriceTag.text('−800 F'),
              ]),
              const SizedBox(height: ComparoDims.space2),
              const PriceLine(offers: [
                PriceLineOffer(price: 1350, vendor: 'Supérette Bel-Air'),
                PriceLineOffer(price: 1450, vendor: 'Épicerie du Rond-Point'),
                PriceLineOffer(price: 1500, vendor: 'Marché central'),
              ]),
              const SizedBox(height: ComparoDims.space2),
              Row(children: [
                Text('Le moins cher ', style: ComparoText.caption.copyWith(color: c.primary, fontWeight: FontWeight.w700)),
                const PricePlain(1350),
              ]),
            ]),
          ),
          const SizedBox(height: ComparoDims.space4),
          const SectionTitle('Comment acheter ?'),
          const SizedBox(height: ComparoDims.space3),
          ChoiceCard(title: 'Tout au même endroit', amount: 14250, subtitle: 'Épicerie du Rond-Point · un seul déplacement', selected: _choice == 0, onTap: () => setState(() => _choice = 0)),
          const SizedBox(height: 10),
          ChoiceCard(title: 'Le moins cher · 2 arrêts', amount: 13950, subtitle: '300 F de moins, pour 1 arrêt de plus', selected: _choice == 1, onTap: () => setState(() => _choice = 1)),
          const SizedBox(height: ComparoDims.space4),
          PriceInputTag(controller: _price, knownLowest: 4950),
        ]),
      ),
    );
  }
}

/// Accueil (point 5) : en-tête clair, une seule surface forte (l'ardoise),
/// « Ma liste » en premier quand elle existe, racheter la liste de la semaine dernière.
class AccueilDemo extends StatelessWidget {
  const AccueilDemo({super.key, this.withList = true, this.offline, this.loading = false});
  final bool withList;
  final String? offline;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final c = context.comparo;
    final slate = loading
        ? const MarketSlate(title: 'Prix du jour', rows: [], loading: true)
        : MarketSlate(
            title: 'Prix du jour',
            meta: 'Libreville · le moins cher vérifié',
            footer: 'En FCFA · mis à jour il y a 2 h',
            offline: offline == null ? null : 'prix du $offline',
            rows: [
              SlateRow(label: 'Riz parfumé 5 kg', value: 4950, onTap: () {}),
              SlateRow(label: 'Huile végétale 1 L', value: 1350, onTap: () {}),
              SlateRow(label: 'Sucre en poudre 1 kg', value: 800, onTap: () {}),
            ],
          );
    final list = loading
        ? const ListSummary.loading()
        : ListSummary(count: withList ? 5 : 0, best: 13950, save: 800, offline: offline, onOpen: () {}, onStart: () {});
    return Scaffold(
      backgroundColor: c.canvas,
      bottomNavigationBar: ComparoNavigationBar(currentIndex: 0, onTap: (_) {}, items: [
        const ComparoNavItem(icon: Icons.home_outlined, label: 'Accueil'),
        const ComparoNavItem(icon: Icons.search_rounded, label: 'Recherche'),
        ComparoNavItem(icon: Icons.checklist_rounded, label: 'Ma liste', badge: withList ? 5 : null),
        const ComparoNavItem(icon: Icons.person_outline_rounded, label: 'Profil'),
      ]),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(ComparoDims.space5, ComparoDims.space4, ComparoDims.space5, ComparoDims.space5), children: [
          Row(children: [
            Text('Comparo', style: ComparoText.title.copyWith(color: c.ink, fontWeight: FontWeight.w800, fontVariations: const [FontVariation('wght', 800), FontVariation('opsz', 20)])),
            const Spacer(),
            Semantics(
              button: true,
              label: 'Zone : Libreville',
              child: Container(
                height: ComparoDims.targetMin,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(color: c.fill100, borderRadius: BorderRadius.circular(ComparoDims.radiusPill)),
                child: Row(children: [
                  Icon(Icons.place_outlined, size: ComparoDims.iconSm, color: c.ink),
                  const SizedBox(width: 6),
                  Text('Libreville', style: ComparoText.label.copyWith(color: c.ink, fontSize: 13)),
                ]),
              ),
            ),
          ]),
          const SizedBox(height: 14),
          Text("Au marché aujourd'hui", style: ComparoText.display.copyWith(color: c.ink)),
          const SizedBox(height: ComparoDims.space1),
          Text('Libreville · prix relevés ce matin', style: ComparoText.caption.copyWith(color: c.inkMuted, fontWeight: FontWeight.w600, fontVariations: const [FontVariation('wght', 600)])),
          const SizedBox(height: 14),
          Semantics(
            button: true,
            label: 'Rechercher un produit',
            excludeSemantics: true,
            child: Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(color: c.paper, borderRadius: BorderRadius.circular(ComparoDims.radiusPill), border: Border.all(color: c.lineSoft)),
              child: Row(children: [
                Icon(Icons.search_rounded, size: ComparoDims.iconMd, color: c.ink),
                const SizedBox(width: 10),
                Expanded(child: Text('Riz, huile, savon…', style: ComparoText.body.copyWith(color: c.inkMuted, fontWeight: FontWeight.w500))),
                Icon(Icons.qr_code_scanner_rounded, size: ComparoDims.iconMd, color: c.ink),
              ]),
            ),
          ),
          const SizedBox(height: 14),
          if (withList || loading) ...[list, const SizedBox(height: 14), slate] else ...[slate, const SizedBox(height: 14), list],
          const SizedBox(height: 14),
          if (!loading)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: ComparoDims.space3),
              decoration: BoxDecoration(color: c.paper, borderRadius: BorderRadius.circular(ComparoDims.radiusCard), border: Border.all(color: c.lineSoft)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Racheter la liste du 4 nov.', style: ComparoText.subtitle.copyWith(color: c.ink)),
                      Text('4 produits', style: ComparoText.caption.copyWith(color: c.inkMuted)),
                    ]),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.add_rounded, size: ComparoDims.iconSm),
                    label: const Text('Ajouter 4'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size(ComparoDims.targetMin, ComparoDims.targetMin), foregroundColor: c.ink, side: BorderSide(color: c.line)),
                  ),
                ]),
                const SizedBox(height: 10),
                const Row(children: [
                  ProductPicto(kind: PictoKind.riz),
                  SizedBox(width: 6),
                  ProductPicto(kind: PictoKind.huile),
                  SizedBox(width: 6),
                  ProductPicto(kind: PictoKind.sucre),
                  SizedBox(width: 6),
                  ProductPicto(kind: PictoKind.lait),
                ]),
              ]),
            ),
        ]),
      ),
    );
  }
}
