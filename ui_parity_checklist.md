# React → Flutter UI parity checklist

Implementation stays inside the project's original `core`, `data_layer`, `ui_layer`, and `assets` folders and follows MVVM.

## Shared shell

- [x] Explore My header, nested-screen back behavior, profile/settings sheet
- [x] Five-tab bottom navigation with raised Mystery action and LIVE badge
- [x] Context-aware Plan selector/actions
- [x] Reusable cards, chips, sheets, modal titles, empty states, avatars, and toast feedback

## Mystery Journey

- [x] Home hero, Solo/Team selection, editable preferences, and Surprise Me
- [x] Detailed preferences and active-journey resume state
- [x] Group setup, scanning/matching, lobby, host/member readiness, and invite code
- [x] Shake animation plus emulator tap fallback
- [x] Active clue, hints, route reveal/vote, group chat, and check-in
- [x] Verification failure, interrupted/resume, completion, XP, passport handoff

## Discover

- [x] Search, state/category filters, results, bookmarks, and empty state
- [x] Place detail, gallery/content, directions, add-to-plan, reviews
- [x] Recommend-a-spot form with validation and duplicate confirmation

## Map Quest

- [x] Offline Flutter map surface, user radius, markers, category filtering
- [x] Place preview/detail, directions, day-route polyline and numbered stops
- [x] Heritage Memo quest, validation, completion feedback, XP reward

## Collaborative Plan

- [x] Workspace, history, and traveller management sections
- [x] Date tabs, activity add/edit/delete/reorder, conflict resolution
- [x] Saved places/recommendations, create plan, day route, export simulation
- [x] Invite code, roles, online status, member removal, leave confirmation

## Profile and authentication

- [x] Profile dashboard, edit validation, language selection, logout
- [x] Badge filters, locked/unlocked states, detail/share feedback
- [x] Login, registration, password recovery, validation, loading states

## Verification

- [x] `flutter analyze` — no issues
- [x] Six focused widget/responsive tests — all passed
- [x] Android debug build installed and launched on `emulator-5554`
- [x] Emulator first-screen visual smoke check completed at 1080×2400
