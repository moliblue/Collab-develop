# MVVM architecture verification

## Result

The application follows MVVM at the module boundary, with a few pragmatic UI
exceptions. It is suitable to describe as an MVVM Flutter application.

## Evidence

- **Models:** `lib/data_layer/Models` and feature-specific planner models hold
  domain data without widget dependencies.
- **Views:** `lib/ui_layer/View` owns rendering, navigation surfaces, dialogs,
  and device-facing UI callbacks.
- **ViewModels:** `lib/ui_layer/ViewModel` exposes observable screen state and
  user intents through `ChangeNotifier` classes.
- **Repositories/services:** `lib/data_layer/Repositories`, remote services,
  device services, and planner repositories isolate persistence and APIs.
- **Composition:** `AppViewModel` coordinates module ViewModels, while
  `AppShellView` binds them to the five retained module screens.

## Improvements made in this change

- Heritage eligibility is defined in a Supabase read model and consumed by
  repositories. Views do not decide whether database records are valid.
- Discover, Map, and Plan use the same eligible heritage source, avoiding
  duplicated UI filtering rules.

## Remaining minor exceptions

- Some Views call presentation-oriented plugins such as URL launching, sharing,
  and image picking directly. Moving these behind injectable navigation/share
  services would make unit testing easier, but this does not break the main
  state/data separation.
- Several View files are large. Splitting them into smaller presentational
  widgets would improve maintainability without changing the MVVM design.
