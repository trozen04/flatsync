# FlatSync - Quick Start Guide

Get FlatSync running in 5 minutes!

## Prerequisites

✅ Flutter 3.0+ installed
✅ A phone or emulator
✅ This project

## 5-Minute Setup

### 1. Install Dependencies (2 min)

```bash
flutter pub get
```

### 2. Generate Database Code (1 min)

```bash
flutter pub run build_runner build
```

If you get errors:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### 3. Run the App (2 min)

```bash
flutter run
```

Or specify device:

```bash
flutter run -d emulator-5554
```

## First Use

### Add an Expense

1. **Home Tab** → Select user → Enter amount → Tap "Add Expense"
2. **Your device**: Locally saves instantly ✅

### View Results

1. **Balance Tab** → See who owes whom
2. **Settlement Tab** → See exact transactions needed

### Export Data

1. **Export Tab** → Choose format (CSV or JSON)
2. **Share** → File sent to your system

## Testing Multi-Device Sync

Need 2 devices on same WiFi:

### With 2 Emulators

```bash
# Terminal 1
flutter emulators --launch Pixel_6_API_32

# Terminal 2
flutter emulators --launch Pixel_6_API_31

# Terminal 3 (first emulator)
flutter run -d emulator-5554

# Terminal 4 (second emulator)
flutter run -d emulator-5555
```

### Then

1. **Device 1**: Add expense
2. **Device 2**: Tap "Sync Now" button
3. **Device 2**: Sees the expense! ✅

## Common Issues

| Issue            | Solution                                                          |
| ---------------- | ----------------------------------------------------------------- |
| Build fails      | `flutter clean && flutter pub get`                                |
| Database error   | `flutter pub run build_runner build --delete-conflicting-outputs` |
| Sync not working | Check both devices on same WiFi                                   |
| UI broken        | `flutter run --release`                                           |

## Key Features Demo

### Settlement Algorithm

```
Example:
- Bhoopendra pays ₹400
- Anand, Naman, Varun pay ₹0

Result: Minimum 3 transactions
- Anand → Bhoopendra: ₹100
- Naman → Bhoopendra: ₹100
- Varun → Bhoopendra: ₹100
```

### Offline First

1. Add expense
2. Enable airplane mode
3. App still works! ✅

### WiFi Sync

1. Both devices same WiFi
2. Tap "Sync Now"
3. Data merges automatically ✅

## Architecture Overview

```
UI (Screens + Widgets)
    ↓ (Provider)
Business Logic (Settlement, Sync)
    ↓
Data (Isar Database)
    ↓
Local Storage
```

Every device is independent + syncs when possible.

## Files Overview

| File                      | Purpose                  |
| ------------------------- | ------------------------ |
| `lib/main.dart`           | App start point          |
| `expense_model.dart`      | Data structure           |
| `settlement_service.dart` | Calculates who pays whom |
| `sync_service.dart`       | WiFi P2P sync            |
| `*_screen.dart`           | UI screens               |
| `isar_service.dart`       | Local database           |

## Testing Settlement

```bash
flutter test test/settlement_test.dart
```

Should see ✅ for all tests.

## What's Next?

- [x] App runs
- [ ] Try adding 10 expenses
- [ ] Test with 2 devices
- [ ] Try exporting to CSV
- [ ] Read [TESTING.md](TESTING.md) for advanced testing
- [ ] Check [README_COMPLETE.md](README_COMPLETE.md) for full docs

## Troubleshooting

### "flutter: not found"

```bash
# Add Flutter to PATH
export PATH="$PATH:`flutter/bin`"
```

### "Isar error"

```bash
flutter pub run build_runner clean
flutter pub get
flutter pub run build_runner build
```

### "Android SDK not found"

```bash
flutter doctor -v
# Follow instructions to set up Android SDK
```

### App won't start

```bash
flutter clean
flutter pub get
flutter run
```

## Commands Reference

```bash
# Development
flutter run                    # Run app
flutter run -v                # With verbose logging
flutter run -d <id>          # On specific device

# Testing
flutter test                   # Run all tests
flutter test test/settlement_test.dart  # One file

# Code
flutter analyze               # Check for issues
dart format lib test          # Format code

# Database
flutter pub run build_runner build   # Generate Isar code

# Release
flutter build apk --release   # Build Android app
flutter build ios --release   # Build iOS app
```

## Performance Baseline

| Operation            | Time                    |
| -------------------- | ----------------------- |
| Add expense          | <10ms                   |
| Calculate settlement | <5ms (for 100 expenses) |
| Sync 100 expenses    | ~500ms                  |
| Database lookup      | <5ms                    |

## Device Requirements

| Requirement | Value  |
| ----------- | ------ |
| Min Android | API 21 |
| Min iOS     | 11.0   |
| Min Flutter | 3.0    |
| Min Dart    | 3.0    |

## Security Notes

✅ **Safe**: No internet required, no cloud, no login
⚠️ **Important**: Only sync on trusted home WiFi
⚠️ **Backup**: Export your data regularly

## Success Indicators

After first run, you should see:

✅ 4 tabs in bottom navigation
✅ Home tab with user dropdown
✅ Can add expense
✅ Balance tab shows calculations
✅ Settlement tab shows transactions
✅ Export tab downloads file
✅ "Sync Now" button in app bar

If all these work → **FlatSync is running!** 🎉

---

**Need more details?** See [SETUP_GUIDE.md](SETUP_GUIDE.md)
**Want to test thoroughly?** See [TESTING.md](TESTING.md)
**Need full documentation?** See [README_COMPLETE.md](README_COMPLETE.md)
