# Plan module verification

## Automated checks

Run `flutter test --no-pub` for unit and widget coverage, then build the production web bundle with `flutter build web --release` and the Supabase `--dart-define` values used by the launch script.

Run database authorization tests against a local Supabase stack with `supabase test db`. The test file verifies owner, member, and outsider permissions for plans, date tabs, cards, and deletion.

Run concurrent API CRUD testing with k6:

```powershell
$env:SUPABASE_URL='https://your-project.supabase.co'
$env:SUPABASE_ANON_KEY='your-publishable-key'
k6 run test/load/plan_api_k6.js
```

The load test creates isolated plans, exercises Create/Read/Update/Delete, and removes every test plan. It deliberately does not load-test the public Nominatim or OSRM demonstration services.

## Two-device collaboration acceptance test

1. Open the deployed app in two different browsers or physical phones.
2. Create a plan on device A and join its PIN on device B.
3. Add, edit, reorder, and delete cards on each device. The other device must update without refreshing.
4. Attempt simultaneous edits. One save must succeed; the stale save must report that another device changed the plan, reload, and require a retry.
5. Promote a member, remove a member, and transfer admin before the owner leaves.
6. Refresh both devices. Their authenticated anonymous sessions and plan access must persist.
7. Open a third unrelated session and verify that RLS prevents plan access.

## Routing acceptance test

Use browser Network tools to verify that custom Malaysian locations call Nominatim with `countrycodes=my`, and that every affected consecutive pair calls OSRM using `longitude,latitude`. A successful route requires HTTP 200, `code=Ok`, distance, duration, and GeoJSON geometry. Test nearby places, interstate places, identical coordinates, no-road coordinates, timeouts, reorder, edit, and deletion.
