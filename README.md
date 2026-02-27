# Twitter Clone

A local-first Twitter clone built with Flutter and Supabase.

## Prerequisites

- Flutter 3.41+ (stable)
- Supabase CLI 2.62+
- Docker (OrbStack or Docker Desktop)

## Setup

1. Start Docker / OrbStack

2. Start Supabase local services:
   ```bash
   supabase start
   ```
   Wait for all Docker containers to start. First run pulls images (~2-3 min).

3. Install Flutter dependencies:
   ```bash
   flutter pub get
   ```

4. Generate code (Freezed models, Riverpod providers):
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

5. Run the app:
   ```bash
   flutter run -d chrome
   ```

## Architecture

```
lib/
  app/              # App entry, theme, router, shell
  core/             # Shared utilities, widgets, exceptions
  features/
    auth/           # Sign in, sign up, auth state
    feed/           # Home timeline with realtime
    post/           # Create post, post detail, likes, reposts
    profile/        # User profiles, follow/unfollow, edit
    search/         # Search users and posts
    notifications/  # Realtime notifications
```

- **State**: Riverpod v3 with code generation
- **Models**: Freezed v3 (immutable, JSON serializable)
- **Routing**: GoRouter with auth redirect
- **Pattern**: Repository pattern (UI never touches Supabase directly)
- **Database**: PostgreSQL via Supabase with RLS policies

## Database

Tables: `users`, `posts`, `likes`, `reposts`, `followers`, `notifications`

Features:
- Row Level Security on all tables
- Denormalized counters with triggers
- Automatic notification generation via triggers
- Feed via RPC function with cursor pagination
- Realtime on posts and notifications

## Useful Commands

```bash
# Reset database (drops and recreates)
supabase db reset

# Open Supabase Studio
open http://127.0.0.1:54323

# Open Mailpit (for auth emails)
open http://127.0.0.1:54324

# Stop Supabase
supabase stop

# Run tests
flutter test

# Analyze code
flutter analyze
```
