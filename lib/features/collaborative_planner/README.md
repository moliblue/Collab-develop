# Collaborative planner module

This folder owns Amberly's UC401 and UC402 implementation. New planner code must remain inside this feature folder; legacy files under `ui_layer` and `data_layer` are integration points for the shared app shell only.

## Runtime configuration

Supply secrets at build time and never commit service keys:

```text
flutter run --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY --dart-define=GOOGLE_TRANSLATE_API_KEY=YOUR_KEY
```

Apply `supabase/collaborative_planner_schema.sql` in the Supabase SQL editor. It creates planner tables, cascading relationships, row-level security, and a secure join-by-PIN function.

OSM search uses Nominatim with a descriptive user agent and Malaysia filtering. OSRM routing sends longitude/latitude pairs to the route endpoint and decodes its GeoJSON line, distance, and duration. Production traffic should use hosted instances rather than relying on public demo endpoints.

PDF exports are generated on-device. The invite Share button and generated PDF use the operating-system share sheet, allowing contacts and installed social apps to receive them.
