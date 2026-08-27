# Protocol Vantage — bundle de déploiement Render

Ce dossier est une version compacte destinée à l’envoi web dans GitHub lorsque l’interface limite le nombre de fichiers. Le code d’exécution complet est regroupé dans `app_bundle.tar.gz`; il est extrait automatiquement pendant la construction Docker. Il ne s’agit pas d’une réduction de la logique métier : les moteurs, modules, collecteurs, templates et outils runtime sont présents dans l’archive interne.

Téléverser ces fichiers à la racine d’un dépôt GitHub public temporaire : `Dockerfile`, `render.yaml`, `requirements.txt`, `.env.example`, `app_bundle.tar.gz`, `README.md`, `README_PRODUCTION.md`, `GUIDE_PRODUCTION_WEB.md`, `PRESENTATION_DEPLOIEMENT_PERMANENT.md` et ce README. Le nombre de fichiers à envoyer est inférieur à 100.

Render doit utiliser le `Dockerfile` à la racine. Les secrets sont à renseigner uniquement dans Render : `VANTAGE_ACCESS_TOKEN`, `VANTAGE_ALLOWED_ORIGINS` et, si souhaité, `HF_TOKEN` et `HF_BACKUP_REPO_ID`. Le plan Free n’offre pas de disque persistant ; Hugging Face sert donc uniquement de sauvegarde externe des rapports et la base SQLite locale peut être perdue lors d’un redémarrage.

La calibration GRU est désactivée par défaut. L’archive complète `protocol_vantage_hardened_complete.zip` reste la sauvegarde intégrale comprenant les tests et les preuves d’audit.
