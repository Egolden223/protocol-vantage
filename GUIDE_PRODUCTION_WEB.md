# Guide de production web — Protocol Vantage v1.22.2-test

## 1. Fonctionnement général

La version de production expose une interface web permanente pour le Protocol Vantage. L’utilisateur saisit la date de la course, le numéro de réunion, le numéro de course et, si nécessaire, l’hippodrome. Le serveur effectue la résolution et la collecte multi-source, exécute le pipeline en mode `AUTO_CONTINUE`, conserve le ticket pré-course et permet ensuite de lancer l’audit post-course depuis la même interface.

Colab n’est plus nécessaire pour l’usage quotidien. Il reste recommandé pour les essais historiques walk-forward, la validation de nouvelles versions et les opérations de secours.

## 2. Données conservées

Chaque analyse est enregistrée dans SQLite et dans un dossier d’artefacts JSON. Le répertoire `/app/data` doit donc être monté sur un volume durable de l’hébergeur.

| Élément | Emplacement | Rôle |
|---|---|---|
| Historique | `/app/data/vantage.sqlite3` | Recherche des analyses après redémarrage et entre plusieurs workers |
| Artefacts pré-course | `/app/data/courses/<course>/pre_course/` | Rapport de collecte, registre de preuves, export JSON et ticket freeze |
| Artefacts post-course | `/app/data/courses/<course>/post_course/` | Résultat officiel, audit, causes racines et manifeste |
| Copie externe facultative | `VANTAGE_BACKUP_DIR` | Réplication locale ou sur un volume synchronisé |
| Google Drive facultatif | API Google Drive | Téléversement des exports, preuves et audits |

Les données absentes ne sont pas remplacées par des valeurs inventées. Elles restent `NC`, sont conservées dans `raw_data` et sont signalées dans `data_quality`.

## 3. Variables d’environnement

Créer les variables suivantes sur l’hébergeur. Ne jamais inscrire les secrets dans GitHub ou dans le fichier `Dockerfile`.

```text
PORT=5000
VANTAGE_DB_PATH=/app/data/vantage.sqlite3
VANTAGE_ARTIFACTS_ROOT=/app/data/courses
VANTAGE_BACKUP_DIR=/app/data/backup
VANTAGE_SESSION_SECRET=<chaine-secrete-longue>
VANTAGE_ACCESS_TOKEN=<jeton-d-acces-long>
```

Si Google Drive doit être activé, ajouter également :

```text
GOOGLE_SERVICE_ACCOUNT_JSON=/run/secrets/google-service-account.json
GOOGLE_DRIVE_FOLDER_ID=<identifiant-du-dossier-drive>
```

Le compte de service doit avoir le droit de créer des fichiers dans le dossier Drive choisi. L’application continue de fonctionner si Google Drive est indisponible ; l’échec de synchronisation est journalisé et ne modifie jamais le résultat du moteur Vantage.

## 4. Exécution Docker

Depuis le dossier contenant le projet :

```bash
docker build -t protocol-vantage:production .
docker run -d \
  --name protocol-vantage \
  --restart unless-stopped \
  -p 5000:5000 \
  -v vantage_data:/app/data \
  -e VANTAGE_ACCESS_TOKEN='remplacer-ce-jeton' \
  -e VANTAGE_SESSION_SECRET='remplacer-ce-secret' \
  protocol-vantage:production
```

L’application est alors accessible à `http://localhost:5000`. En production publique, utiliser HTTPS devant le conteneur et ne pas exposer directement le port sans reverse proxy ou équivalent.

La sonde `GET /health` retourne un statut minimal pour vérifier la disponibilité du service. Les routes fonctionnelles sont protégées lorsque `VANTAGE_ACCESS_TOKEN` est défini.

## 5. Parcours utilisateur

Ouvrir l’URL de production, saisir le jeton d’accès, puis utiliser le formulaire **Analyser**. Après l’exécution, le ticket de 8 chevaux, le statut de confiance, l’IFT, les sources consultées et le registre de preuves sont affichés. Le bouton **Export JSON** télécharge le fichier conservé dans les artefacts persistants. Le bouton **Audit post-course** déclenche explicitement la recherche des résultats officiels et calcule la capture du Top 5 en ordre libre, les chevaux manqués, les chevaux du ticket hors Top 5 et les causes racines.

Le pré-course reste gelé pendant l’audit. Le rapport post-course est ajouté séparément et ne modifie pas la prédiction initiale.

## 6. Points à vérifier avant mise en ligne

Vérifier que le volume `/app/data` survit à un redémarrage du conteneur. Vérifier également que `GET /health` répond correctement, que l’accès sans jeton est refusé lorsque `VANTAGE_ACCESS_TOKEN` est défini, qu’une analyse apparaît encore dans `/historique` après redémarrage et que le bouton d’audit retrouve bien l’analyse persistée.

Pour une première mise en ligne, il est recommandé d’exécuter une course historique ou une course déjà terminée en mode walk-forward, de comparer l’export JSON avec celui de Colab, puis seulement de l’utiliser pour les courses futures.

## 7. Déploiement recommandé sur Render

Le dépôt doit contenir `Dockerfile` et `render.yaml` à la racine du service. Dans Render, choisir **New > Blueprint**, connecter le dépôt GitHub et sélectionner le fichier `render.yaml`. Le Blueprint fourni crée un Web Service Docker nommé `protocol-vantage`, utilise le plan `starter`, monte un disque persistant de 1 Go sur `/app/data` et configure la sonde `/health`.

Le plan gratuit Render est adapté aux essais mais ne convient pas à cette production : les services gratuits peuvent être mis en veille et ne disposent pas du disque persistant nécessaire à SQLite et aux rapports. Le plan avec disque persistant est donc requis pour conserver l’historique et les artefacts après redémarrage ou redéploiement. Un seul service et une seule instance doivent être utilisés tant que SQLite est le stockage principal.

Après la création du service, renseigner dans l’onglet **Environment** :

| Variable | Valeur |
|---|---|
| `VANTAGE_ACCESS_TOKEN` | Un jeton privé choisi par l’utilisateur |
| `VANTAGE_SESSION_SECRET` | Valeur générée par Render ou chaîne secrète longue |
| `VANTAGE_DB_PATH` | `/app/data/vantage.sqlite3` |
| `VANTAGE_ARTIFACTS_ROOT` | `/app/data/courses` |
| `VANTAGE_BACKUP_DIR` | `/app/data/backup` |
| `GOOGLE_SERVICE_ACCOUNT_JSON` | Chemin ou contenu JSON du compte de service, si Drive est activé |
| `GOOGLE_DRIVE_FOLDER_ID` | Identifiant du dossier Drive, si Drive est activé |

Une fois le premier déploiement terminé, ouvrir l’URL `https://<nom-du-service>.onrender.com`. La page de connexion demande le `VANTAGE_ACCESS_TOKEN`. Vérifier ensuite `https://<nom-du-service>.onrender.com/health`, puis lancer une course historique de contrôle. Après validation, l’application peut être utilisée sans Colab.

Les déploiements Render peuvent être déclenchés automatiquement par les nouveaux commits du dépôt relié. Avant chaque mise à jour importante du moteur, effectuer un export de sauvegarde et conserver une copie du dossier `/app/data` ou des rapports synchronisés sur Google Drive.

### Références Render

[1]: https://render.com/docs/deploy-flask "Render — Deploy a Flask App"
[2]: https://render.com/docs/disks "Render — Persistent Disks"
[3]: https://render.com/docs/free "Render — Deploy for Free"
[4]: https://render.com/docs/blueprint-spec "Render — Blueprint YAML Reference"

## 8. Collecte multi-source ciblée depuis la page d’accueil

Lorsque la date, la réunion et le numéro de course sont saisis, l’application construit un registre de collecte contenant les onze sources prioritaires dans l’ordre normatif. Chaque entrée indique `url_strategy`, `adapter_method`, `search_parameters`, `identity_required`, `top5_required` et `popup_policy`.

Les sources ne sont pas traitées avec une URL universelle. LeTROT utilise un index calendrier, Geny un index daté d’organisation PMU, Zone-Turf un index de programmes, CanalTurf un index quotidien de découverte, Turf.bzh une URL directe date/réunion/course et les autres sources leur page d’index avec les paramètres de recherche correspondants. Les adaptateurs spécialisés ne valident un lien que si la date, la réunion et le numéro de course sont démontrés dans le contenu.

Pour chaque tentative, le rapport conserve l’URL demandée, l’URL finale après redirection, la liste des redirections, le code HTTP, le type de contenu, le nombre d’octets, le nombre de lignes extraites et les preuves d’identité. Les scripts, iframes, conteneurs d’annonces, overlays, popups et bandeaux de consentement connus sont retirés uniquement de la copie HTML utilisée pour l’extraction ; la page brute n’est pas transformée en donnée observée.

Une source qui exige une interaction JavaScript, un clic sur une fenêtre, un CAPTCHA ou qui renvoie un blocage reçoit le statut `BLOCKED` ou `UNPROVEN`. Elle ne contribue ni au Top 5 ni au ticket tant que l’identité et l’extraction ne sont pas prouvées. Cette politique évite de confondre une page accessible avec une donnée fiable et respecte la règle « absence = NC/UNPROVEN ».
