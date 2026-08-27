# Protocol Vantage — Application Cloud Python

## Système de Prédiction Quinté+ PMU

**Version**: v1.22.2-test (Ruleset gelé 22/07/2026)  
**Règles RAH actives**: 281  
**Base empirique**: 58+ courses auditées

---

## Description

Application cloud Python complète implémentant le **Protocol Vantage**, un système de prédiction hippique pour le Quinté+ PMU. L'application exécute un pipeline séquentiel de 12 étapes avec vérification systématique des règles inviolables.

## Architecture

```
protocol_vantage/
├── app.py                      # Application Flask principale (API + Web)
├── engine/
│   ├── models.py               # Modèles de données (Course, Partant, Signal...)
│   ├── scoring.py              # Moteur de scoring (PCH, COMPOSITE, ORDRE_SCORE)
│   └── pipeline.py             # Pipeline séquentiel (12 étapes + 10bis)
├── modules/
│   ├── obligatoires.py         # Modules obligatoires (STAB, H2H, TERRAIN...)
│   ├── supra.py                # Module SUPRA (7 phases) + Chasseur Longshots
│   └── gmov.py                 # Module GMO-V (construction ticket)
├── collectors/
│   └── pmu_collector.py        # Collecte données PMU (API + scraping)
├── templates/
│   ├── index.html              # Dashboard principal
│   ├── nouvelle_analyse.html   # Formulaire de saisie
│   └── historique.html         # Historique des analyses
├── Dockerfile                  # Déploiement Docker
├── requirements.txt            # Dépendances Python
└── README.md                   # Ce fichier
```

## Fonctionnalités Implémentées

### Moteur de Scoring
- **P(LOCK)** / **P(GUERRE)** / **P(STANDARD)** — Signatures MSP v2
- **IIC** (Indice d'Incertitude Course) — TROT uniquement
- **PCH_FINAL** = PCH_brut + GRU + modules
- **COMPOSITE** = score normalisé multi-facteurs
- **PRODUIT_MULT** écrêté [0.65, 1.45] (RAH-153)
- **ORDRE_SCORE** = COMPOSITE × PRODUIT_MULT_écrêté

### Modules Obligatoires
- STAB (Stabilité de performance)
- H2H_GRAPH (Confrontations directes)
- MODULE_TERRAIN_DYN (Adaptation terrain)
- MODULE_DIST_ADAPT (Adaptation distance)
- MPA_CHAMP (Moyenne Places d'Arrivée)
- TANDEM_BONUS (Association driver/entraîneur)
- OVERBET_DETECTOR (Détection surcote)
- MODULE_POIDS (PLAT + HANDICAP)
- MODULE_RECUL (TROT + HANDICAP)
- TACT (TROT, incl. TACT-05 Vincennes)

### Module SUPRA (7 phases)
1. Identification des anomalies
2. Vérification de cohérence
3. S1-MARCHÉ (DELTA_MARCHÉ)
4. S3-PRESSE-DIVERGENCE (détecteur uniquement)
5. Modules différentiels
6. Vérification contraintes
7. Synthèse et décision (max 3 modifications)

### Module GMO-V
- Gain hybride ΔF = 0.55×couverture + 0.45×P_boost
- POTENTIAL_SCORE pour outsiders
- Contraintes style/écurie/tranche dans la boucle gloutonne
- Quotas par signature MSP

### Chasseur de Longshots (8 familles)
- Forme cachée, Terrain spécialiste, Distance favorite
- Driver en forme, Mouvement de cote, Hippodrome favorable
- Repos optimal, Consensus minoritaire

### Profils ADO
- PILIER, RÉGULIER, VALEUR_MORTE
- DISSIMULÉ_LÉGER, DISSIMULÉ_FORT
- FAVORI_UNANIME

### GRU (22 hippodromes)
- Tiers A/B/C avec contribution ajustée
- Tier C = 40% de la valeur (RAH-154)
- Flag GRU_TIER_C_PRUDENCE

## Documentation de déploiement permanent

Le document `PRESENTATION_DEPLOIEMENT_PERMANENT.md` présente l’architecture, le fonctionnement pré-course et post-course, le rapport JSON intégral, la calibration GRU, la persistance et les procédures de déploiement local, Docker, VPS, Render et autres plateformes conteneurisées. `README_PRODUCTION.md` et `GUIDE_PRODUCTION_WEB.md` contiennent les contrôles de production détaillés.

Les scripts `scripts/verify_install.sh`, `scripts/backup_runtime.sh` et `scripts/restore_runtime.sh` permettent respectivement de vérifier l’installation, sauvegarder les données runtime et restaurer une sauvegarde avec confirmation explicite.

## Installation et Lancement

### Prérequis
- Python 3.9+
- pip

### Installation locale

```bash
cd protocol_vantage
pip install -r requirements.txt
python app.py
```

L'application sera accessible sur `http://localhost:5000`

### Déploiement Docker

```bash
docker build -t protocol-vantage .
docker run -p 5000:5000 protocol-vantage
```

### Déploiement Cloud (Railway, Render, Fly.io)

L'application est prête pour le déploiement sur toute plateforme supportant Docker ou Python/Flask :
- **Railway**: `railway deploy`
- **Render**: connecter le repo GitHub
- **Fly.io**: `fly deploy`
- **Heroku**: ajouter un `Procfile` avec `web: gunicorn app:app`

## API REST

| Endpoint | Méthode | Description |
|----------|---------|-------------|
| `/api/programme` | GET | Programme PMU du jour |
| `/api/participants/<date>/<reunion>/<course>` | GET | Participants d'une course |
| `/api/analyser` | POST | Exécuter le Protocol Vantage complet |
| `/api/historique` | GET | Historique des analyses |
| `/api/analyse/<id>` | GET | Détail d'une analyse |
| `/api/export/<id>` | GET | Export JSON (template rigide) |
| `/api/hippodromes` | GET | Liste des 22 hippodromes GRU |
| `/api/sources` | GET | Sources de données configurées |

## Utilisation

1. Accéder à **Nouvelle Analyse**
2. Remplir les informations de la course (hippodrome, discipline, distance, terrain)
3. Saisir chaque partant avec ses données (cote, driver, signaux actifs)
4. Cliquer sur **EXÉCUTER LE PROTOCOL VANTAGE**
5. Visualiser le ticket final (P1-P5 + R1-R2), les scores, et le rapport SUPRA
6. Exporter en JSON pour archivage

## Conformité Protocol Vantage

L'application vérifie automatiquement les 22 règles inviolables et calcule l'IFT (Indice de Fiabilité du Ticket) sur 100. Toute violation est signalée dans le rapport.

## Licence

Usage personnel uniquement. Protocol Vantage © 2026.
