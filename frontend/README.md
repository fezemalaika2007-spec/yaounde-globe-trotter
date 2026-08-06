# GlobeTrotter Frontend (Flutter)

Cross-platform Flutter client (web / mobile / desktop) for the GlobeTrotter
Yaoundé travel assistant.

## Running the app

```bash
cd frontend
flutter run -d chrome        # web
# or
flutter run                  # connected device / emulator
```

## Running the tests

The frontend uses Flutter's built-in widget/unit test framework. The suite
covers:

- **App launch** (`test/widget_test.dart`)
- **Destination filters & image dedup** (`test/destination_filters_test.dart`) —
  name validation, image URL normalization, gallery dedup.
- **Destination detail screen** (`test/destination_details_screen_test.dart`) —
  gallery dedup, real-name captions, image detail / price display.
- **Recommendations screen** (`test/recommendations_screen_test.dart`) —
  categorized sections (Most Popular / Highly Rated / Recently Added /
  Less Costly) render correctly.

Run the full suite:

```bash
cd frontend
flutter test
```

Run the analyzer:

```bash
flutter analyze
```

## Test command summary

| What                 | Command            |
|----------------------|--------------------|
| Full frontend suite  | `flutter test`     |
| Static analysis      | `flutter analyze`  |

> Part of the permanent app-wide suite. Any change to the destination detail
> view or Recommendations screen must keep these tests green.
</content>
