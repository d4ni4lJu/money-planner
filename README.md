# Money Planner (かんたん家計プラン)

A simple monthly budget app for older adults, in Japanese and English. It finds where you live,
estimates local costs (rent, food, transport…), takes out Japanese or U.S. taxes, and shows how much
you can spend and save each month.

## Made for older users
- One question per screen during setup, with big **Back / Next** buttons and a step counter
- Large text by default, plus a 3-step text size choice (on the first screen and in Settings).
  It also respects the phone's own font-size setting
- **High-contrast** display option, plus light and dark
- Every button is at least 64 dp tall; − / + buttons for numbers instead of fiddly sliders
- Money is shown the familiar way (`42,900円`) with separators added while typing
- Status always uses an icon **and** words (✓ OK / ! A little low / ✕ Too low), never color alone
- Plain language: "After tax: the amount that arrives in your bank" instead of jargon
- Confirmations before anything is deleted; everything is saved automatically on the phone

## Features
- Automatic location (device GPS, coarse) → city or prefecture/state; or search a list in Japanese or English
- Japan: income tax, resident tax, pension, health and employment insurance (2025 rules); 47 prefectures + 29 cities
- U.S.: federal, Social Security/Medicare, state and city taxes; 52 cities + all states
- Turn any tax or category on/off, add your own expenses, change any amount (the rest rebalances)
- Three planning styles: real local prices (default), 50/30/20, save first

## Run it
Install Flutter (3.47 or newer), then:

```bash
flutter pub get
flutter run            # on a connected phone or emulator
flutter test           # 35 unit + widget tests
```

Build for release:

```bash
flutter build apk --release        # Android → build/app/outputs/flutter-apk/app-release.apk
flutter build ios --release        # iPhone (needs a Mac with Xcode)
flutter build web --release        # web version
```

## Code layout
- `lib/logic/`: pure Dart budget engine (taxes, locations, allocation), fully unit tested
- `lib/logic/data.dart`: cost data (generated; index 100 = national average)
- `lib/l10n/strings.dart`: all English and Japanese text
- `lib/ui/`: screens (setup, plan, my details, settings, include) and big-button widgets
- `lib/services/locator.dart`: location + reverse geocoding (free BigDataCloud client API)

Figures are estimates for planning, not financial advice. Cost data is approximate.
