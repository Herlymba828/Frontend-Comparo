# Wireframes et maquettes — Comparo

Export du canvas « Wireframes Comparateur de prix » (claude.ai), version du 13/11/2026 : wireframes en niveaux de gris, écrans haute fidélité (identité « corde à prix », design system v2.4) et back-office.

Ce dossier est une **référence de conception** : il ne fait pas partie de l'application Flutter et n'est pas compilé.

## Contenu

| Dossier | Ce qu'il contient |
|---|---|
| `apercus/` | Une capture PNG par écran (58 écrans), à ouvrir directement sur GitHub |
| `canvas/` | Les sources du canvas : un fichier `*.dc.html` par écran, `canvas.json` (disposition et titres des planches), `hf.css`, `proto.css` et la copie du design system dans `ds/wf/` (tokens, composants) |
| `prototype/comparo-prototype.html` | Le prototype cliquable (un seul fichier HTML, sans dépendance) : ouvrez-le dans un navigateur |

## Ouvrir les écrans

- **Le plus simple** : les captures de `apercus/`, ou le prototype dans un navigateur.
- Les fichiers `canvas/*.dc.html` sont faits pour l'éditeur de canvas : ils chargent un `support.js` fourni par l'éditeur, absent ici. Leur contenu (HTML et styles) reste lisible tel quel et sert de référence pour l'intégration Flutter.

## Écrans

### Haute fidélité (application mobile, 390 × 844)

| Écran | Source | Aperçu |
|---|---|---|
| Bienvenue · choix de la zone | [`HF-Bienvenue.dc.html`](canvas/HF-Bienvenue.dc.html) | [aperçu](apercus/HF-Bienvenue.png) |
| Accueil | [`HF-Accueil.dc.html`](canvas/HF-Accueil.dc.html) | [aperçu](apercus/HF-Accueil.png) |
| Résultats | [`HF-Resultats.dc.html`](canvas/HF-Resultats.dc.html) | [aperçu](apercus/HF-Resultats.png) |
| Aucun résultat | [`HF-AucunResultat.dc.html`](canvas/HF-AucunResultat.dc.html) | [aperçu](apercus/HF-AucunResultat.png) |
| Fiche produit et offres | [`HF-Fiche.dc.html`](canvas/HF-Fiche.dc.html) | [aperçu](apercus/HF-Fiche.png) |
| Fiabilité d'un prix | [`HF-Fiabilite.dc.html`](canvas/HF-Fiabilite.dc.html) | [aperçu](apercus/HF-Fiabilite.png) |
| Historique et tendance · P1 | [`HF-Historique.dc.html`](canvas/HF-Historique.dc.html) | [aperçu](apercus/HF-Historique.png) |
| Prévision · P2 | [`HF-Prevision.dc.html`](canvas/HF-Prevision.dc.html) | [aperçu](apercus/HF-Prevision.png) |
| Hors connexion · P1 | [`HF-HorsLigne.dc.html`](canvas/HF-HorsLigne.dc.html) | [aperçu](apercus/HF-HorsLigne.png) |
| Accueil · premier lancement | [`HF-Accueil-Premier.dc.html`](canvas/HF-Accueil-Premier.dc.html) | [aperçu](apercus/HF-Accueil-Premier.png) |
| Accueil · hors connexion | [`HF-Accueil-HorsLigne.dc.html`](canvas/HF-Accueil-HorsLigne.dc.html) | [aperçu](apercus/HF-Accueil-HorsLigne.png) |
| Accueil · réseau lent (chargement) | [`HF-Accueil-Chargement.dc.html`](canvas/HF-Accueil-Chargement.dc.html) | [aperçu](apercus/HF-Accueil-Chargement.png) |
| Connexion | [`HF-Connexion.dc.html`](canvas/HF-Connexion.dc.html) | [aperçu](apercus/HF-Connexion.png) |
| Inscription | [`HF-Inscription.dc.html`](canvas/HF-Inscription.dc.html) | [aperçu](apercus/HF-Inscription.png) |
| Profil | [`HF-Profil.dc.html`](canvas/HF-Profil.dc.html) | [aperçu](apercus/HF-Profil.png) |
| Favoris · P1 | [`HF-Favoris.dc.html`](canvas/HF-Favoris.dc.html) | [aperçu](apercus/HF-Favoris.png) |
| Mes alertes · P1 | [`HF-Alertes.dc.html`](canvas/HF-Alertes.dc.html) | [aperçu](apercus/HF-Alertes.png) |
| Créer une alerte · P1 | [`HF-CreerAlerte.dc.html`](canvas/HF-CreerAlerte.dc.html) | [aperçu](apercus/HF-CreerAlerte.png) |
| Notifications · P1 | [`HF-Notifications.dc.html`](canvas/HF-Notifications.dc.html) | [aperçu](apercus/HF-Notifications.png) |
| Budget · P2 | [`HF-Budget.dc.html`](canvas/HF-Budget.dc.html) | [aperçu](apercus/HF-Budget.png) |
| Ma liste · P1 | [`HF-Panier.dc.html`](canvas/HF-Panier.dc.html) | [aperçu](apercus/HF-Panier.png) |
| Optimiser le panier · P2 | [`HF-Optimisation.dc.html`](canvas/HF-Optimisation.dc.html) | [aperçu](apercus/HF-Optimisation.png) |
| Récapitulatif de commande · P1 | [`HF-Commande.dc.html`](canvas/HF-Commande.dc.html) | [aperçu](apercus/HF-Commande.png) |
| Paiement mobile money · P1 | [`HF-Paiement.dc.html`](canvas/HF-Paiement.dc.html) | [aperçu](apercus/HF-Paiement.png) |
| Paiement confirmé · P1 | [`HF-PaiementOk.dc.html`](canvas/HF-PaiementOk.dc.html) | [aperçu](apercus/HF-PaiementOk.png) |
| Suivi de commande · P1 | [`HF-Suivi.dc.html`](canvas/HF-Suivi.dc.html) | [aperçu](apercus/HF-Suivi.png) |
| Mes commandes · P1 | [`HF-MesCommandes.dc.html`](canvas/HF-MesCommandes.dc.html) | [aperçu](apercus/HF-MesCommandes.png) |
| Signaler un problème · P1 | [`HF-Litige.dc.html`](canvas/HF-Litige.dc.html) | [aperçu](apercus/HF-Litige.png) |
| Support · P1 | [`HF-Support.dc.html`](canvas/HF-Support.dc.html) | [aperçu](apercus/HF-Support.png) |
| Assistant · P2 | [`HF-Assistant.dc.html`](canvas/HF-Assistant.dc.html) | [aperçu](apercus/HF-Assistant.png) |
| Créer son commerce | [`HF-MarchandProfil.dc.html`](canvas/HF-MarchandProfil.dc.html) | [aperçu](apercus/HF-MarchandProfil.png) |
| Vérification du commerce | [`HF-MarchandStatut.dc.html`](canvas/HF-MarchandStatut.dc.html) | [aperçu](apercus/HF-MarchandStatut.png) |
| Points de vente | [`HF-PointsDeVente.dc.html`](canvas/HF-PointsDeVente.dc.html) | [aperçu](apercus/HF-PointsDeVente.png) |
| Mes prix | [`HF-MesPrix.dc.html`](canvas/HF-MesPrix.dc.html) | [aperçu](apercus/HF-MesPrix.png) |
| Publier un prix | [`HF-Publier.dc.html`](canvas/HF-Publier.dc.html) | [aperçu](apercus/HF-Publier.png) |
| Stock | [`HF-Stock.dc.html`](canvas/HF-Stock.dc.html) | [aperçu](apercus/HF-Stock.png) |
| Commandes reçues · P1 | [`HF-CommandesRecues.dc.html`](canvas/HF-CommandesRecues.dc.html) | [aperçu](apercus/HF-CommandesRecues.png) |
| Statistiques · P1 | [`HF-Statistiques.dc.html`](canvas/HF-Statistiques.dc.html) | [aperçu](apercus/HF-Statistiques.png) |
| Relever un prix | [`HF-Releve.dc.html`](canvas/HF-Releve.dc.html) | [aperçu](apercus/HF-Releve.png) |
| Mes relevés | [`HF-MesContributions.dc.html`](canvas/HF-MesContributions.dc.html) | [aperçu](apercus/HF-MesContributions.png) |

### Back-office (web, 1280 × 800)

| Écran | Source | Aperçu |
|---|---|---|
| Validation des prix | [`BO-Validation.dc.html`](canvas/BO-Validation.dc.html) | [aperçu](apercus/BO-Validation.png) |
| Vérification des marchands | [`BO-Marchands.dc.html`](canvas/BO-Marchands.dc.html) | [aperçu](apercus/BO-Marchands.png) |
| Catalogue | [`BO-Catalogue.dc.html`](canvas/BO-Catalogue.dc.html) | [aperçu](apercus/BO-Catalogue.png) |
| Anomalies et dossiers · P1 | [`BO-Anomalies.dc.html`](canvas/BO-Anomalies.dc.html) | [aperçu](apercus/BO-Anomalies.png) |
| Litiges et support · P1 | [`BO-Litiges.dc.html`](canvas/BO-Litiges.dc.html) | [aperçu](apercus/BO-Litiges.png) |

### Wireframes (niveaux de gris)

| Écran | Source | Aperçu |
|---|---|---|
| C2 · Résultats | [`Resultats.dc.html`](canvas/Resultats.dc.html) | [aperçu](apercus/Resultats.png) |
| C3 · Aucun résultat | [`AucunResultat.dc.html`](canvas/AucunResultat.dc.html) | [aperçu](apercus/AucunResultat.png) |
| C4 · Fiche produit et offres | [`Fiche.dc.html`](canvas/Fiche.dc.html) | [aperçu](apercus/Fiche.png) |
| C5 · Fiabilité d'une offre | [`Fiabilite.dc.html`](canvas/Fiabilite.dc.html) | [aperçu](apercus/Fiabilite.png) |
| C6 · Connexion / inscription | [`Connexion.dc.html`](canvas/Connexion.dc.html) | [aperçu](apercus/Connexion.png) |
| C7 · Profil | [`Profil.dc.html`](canvas/Profil.dc.html) | [aperçu](apercus/Profil.png) |
| M1 · Créer son profil marchand | [`MarchandProfil.dc.html`](canvas/MarchandProfil.dc.html) | [aperçu](apercus/MarchandProfil.png) |
| M2 · Statut de vérification | [`MarchandStatut.dc.html`](canvas/MarchandStatut.dc.html) | [aperçu](apercus/MarchandStatut.png) |
| M3 · Points de vente | [`PointsDeVente.dc.html`](canvas/PointsDeVente.dc.html) | [aperçu](apercus/PointsDeVente.png) |
| M4 · Mes prix | [`MesPrix.dc.html`](canvas/MesPrix.dc.html) | [aperçu](apercus/MesPrix.png) |
| M5 · Publier un prix | [`Publier.dc.html`](canvas/Publier.dc.html) | [aperçu](apercus/Publier.png) |
| M6 · Disponibilité | [`Disponibilite.dc.html`](canvas/Disponibilite.dc.html) | [aperçu](apercus/Disponibilite.png) |
| T1 · Relevé terrain (contributeur) | [`Releve.dc.html`](canvas/Releve.dc.html) | [aperçu](apercus/Releve.png) |

## Design system

Les écrans haute fidélité utilisent le design system Comparo v2.4 (palette P07 : vert `#24834B`, citron `#D7E96B`, turquoise `#29A6A1`, fond `#FAFBF5`, texte `#20392D` ; polices Bricolage Grotesque et Manrope). Les tokens sont dans `canvas/ds/wf/tokens.json` et `tokens.css`.

## Décisions ouvertes

Ces points restent à trancher avant l'intégration :

- Cible tactile : 44 px dans le design system, alors que la règle Android demande 48 dp.
- Offres à égalité au prix le plus bas : une seule étiquette citron ou toutes.
- Graisse 500 pour toutes les légendes (contraste).
- Coût du trajet dans « Ma liste ».
- Icônes et logo définitifs.
- Zone et distance (chantier 27 du backend).
