# Protocol Vantage v1.22.2-test

## Présentation intégrale, déploiement permanent et exploitation multiplateforme

**Version du paquet :** 2026-08-25  
**Type :** application Flask conteneurisable et portable  
**Statut de calibration GRU :** historique conservé ; nouvelles magnitudes en shadow ; activation approuvée désactivée par défaut

> **Avertissement.** Protocol Vantage est un logiciel d’analyse de données hippiques. Il ne garantit aucun résultat, aucun taux de capture ni aucun gain. Les décisions liées aux paris relèvent exclusivement de l’utilisateur et doivent respecter la réglementation applicable.

## 1. Objet de l’application

Protocol Vantage automatise une analyse hippique structurée à partir de l’identification d’une course. L’utilisateur fournit la date, la réunion, le numéro de course et, lorsque cela est nécessaire, l’hippodrome. L’application résout l’identité de la course, orchestre les recherches multi-source, consolide les données observées, applique les règles et modules du protocole, produit les scores individuels, construit le ticket de huit chevaux et conserve un rapport intégral auditable.

Après la course, l’utilisateur peut lancer l’audit post-course depuis la même interface. L’application recherche et compare les résultats officiels, exige un consensus conforme à la politique configurée, calcule la capture du Top 5 en ordre libre par le ticket de huit, identifie les chevaux manqués et les chevaux du ticket hors Top 5, puis produit les causes racines et les diagnostics de score. L’audit post-course n’altère jamais le ticket pré-course gelé.

## 2. Architecture fonctionnelle

| Couche | Responsabilité | Principaux fichiers |
|---|---|---|
| Interface web | Saisie, affichage du ticket, scores, rapports et lancement de l’audit post-course | `templates/`, `static/`, `app.py` |
| API Flask | Routes d’analyse, historique, export intégral et audit post-course | `app.py`, `api/` |
| Résolution et collecte | Identification date/R/C, adaptateurs multi-source, fusion et registre de preuves | `collectors/` |
| Modèles | Course, partants, signaux, modules, règles et métriques | `engine/models.py` |
| Pipeline | Exécution séquentielle, contrôles, scoring, composition et ticket | `engine/pipeline.py` |
| Modules | Normatif, SUPRA, GMO-V, longshots, contraintes, terrain, poids et discipline | `modules/` |
| GRU | Règles hippodrome et discipline, provenance et activation contrôlée | `engine/gru_runtime.py`, `engine/gru_activation.py` |
| Calibration | Qualification d’exports, grille de magnitudes, split temporel et rapport shadow | `engine/gru_calibration.py`, `tools/qualify_gru_dataset.py` |
| Persistance | SQLite, artefacts JSON, gzip et sauvegardes optionnelles | `production_storage.py`, `data/` |

Le service est une application Flask Python. Il peut être exécuté directement avec Gunicorn, dans Docker, avec Docker Compose, sur Render ou sur tout fournisseur acceptant un conteneur OCI ou une application Python WSGI. Les données runtime ne sont pas incorporées dans l’image : elles résident dans `/app/data` ou dans le répertoire équivalent configuré.

## 3. Déroulement pré-course

Le parcours normal est le suivant :

1. l’utilisateur identifie la date, la réunion et la course ;
2. le résolveur vérifie l’identité et les éventuelles ambiguïtés ;
3. l’orchestrateur interroge les sources prioritaires avec leurs stratégies d’URL propres ;
4. les réponses sont nettoyées pour l’extraction, sans transformer les publicités ou les overlays en données ;
5. les champs sont fusionnés dans un tableau consolidé, avec source, valeur, horodatage et statut ;
6. le garde de couverture contrôle le nombre de sources, la couverture et les partants nécessaires ;
7. le pipeline applique les formules, indices, règles, modules et contrôles d’intégrité ;
8. le ticket de huit chevaux est construit et gelé ;
9. le rapport intégral est écrit en JSON, avec téléchargement gzip par défaut.

Une donnée absente reste `NC`, `UNPROVEN` ou `BLOCKED` selon la cause. Elle n’est pas remplacée par une valeur inventée. Les valeurs imputées neutres, lorsqu’elles sont autorisées, sont marquées comme telles dans la qualité des données et ne doivent pas être confondues avec une observation source.

## 4. Score et audit analytique

Le rapport conserve la chaîne de calcul et ses dépendances : `PCH_BRUT`, contribution GRU, contributions des modules, `PCH_FINAL`, normalisation, `COMPOSITE`, multiplicateurs et `ORDRE_SCORE`. Pour chaque partant, l’audit V3 expose les contributions positives et négatives, les modules actifs, les champs manquants, la position dans le classement, le seuil du ticket, les contrefactuels sans rétroaction et la cause probable d’un succès ou d’un échec.

Le contrefactuel « sans GRU » est analytique et non rétroactif. Il ne modifie ni le ticket pré-course ni le rapport original. Il sert à répondre à une question précise : le cheval aurait-il changé de rang ou de statut dans le ticket si la contribution GRU avait été nulle ?

## 5. Calibration GRU contrôlée

Les magnitudes historiques ne sont pas remplacées automatiquement. Les nouvelles règles ou magnitudes sont d’abord évaluées en shadow sur un export réel et complet.

| Famille | Grille candidate en points PCH |
|---|---|
| Structurelle | −12, −10, −8, −6, −5, −4, −3, −2, −1, 0, +1, +2, +3, +4, +5, +6, +8, +10, +12 |
| Locale hippodrome/départ/terrain | −6, −4, −3, −2, −1, 0, +1, +2, +3, +4, +6 |
| Risque disqualification/chute/fragilité | −10, −8, −6, −5, −4, −3, −2, −1, 0 |
| Marché/cote/fluctuation | −6, −4, −3, −2, −1, 0, +1, +2, +3, +4, +6 |

La valeur zéro constitue la baseline. La valeur brute sélectionnée est réduite vers zéro par un shrinkage dépendant du nombre de déclenchements d’apprentissage : `n / (n + 100)`, avec arrondi par pas de 0,5 point. Cette précaution évite qu’une règle rare reçoive une forte amplitude simplement parce qu’elle a déplacé quelques tickets dans l’échantillon d’apprentissage.

Le plan progressif est le suivant :

| Étape | Courses complètes | Train chronologique | Validation hors échantillon | Décision |
|---|---:|---:|---:|---|
| Screening | 120 | 84 | 36 | Shadow uniquement |
| Confirmation | 300 | 210 | 90 | Robustesse statistique |
| Revue finale | 500 | 350 | 150 | Examen avant activation |

Une course est complète uniquement si le dénominateur de partants est vérifié, si tous les partants nécessaires sont présents, si chaque score baseline et rang officiel existe, si le Top 5 est valide et si aucune feature ne possède un timestamp postérieur à la décision. La sélection s’effectue sur le train ; la validation ne sert jamais à choisir la magnitude.

L’activation exige au minimum un gain de rappel Top 5 de 0,02 sur le holdout, aucune perte globale, une stabilité par blocs temporels, au moins 100 déclenchements train, 30 validation, une magnitude dans ±12 et une preuve identifiée. Le replay du pipeline Vantage intégral est obligatoire avant l’éligibilité. Sans replay intégral, le rapport reste `BASE_SCORE_PROXY_SCREENING` et la règle est bloquée.

## 6. Audit post-course et rapport intégral

Chaque analyse peut produire un document intégral unique contenant les données collectées, le registre de preuves, la trace des étapes, les scores, les règles, les modules, le ticket, les diagnostics V3, l’état GRU, l’audit post-course et les métadonnées de sauvegarde. Le fichier est compressé en gzip par défaut et nommé selon la convention :

```text
vantage_rapport_integral_YYYYMMDD_RxCy_DISCIPLINE_HIPPODROME_A{id}.json.gz
```

L’audit post-course conserve la séparation entre :

| Élément | Fonction |
|---|---|
| Ticket pré-course gelé | Référence immuable de la décision initiale |
| Arrivée officielle confirmée | Résultat collecté après la course avec sources et consensus |
| Capture Top 5 | Intersection entre le ticket de huit et le Top 5 officiel |
| Manqués | Chevaux du Top 5 absents du ticket |
| Faux positifs | Chevaux du ticket absents du Top 5 |
| Diagnostic V3 | Explication des scores, contributions et seuils |
| Contrefactuels | Analyse sans modifier l’exécution historique |

## 7. Stockage et persistance

Le répertoire de persistance recommandé est `/app/data`.

| Donnée | Chemin par défaut |
|---|---|
| Base SQLite | `/app/data/vantage.sqlite3` |
| Rapports et preuves | `/app/data/courses/<course>/` |
| Sauvegardes locales | `/app/data/backup/` |
| Copie Google Drive facultative | Compte de service et dossier configurés |

Pour un service permanent, `/app/data` doit être monté sur un disque ou un volume persistant. Sans ce volume, le code peut redémarrer mais l’historique, la base SQLite et les rapports peuvent être perdus lors d’un remplacement de conteneur. Une seule instance est recommandée tant que SQLite reste le stockage principal.

La sauvegarde Google Drive est facultative. Elle ne doit jamais contenir de clé secrète dans Git. Si elle est configurée, l’application journalise le statut `UPLOADED`, `FAILED` ou `SKIPPED_NOT_CONFIGURED` et ne modifie pas le résultat de l’analyse lorsqu’un téléversement échoue.

### Hugging Face comme persistance externe

Le disque local fourni à un Space Hugging Face est éphémère. La documentation Hugging Face indique qu’un Storage Bucket peut être attaché comme volume, avec montage en lecture-écriture ou lecture seule [1]. Les Storage Buckets sont un stockage objet mutable de type S3, adapté aux logs et artefacts, mais ils ne doivent pas être assimilés automatiquement à un volume SQLite local cohérent [2].

L’architecture retenue pour Protocol Vantage est donc prudente : la base SQLite active et les rapports récemment produits restent sur le volume persistant du fournisseur qui exécute l’application ; Hugging Face sert de **destination de sauvegarde externe facultative** pour les rapports JSON gzip, audits, manifestes et snapshots arrêtés proprement. Le code ne dépend pas d’un accès Hugging Face à chaque requête et une indisponibilité distante ne bloque pas l’analyse.

Pour activer cette sauvegarde, définir `HF_TOKEN`, `HF_BACKUP_REPO_ID`, `HF_BACKUP_REPO_TYPE=dataset` et, si nécessaire, `HF_BACKUP_CREATE_REPO=1`. Le dépôt doit être privé et le jeton doit rester dans les secrets de l’hébergeur. La configuration ne transforme pas un dépôt Hugging Face en disque SQLite actif ; elle réplique les artefacts vers un dépôt privé. L’utilisation d’un Storage Bucket monté en volume nécessite en plus de vérifier le compte, les droits, la capacité et la configuration de montage auprès de Hugging Face.

## 8. Déploiement local ou VPS avec Docker

Depuis la racine de l’archive :

```bash
cp .env.example .env
# Modifier au minimum VANTAGE_SESSION_SECRET,
# VANTAGE_ACCESS_TOKEN et VANTAGE_ALLOWED_ORIGINS.
docker compose -f docker-compose.production.yml up -d --build
curl http://localhost:5000/health
```

Pour un lancement sans Compose :

```bash
docker build -t protocol-vantage:production .
docker volume create vantage_data
docker run -d --name protocol-vantage --restart unless-stopped \
  -p 5000:5000 \
  -v vantage_data:/app/data \
  --env-file .env \
  protocol-vantage:production
```

Sur un VPS public, placer un reverse proxy HTTPS devant le conteneur, limiter l’accès réseau au port du proxy et conserver le secret d’accès hors du dépôt. Le fichier `Dockerfile` écoute sur `0.0.0.0` et respecte la variable `PORT` du fournisseur.

## 9. Déploiement Render

Le fichier `render.yaml` décrit un Web Service Docker avec la sonde `/health`, les chemins de stockage et un disque persistant. Le service doit être configuré avec au minimum `VANTAGE_ENV=production`, `VANTAGE_SESSION_SECRET`, `VANTAGE_ACCESS_TOKEN`, `VANTAGE_ALLOWED_ORIGINS`, `VANTAGE_DB_PATH`, `VANTAGE_ARTIFACTS_ROOT` et `VANTAGE_BACKUP_DIR`.

Le plan gratuit peut convenir à un essai mais ne doit pas être présenté comme une garantie de disponibilité permanente ni de persistance. Pour une exploitation durable, choisir une offre permettant le disque persistant et vérifier la politique de sommeil, de redéploiement et de sauvegarde du fournisseur.

## 10. Déploiement sur d’autres plateformes

| Plateforme | Méthode | Persistance à prévoir |
|---|---|---|
| Railway, Fly.io ou équivalent | Déployer l’image Docker et fournir les variables d’environnement | Volume persistant ou stockage externe |
| Cloud Run ou service conteneur stateless | Déployer l’image avec stockage externe pour SQLite/artefacts | Ne pas compter sur le disque local éphémère |
| VPS Linux | Docker Compose avec `restart: unless-stopped` et reverse proxy HTTPS | Volume Docker ou montage disque |
| Ordinateur local | Python/Gunicorn ou Docker Compose | Sauvegarde régulière du dossier `data` |
| Google Colab | Exécution ponctuelle et sauvegarde Drive | Non adapté à un service permanent sans orchestration externe |

Le paquet reste indépendant du fournisseur. Les éléments spécifiques à Render sont isolés dans `render.yaml`, ceux de Docker Compose dans `docker-compose.production.yml`, et le démarrage WSGI est également fourni par `Procfile`.

## 11. Variables d’environnement

| Variable | Obligatoire en production | Exemple |
|---|---|---|
| `PORT` | Oui selon le fournisseur | `5000` |
| `VANTAGE_ENV` | Oui | `production` |
| `VANTAGE_SESSION_SECRET` | Oui, secret long | valeur générée hors Git |
| `VANTAGE_ACCESS_TOKEN` | Oui | jeton privé long |
| `VANTAGE_ALLOWED_ORIGINS` | Oui | domaine HTTPS exact |
| `VANTAGE_DB_PATH` | Oui | `/app/data/vantage.sqlite3` |
| `VANTAGE_ARTIFACTS_ROOT` | Oui | `/app/data/courses` |
| `VANTAGE_BACKUP_DIR` | Recommandé | `/app/data/backup` |
| `VANTAGE_PRIORITY_SOURCES_ENABLED` | Oui pour la collecte | `1` |
| `GRU_CALIBRATION_ACTIVATION` | Non ; `0` par défaut | `0` |
| `GRU_CALIBRATION_PATCH_PATH` | Seulement avec patch approuvé | chemin hors Git |
| `GOOGLE_SERVICE_ACCOUNT_JSON` | Facultatif | chemin secret monté |
| `GOOGLE_DRIVE_FOLDER_ID` | Facultatif avec Drive | identifiant du dossier |

## 12. Sécurité et exploitation

En production, les secrets et origines autorisées doivent être explicitement définis. Les requêtes sont plafonnées, les headers de sécurité sont activés et les routes de production ne doivent pas être rendues publiques sans contrôle d’accès. Les logs peuvent contenir des identifiants techniques mais ne doivent pas contenir les secrets.

Avant chaque mise à jour importante, sauvegarder la base et les artefacts, vérifier le hash de l’archive ou de l’image, exécuter la suite de tests et réaliser une analyse historique contrôlée. Après déploiement, contrôler `/health`, l’accès avec et sans jeton, la création d’une analyse, la persistance après redémarrage et le téléchargement du rapport intégral.

## 13. Contenu de l’archive

L’archive contient le code complet, les templates, les adaptateurs de collecte, les modules normatifs, le moteur de scoring, le stockage, les scripts de test, les fichiers Docker/Compose/Render/Procfile, l’exemple d’environnement, les outils de qualification GRU, les documents maître et guide disponibles, les preuves d’audit et les documents de production. Les données runtime, secrets, bases SQLite et fichiers de sauvegarde ne sont volontairement pas inclus.

## 14. Vérification finale

```bash
python3 -m py_compile app.py engine/*.py modules/*.py collectors/*.py tools/*.py
VANTAGE_ENV=development VANTAGE_PRIORITY_SOURCES_ENABLED=0 python3 audit_run_all_tests.py
python3 tools/qualify_gru_dataset.py historique.json --output qualification.json
unzip -tq protocol_vantage_hardened_complete.zip
curl http://localhost:5000/health
```

La qualification GRU ne doit être exécutée qu’avec un export réel et légal. Aucun jeu de données simulé ne doit être utilisé pour créer un patch de production. L’état par défaut reste désactivé tant qu’une preuve hors échantillon complète n’a pas été revue.

## 15. Références opérationnelles

[1]: https://huggingface.co/docs/hub/en/spaces-storage "Hugging Face — Disk usage on Spaces"

[2]: https://huggingface.co/docs/hub/en/storage-buckets "Hugging Face — Storage Buckets"

Le paquet comprend également `README.md`, `README_PRODUCTION.md`, `GUIDE_PRODUCTION_WEB.md`, le rapport d’implémentation de calibration GRU, le plan de test des magnitudes et les rapports d’audit. Ces documents doivent être lus avant la première mise en production.
