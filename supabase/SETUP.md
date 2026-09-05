# Supabase collaborative planner setup

1. Sign in at `https://supabase.com/dashboard` and open project `iluktwtwmkzlifasqngd`.
2. Open **SQL Editor**, create a query, paste all of `collaborative_planner_schema.sql`, and select **Run**.
3. Open **Authentication > Providers > Anonymous Sign-Ins** and enable it for development, or connect the app to your existing email login. Planner writes require an authenticated user access token; the publishable key alone is not a user session.
4. Confirm `travel_plans`, `plan_days`, `itinerary_cards`, and `plan_members` in **Table Editor**.
5. Run `verify_collaborative_planner.sql`; all rows should show `ready = true`.

Never place the database password in Flutter code or committed files. Rotate a database password after sharing it.

## Current application connection

Project URL: `https://iluktwtwmkzlifasqngd.supabase.co`

The Flutter application receives the project URL and publishable key through
`--dart-define`; no database password is required by the application.

## Moving existing rows

Run the schema first. Do not copy `travel_plans` rows before their referenced
`auth.users` identities exist in the destination project. Supabase Auth users
are project-specific. For anonymous development data, start the app against the
new project and create a fresh plan. For permanent user data, migrate Auth users
first, followed by `travel_plans`, `plan_days`, `itinerary_cards`, and finally
`plan_members`.
