# Protocol Vantage — Déploiement production durci

## Configuration obligatoire

Le service doit démarrer avec `VANTAGE_ENV=production`, `VANTAGE_SESSION_SECRET` généré aléatoirement avec au moins 32 octets, `VANTAGE_ACCESS_TOKEN` long et aléatoire, `VANTAGE_ALLOWED_ORIGINS` limité au domaine public réel et `VANTAGE_PRIORITY_SOURCES_ENABLED=1`. Les chemins `/app/data/vantage.sqlite3`, `/app/data/courses` et `/app/data/backup` doivent pointer vers le disque persistant Render.

L’absence du secret de session ou du token d’accès bloque le service en production. Le mode ouvert n’est autorisé qu’en développement local explicite avec `VANTAGE_ENV=development`.

## Parcours d’analyse autorisé

Le seul parcours de production est `POST /api/analyser-course` avec la date, la réunion et le numéro de course. Les anciens parcours URL et manuel retournent `410 Gone` afin d’empêcher un contournement de la collecte multisource et du garde des trois sources effectives avec couverture minimale de 80 %.

## Stockage et sauvegardes

SQLite génère atomiquement les identifiants des analyses. Les artefacts JSON sont écrits de manière atomique. Les uploads Google Drive produisent un manifeste avec les statuts `UPLOADED`, `SKIPPED_NOT_CONFIGURED` ou `FAILED`. Les données runtime ne doivent pas être copiées dans l’image Docker; elles doivent rester sur le disque persistant ou dans le stockage externe configuré.

## Vérifications avant mise en production

```bash
python3 -m compileall -q .
VANTAGE_ENV=development VANTAGE_PRIORITY_SOURCES_ENABLED=0 python3 audit_run_all_tests.py
python3 /home/ubuntu/vantage_audit/concurrency_storage_audit_after_fix.py
```

Le service doit ensuite être testé avec les secrets Render réellement configurés, les onze sources prioritaires actives, la sonde `/health`, l’export JSON rigide et l’audit post-course avec consensus minimum de deux sources.
