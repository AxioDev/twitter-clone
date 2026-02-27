# Twitter Clone — CLAUDE.md

## Stack
- Flutter + Supabase | Riverpod (codegen) | go_router
- Supabase: `http://88.198.120.138:54321` (Hetzner VPS)
- Signing: Apple Distribution: Thibault BARILLET (J9KLFLQ7FL)
- Bundle ID: `com.twitterclone.twitterClone`

## Commands
- `dart run build_runner build --delete-conflicting-outputs` — regénérer après tout changement de provider
- `supabase db reset` — réinitialiser DB + seed avant les tests
- `flutter test --concurrency=1` — tests intégration (toujours séquentiels)
- `./scripts/deploy.sh <version> [message] [--production]` — build + TestFlight upload

## Deploy
- Fastlane gère uniquement l'upload (pas le build)
- Flutter build ipa d'abord, fastlane upload ensuite
- Secrets dans `~/.twitter-clone-ci/.env` (ASC_KEY_ID=P7PBZS8Z4K, pas WEMZTTQYT437)
- La clé API App Store Connect qui marche: `P7PBZS8Z4K` (partagée avec fogofcity)

## Architecture
- Repositories: `SupabaseClient?` optionnel pour injection de test
- Uploads: toujours `Uint8List` + `uploadBinary()` — jamais `dart:io File` (casse Flutter Web)
- Erreurs async: try/catch + SnackBar (`_handleAction()` pattern)
- Navigation retour: `await context.push(...)` puis `ref.invalidate(provider)`
- Erreurs UI: toujours `AppErrorWidget(onRetry:)` jamais `Text(error)`

## Pièges connus
- `pumpAndSettle` timeout avec `CircularProgressIndicator` permanent dans les listes
- RLS DELETE/UPDATE silencieux (0 rows, pas d'exception)
- Notification trigger: stocke `reply.id` comme `post_id`, pas le post parent
- `tearDownAll` ne doit pas supprimer les relations seed data
- Keychain `ci_signing_test` contient la clé privée Apple Distribution — NE PAS le retirer de la liste de recherche
- Pour déverrouiller `ci_signing_test`: `security unlock-keychain -p ci_temp_password ~/Library/Keychains/ci_signing_test.keychain-db`
- Le deploy script gère ça automatiquement

## Infra Hetzner
- Serveur: CX23 (2c/4GB) — `88.198.120.138` — SSH: `ssh -i ~/.ssh/hetzner_supabase root@88.198.120.138`
- Supabase démarré avec: `cd /root/twitter-clone && npx supabase start`
- Hetzner API key dans `~/.twitter-clone-ci/` (ne pas commit)

## Users seed (password: password123)
- alice a1111111, bob b2222222, carol c3333333, dave d4444444
- emma e5555555, frank f6666666, grace a7777777, henry b8888888
- Henry suit: alice/bob/dave/emma/frank/grace (PAS carol)
