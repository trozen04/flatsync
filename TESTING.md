# FlatSync - Testing Guide

## Overview

FlatSync is an offline-first peer-to-peer expense sharing application for 4 predefined users. This guide explains how to test the app's key features, especially the settlement algorithm and WiFi synchronization.

## Architecture

### Clean Architecture Layers

- **Data Layer** (`lib/src/data/`): Isar database, repositories
- **Domain Layer** (`lib/src/domain/`): Business entities and use cases
- **Presentation Layer** (`lib/src/presentation/`): UI screens and state management
- **Services Layer** (`lib/src/services/`): Settlement calculation and P2P sync

### Key Components

#### 1. Settlement Algorithm (`lib/src/services/settlement/settlement_service.dart`)

The core business logic that calculates minimal transactions.

**Algorithm Overview:**

```
1. Calculate total expenses
2. Per-person share = total / 4
3. For each person:
   - Net balance = (amount they paid) - (their share)
   - Positive = they should receive money
   - Negative = they should pay money

4. Minimize transactions:
   - Separate into debtors and creditors
   - Match largest debtor with largest creditor
   - Create settlement until all balanced
```

#### 2. Local Database (`lib/src/data/repositories/isar_service.dart`)

- Uses Isar for offline-first local persistence
- Each device maintains complete copy of all expenses
- Sync-friendly: UUID matching and lastModifiedAt timestamp

#### 3. P2P Sync (`lib/src/services/sync/sync_service.dart`)

- Local HTTP server on port 8765
- UDP discovery on port 9876
- Automatic WiFi detection
- Latest-modification-wins conflict resolution

## Testing Settlement Algorithm

### Manual Testing

#### Test Case 1: Simple Equal Split

```
Setup:
- Bhoopendra pays ₹400
- Anand, Naman, Varun pay ₹0

Expected:
- Total: ₹400
- Per person share: ₹100
- Balances:
  - Bhoopendra: +₹300 (gets money)
  - Anand, Naman, Varun: -₹100 each (owe money)

Expected Settlements:
- Anand → Bhoopendra: ₹100
- Naman → Bhoopendra: ₹100
- Varun → Bhoopendra: ₹100
```

**Test Steps:**

1. Open app
2. Add expense: Bhoopendra paid ₹400
3. Go to Balance screen - verify balances match expected
4. Go to Settlement screen - verify 3 settlements
5. Verify amounts sum correctly

#### Test Case 2: Mixed Payments

```
Setup:
- Bhoopendra: ₹200
- Anand: ₹150
- Naman: ₹100
- Varun: ₹0

Expected:
- Total: ₹450
- Per person share: ₹112.50
- Balances:
  - Bhoopendra: +₹87.50
  - Anand: +₹37.50
  - Naman: -₹12.50
  - Varun: -₹112.50

Expected Settlements (minimized):
- Varun → Bhoopendra: ₹87.50
- Varun → Anand: ₹25
- Naman → Anand: ₹12.50
(Or similar combination that settles all balances)
```

#### Test Case 3: Everyone Paid

```
Setup:
- Bhoopendra: ₹1000
- Anand: ₹1000
- Naman: ₹1000
- Varun: ₹1000

Expected:
- Total: ₹4000
- Per person share: ₹1000
- All balances: ₹0

Expected Settlements:
- None (everyone is settled)
```

### Automated Testing (Unit Tests)

Create `test/settlement_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flatsync/src/data/models/expense_model.dart';
import 'package:flatsync/src/services/settlement/settlement_service.dart';
import 'package:uuid/uuid.dart';

void main() {
  group('Settlement Service Tests', () {

    test('Simple equal split', () {
      final expenses = [
        ExpenseModel(
          uuid: const Uuid().v4(),
          amount: 40000, // ₹400 in paise
          paidBy: UserName.bhoopendra,
          createdAt: DateTime.now(),
          lastModifiedAt: DateTime.now(),
          deviceId: 'test-device',
        ),
      ];

      final balances = SettlementService.calculateBalances(expenses);
      final settlements = SettlementService.calculateSettlements(balances);

      expect(balances.length, 4);
      expect(balances[0].netBalance, 30000); // Bhoopendra gets 300
      expect(balances[1].netBalance, -10000); // Anand owes 100
      expect(balances[2].netBalance, -10000); // Naman owes 100
      expect(balances[3].netBalance, -10000); // Varun owes 100

      expect(settlements.length, 3);
      expect(SettlementService.verifiesBalances(balances, settlements), true);
    });

    test('Mixed payments settle correctly', () {
      final expenses = [
        ExpenseModel(
          uuid: const Uuid().v4(),
          amount: 20000,
          paidBy: UserName.bhoopendra,
          createdAt: DateTime.now(),
          lastModifiedAt: DateTime.now(),
          deviceId: 'device-1',
        ),
        ExpenseModel(
          uuid: const Uuid().v4(),
          amount: 15000,
          paidBy: UserName.anand,
          createdAt: DateTime.now(),
          lastModifiedAt: DateTime.now(),
          deviceId: 'device-2',
        ),
      ];

      final balances = SettlementService.calculateBalances(expenses);
      final settlements = SettlementService.calculateSettlements(balances);

      expect(SettlementService.verifiesBalances(balances, settlements), true);
    });

    test('All settled case', () {
      final expenses = [
        ExpenseModel(
          uuid: const Uuid().v4(),
          amount: 10000,
          paidBy: UserName.bhoopendra,
          createdAt: DateTime.now(),
          lastModifiedAt: DateTime.now(),
          deviceId: 'device-1',
        ),
        ExpenseModel(
          uuid: const Uuid().v4(),
          amount: 10000,
          paidBy: UserName.anand,
          createdAt: DateTime.now(),
          lastModifiedAt: DateTime.now(),
          deviceId: 'device-2',
        ),
        ExpenseModel(
          uuid: const Uuid().v4(),
          amount: 10000,
          paidBy: UserName.naman,
          createdAt: DateTime.now(),
          lastModifiedAt: DateTime.now(),
          deviceId: 'device-3',
        ),
        ExpenseModel(
          uuid: const Uuid().v4(),
          amount: 10000,
          paidBy: UserName.varun,
          createdAt: DateTime.now(),
          lastModifiedAt: DateTime.now(),
          deviceId: 'device-4',
        ),
      ];

      final settlements = SettlementService.calculateSettlements(
        SettlementService.calculateBalances(expenses),
      );

      expect(settlements.length, 0); // No settlements needed
    });
  });
}
```

Run tests:

```bash
flutter test test/settlement_test.dart
```

## Testing WiFi Synchronization

### Testing on Emulators

#### Setup Two Emulators

1. **Start first emulator:**

```bash
flutter emulators --launch Pixel_6_API_32
```

2. **In another terminal, start second emulator:**

```bash
flutter emulators --launch Pixel_6_API_31
```

#### Configure Network (Android Emulator)

Android emulator doesn't support true WiFi sync. For testing purposes:

1. **Setup port forwarding between emulators:**

```bash
adb -s emulator-5554 forward tcp:8765 tcp:8765
```

2. **Connect via HTTP** (emulators see each other via localhost)

#### Test Scenario

**Device 1 (Emulator 1):**

1. Run app: `flutter run -d emulator-5554`
2. Add expense: Bhoopendra ₹500

**Device 2 (Emulator 2):**

1. Run app: `flutter run -d emulator-5555`
2. Do NOT add expense yet
3. Tap "Sync Now" button
4. Should receive Bhoopendra's expense

**Verification:**

- Both devices show Bhoopendra's ₹500 expense
- Balances are identical on both devices
- Settlement is identical on both devices

### Testing on Real Devices

**Requirements:**

- 2 Android/iOS devices on same WiFi network
- Same WiFi SSID

**Test Steps:**

1. **Build on Device 1:**

```bash
flutter build apk
adb install build/app/outputs/apk/release/app-release.apk
```

2. **Build on Device 2:**

```bash
flutter build apk
adb install build/app/outputs/apk/release/app-release.apk
```

3. **Both devices connected to same WiFi**

4. **Device 1:**
   - Open app
   - Add multiple expenses with different users
   - Note timestamp of last sync

5. **Device 2:**
   - Open app
   - Tap "Sync Now"
   - Should download all expenses

6. **Verify:**
   - All expenses match on both devices
   - Settlement is identical
   - Balances are identical

7. **Device 2 adds new expense:**
   - Add: Anand paid ₹300

8. **Device 1:**
   - Tap "Sync Now"
   - Should see the new ₹300 expense from Device 2

### Conflict Resolution Testing

Test that `lastModifiedAt` handles conflicts correctly:

1. **Add expense on Device 1:** Bhoopendra ₹100

2. **Both sync** - Device 2 receives expense

3. **Edit expense on Device 1** (not in UI, manually in code):
   - Change amount to ₹200
   - Update lastModifiedAt to newer timestamp

4. **Device 1 syncs** to Device 2

5. **Verify:** Device 2 shows ₹200 (newer modification wins)

## Performance Testing

### Scalability Test

Add 1000 expenses and measure:

```dart
// In settlement_service_test.dart
test('Performance: 1000 expenses', () {
  final stopwatch = Stopwatch()..start();

  final expenses = List.generate(
    1000,
    (i) => ExpenseModel(
      uuid: const Uuid().v4(),
      amount: Random().nextInt(100000),
      paidBy: UserName.values[i % 4],
      createdAt: DateTime.now(),
      lastModifiedAt: DateTime.now(),
      deviceId: 'device-${i ~/ 250}',
    ),
  );

  SettlementService.calculateBalances(expenses);
  SettlementService.calculateSettlements(
    SettlementService.calculateBalances(expenses),
  );

  stopwatch.stop();

  print('Time to calculate settlements for 1000 expenses: ${stopwatch.elapsedMilliseconds}ms');
  expect(stopwatch.elapsedMilliseconds, lessThan(500)); // Should be < 500ms
});
```

### Database Performance

Test Isar operations:

```dart
test('Database: Bulk insert 1000 expenses', () async {
  final isarService = IsarService();
  final stopwatch = Stopwatch()..start();

  final expenses = List.generate(
    1000,
    (i) => ExpenseModel(...),
  );

  await isarService.batchUpsertExpenses(expenses);
  stopwatch.stop();

  print('Time: ${stopwatch.elapsedMilliseconds}ms');
  expect(stopwatch.elapsedMilliseconds, lessThan(1000));
});
```

## Offline Mode Testing

1. **Enable Airplane Mode** on device (WiFi disabled)
2. **Add expenses** - should work without sync
3. **Verify** they're stored locally
4. **Disable Airplane Mode**
5. **Tap Sync** - should try to sync with peers

## Edge Cases to Test

1. **Odd distribution (non-divisible):**
   - ₹1005 / 4 = ₹251.25 per person
   - Verify remainder is handled

2. **Large amounts:**
   - ₹1,00,00,000 (1 crore rupees)
   - Verify no integer overflow

3. **Rapid rapid additions:**
   - Add 10 expenses in 1 second
   - Verify all are saved correctly

4. **Network interruption during sync:**
   - Start sync and immediately disconnect WiFi
   - App should handle gracefully

## Debugging

### View Local Database

```dart
// In main.dart or debug screen
Future<void> _debugPrintExpenses() async {
  final expenses = await IsarService.instance.getAllExpenses();
  for (final exp in expenses) {
    print('${exp.paidBy.displayName}: ₹${(exp.amount / 100).toStringAsFixed(2)}');
  }
}
```

### Enable Verbose Logging

```bash
flutter run -v
```

### Android Logcat

```bash
adb logcat | grep flutter
```

## Checklist for Production

- [ ] Settlement algorithm produces minimal transactions
- [ ] No money is lost in settlements
- [ ] Sync correctly merges conflicts (latest wins)
- [ ] Offline mode works completely
- [ ] Database persists across app restarts
- [ ] Export to CSV/JSON works
- [ ] Material 3 UI works on light/dark mode
- [ ] App responds smoothly with 100+ expenses
- [ ] All 4 users are available for selection
- [ ] Device ID is unique per device
