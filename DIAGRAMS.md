# FlatSync - System Diagrams & Flow Charts

## 1. High-Level System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     FlatSync Application                     │
│                    (Flutter + Material 3)                    │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │         User Interface Layer                         │   │
│  │  ┌─────────┬─────────┬─────────────┬──────────┐     │   │
│  │  │  Home   │ Balance │ Settlement  │ Export   │     │   │
│  │  │  (Add)  │ (View)  │   (Show)    │ (CSV/JSON)     │   │
│  │  └─────────┴─────────┴─────────────┴──────────┘     │   │
│  └──────────────────────────────────────────────────────┘   │
│                          ↓                                   │
│  ┌──────────────────────────────────────────────────────┐   │
│  │      State Management (Provider)                     │   │
│  │  ┌──────────────┬──────────────┬─────────────────┐  │   │
│  │  │   Expense    │   Balance    │  Sync Provider  │  │   │
│  │  │  Provider    │  Provider    │                 │  │   │
│  │  └──────────────┴──────────────┴─────────────────┘  │   │
│  └──────────────────────────────────────────────────────┘   │
│                          ↓                                   │
│  ┌──────────────────────────────────────────────────────┐   │
│  │    Business Logic & Services                         │   │
│  │  ┌──────────────────┬───────────────────────┐       │   │
│  │  │ Settlement       │ Sync Service          │       │   │
│  │  │ Service          │ (WiFi P2P)            │       │   │
│  │  │ (Algorithm)      │                       │       │   │
│  │  └──────────────────┴───────────────────────┘       │   │
│  └──────────────────────────────────────────────────────┘   │
│                          ↓                                   │
│  ┌──────────────────────────────────────────────────────┐   │
│  │    Repository Layer                                  │   │
│  │  ┌──────────────────────────────────────────────┐   │   │
│  │  │    Expense Repository                         │   │   │
│  │  └──────────────────────────────────────────────┘   │   │
│  └──────────────────────────────────────────────────────┘   │
│                          ↓                                   │
│  ┌──────────────────────────────────────────────────────┐   │
│  │    Data Access Layer (Isar Service)                  │   │
│  │  ┌──────────────────────────────────────────────┐   │   │
│  │  │   Database Operations (CRUD)                 │   │   │
│  │  └──────────────────────────────────────────────┘   │   │
│  └──────────────────────────────────────────────────────┘   │
│                          ↓                                   │
│  ┌──────────────────────────────────────────────────────┐   │
│  │    Isar Local Database                               │   │
│  │  ┌──────────────────────────────────────────────┐   │   │
│  │  │    Expenses Collection (with indexes)        │   │   │
│  │  │    ├─ UUID (unique)                          │   │   │
│  │  │    ├─ lastModifiedAt (for sync)              │   │   │
│  │  │    └─ syncedAt (tracking)                    │   │   │
│  │  └──────────────────────────────────────────────┘   │   │
│  └──────────────────────────────────────────────────────┘   │
│                          ↓                                   │
│  ┌──────────────────────────────────────────────────────┐   │
│  │    Device Local Storage                              │   │
│  │  ┌──────────────────────────────────────────────┐   │   │
│  │  │    SQLite Database (Isar backend)            │   │   │
│  │  └──────────────────────────────────────────────┘   │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                               │
└─────────────────────────────────────────────────────────────┘
                              ↕
                        Local WiFi
                     (192.168.x.x)
                              ↕
            ┌──────────────────────────────────────┐
            │    Peer Device 2 (Same structure)    │
            │                                      │
            │  ┌────────────────────────────────┐ │
            │  │  Isar Database (full copy)     │ │
            │  └────────────────────────────────┘ │
            │                                      │
            └──────────────────────────────────────┘
```

## 2. Data Flow Diagram: Adding an Expense

```
User taps "Add Expense"
        ↓
┌──────────────────────────────────────┐
│ HomeScreen (UI)                      │
│ - User: Bhoopendra                   │
│ - Amount: ₹500                       │
│ - Description: "Pizza"               │
└──────────────────────────────────────┘
        ↓
    [Call]
        ↓
┌──────────────────────────────────────┐
│ ExpenseProvider.addExpense()         │
│ 1. Generate UUID                     │
│ 2. Create ExpenseModel               │
│ 3. Set deviceId, timestamps          │
└──────────────────────────────────────┘
        ↓
    [Call]
        ↓
┌──────────────────────────────────────┐
│ ExpenseRepository.addExpense()       │
│ (Delegates to IsarService)           │
└──────────────────────────────────────┘
        ↓
    [Call]
        ↓
┌──────────────────────────────────────┐
│ IsarService.addExpense()             │
│ - Run Isar transaction               │
│ - Insert into database               │
└──────────────────────────────────────┘
        ↓
    [Success]
        ↓
┌──────────────────────────────────────┐
│ Expense stored in local database     │
│ - UUID: "a1b2c3d4..."               │
│ - Amount: 50000 (₹500 in paise)      │
│ - DeviceId: "device-xyz"             │
└──────────────────────────────────────┘
        ↓
    [Event]
        ↓
┌──────────────────────────────────────┐
│ ExpenseProvider.notifyListeners()    │
│ (Tell all listeners about change)    │
└──────────────────────────────────────┘
        ↓
    [React]
        ↓
┌──────────────────────────────────────┐
│ UI rebuilds:                         │
│ - HomeScreen updates list            │
│ - BalanceProvider recalculates       │
│ - SettlementScreen updates           │
│ - Show success snackbar              │
└──────────────────────────────────────┘
```

## 3. Settlement Calculation Flow

```
Input: List<ExpenseModel> (all expenses)
       ├─ Bhoopendra: ₹500
       ├─ Anand: ₹0
       ├─ Naman: ₹0
       └─ Varun: ₹0
        ↓
┌──────────────────────────────────────┐
│ SettlementService.calculateBalances()│
│ 1. Total = ₹500                      │
│ 2. Per person share = ₹125           │
│ 3. Calculate net for each:           │
│    - Bhoopendra: 500 - 125 = +375   │
│    - Anand: 0 - 125 = -125          │
│    - Naman: 0 - 125 = -125          │
│    - Varun: 0 - 125 = -125          │
└──────────────────────────────────────┘
        ↓
Output: List<UserBalance>
       ├─ Bhoopendra: +₹375 (receives)
       ├─ Anand: -₹125 (owes)
       ├─ Naman: -₹125 (owes)
       └─ Varun: -₹125 (owes)
        ↓
┌──────────────────────────────────────┐
│ SettlementService.calculateSettlements│
│ 1. Debtors: [Anand, Naman, Varun]   │
│    (all owe ₹125)                    │
│ 2. Creditors: [Bhoopendra]           │
│    (receives ₹375)                   │
│ 3. Greedy matching:                  │
│    - Anand → Bhoopendra: ₹125        │
│    - Naman → Bhoopendra: ₹125        │
│    - Varun → Bhoopendra: ₹125        │
└──────────────────────────────────────┘
        ↓
Output: List<Settlement>
       ├─ Anand → Bhoopendra: ₹125
       ├─ Naman → Bhoopendra: ₹125
       └─ Varun → Bhoopendra: ₹125
        ↓
┌──────────────────────────────────────┐
│ UI displays settlements              │
│ "Who pays whom and how much"         │
└──────────────────────────────────────┘
```

## 4. Peer-to-Peer Sync Flow

```
Device A                           Device B (WiFi same network)
(localhost:8765)                   (localhost:8765)
        │                                   │
        │                                   │
        │                                   │
        │   User taps "Sync Now"            │
        │   ──────────────────>             │
        │                                   │
        │                              [Start Sync]
        │                                   │
        │                          [Scan 192.168.1.x]
        │                                   │
        │<──────  UDP Discovery Broadcast   │
        │     "Anyone here? I'm Device B"   │
        │                                   │
        │        [Response]                 │
        │        "I'm Device A at port 8765"
        │────────────────────>              │
        │                                   │
        │                          [Connect to A:8765]
        │                                   │
        │     HTTP GET /expenses            │
        │<──────────────────────────────────│
        │                                   │
        │  [Return all expenses as JSON]   │
        │────────────────────────────────>  │
        │                                   │
        │                          [Merge with local]
        │                          [Conflict resolution]
        │                                   │
        │     HTTP POST /sync               │
        │<──────────────────────────────────│
        │        [Send B's expenses]        │
        │                                   │
        │  [Merge B's expenses]             │
        │  [Update local database]          │
        │                                   │
        │           {success}               │
        │────────────────────────────────>  │
        │                                   │
        │         [Sync Complete]           │
        │  UI updates with merged data      │
        │                                   │
```

## 5. Conflict Resolution Strategy

```
Remote Expense (from other device):
{
  uuid: "abc123",
  amount: 50000,
  lastModifiedAt: "2026-01-27T15:00:00Z",
  ...
}
        ↓
┌─────────────────────────────────────┐
│ Check local database by UUID        │
└─────────────────────────────────────┘
        ↓
    Does it exist?
        ├─ NO → Insert as new ✓
        │
        └─ YES → Compare timestamps
             ├─ remote.lastModifiedAt > local?
             │  ├─ YES → Update with remote ✓
             │  │
             │  └─ NO → Keep local ✓
             │
             └─ Result: No data loss, fairest resolution
```

## 6. Database Structure

```
Isar Database (Local Device)
│
└─ ExpenseModel Collection
    ├─ [Index] id (Isar ID)
    ├─ [Index] uuid (unique, global)
    ├─ [Index] lastModifiedAt (for sync)
    ├─ [Index] syncedAt (tracking)
    │
    └─ Documents:
        ├─ {
        │    id: 1,
        │    uuid: "a1b2c3d4-e5f6...",
        │    amount: 50000,                 (₹500)
        │    paidBy: "bhoopendra",
        │    createdAt: 2026-01-27T...,
        │    lastModifiedAt: 2026-01-27T...,
        │    deviceId: "android-device-1",
        │    description: "Lunch",
        │    syncedAt: 2026-01-27T...
        │  }
        │
        ├─ {
        │    id: 2,
        │    uuid: "b2c3d4e5-f6g7...",
        │    ...
        │  }
        │
        └─ ...
```

## 7. User Interaction Flow

```
                    FlatSync App
                        │
        ┌───────┬───────┼───────┬───────┐
        │       │       │       │       │
        ↓       ↓       ↓       ↓       ↓
      Home   Balance Settlement Export Sync
     (Add)   (View)   (Show)   (CSV/JSON)
       │       │       │       │       │
       ├─────->│       │       │       │
       │   [Recalc]    │       │       │
       │       ├─────->│       │       │
       │       │   [Update]   │       │
       │       │       ├─────->│       │
       │       │       │  [Show] │      │
       │       │       │       │       │
       │       │       │       ├─────->│
       │       │       │       │   [Export]
       │       │       │       │    [Share]
       │       │       │       │
       └─────────────────────────────->│
                                    [Sync]
                                     [WiFi]
```

## 8. State Diagram

```
┌─────────────────────┐
│  App Started        │
│ (Initialize)        │
└──────────┬──────────┘
           │
           ├─> IsarService.initialize()
           │
           ├─> SyncService.initialize()
           │      ├─> Generate device ID
           │      └─> Start HTTP server
           │
           ├─> ExpenseProvider.loadExpenses()
           │      └─> Load from database
           │
           └─> BalanceProvider ready
                  └─> Waiting for expense changes
                       │
                       ├─ User adds expense
                       │  ├─> ExpenseProvider updates
                       │  ├─> BalanceProvider recalculates
                       │  └─> UI refreshes
                       │
                       ├─ User taps Sync
                       │  ├─> SyncService scans network
                       │  ├─> HTTP exchange with peers
                       │  ├─> Merge with conflict resolution
                       │  ├─> Update local database
                       │  └─> UI refreshes
                       │
                       └─ User exports data
                          ├─> CSV or JSON format
                          └─> Share file
```

## 9. Settlement Algorithm Visualization

```
Input: 4 Users with balances
┌─────────────────────────────────┐
│  Bhoopendra:  +₹300 (receiver)  │
│  Anand:       -₹100 (owes)      │
│  Naman:       -₹100 (owes)      │
│  Varun:       -₹100 (owes)      │
└─────────────────────────────────┘
            ↓
    Step 1: Separate
┌─────────────────────────────────┐
│ Debtors:     Creditors:         │
│ Anand -100   Bhoopendra +300    │
│ Naman -100                      │
│ Varun -100                      │
└─────────────────────────────────┘
            ↓
    Step 2: Match (greedy)
┌─────────────────────────────────┐
│ Anand (100) vs Bhoopendra (300) │
│ → Match 100                     │
│ Result: Anand settled ✓         │
│         Bhoopendra: +200        │
├─────────────────────────────────┤
│ Naman (100) vs Bhoopendra (200) │
│ → Match 100                     │
│ Result: Naman settled ✓         │
│         Bhoopendra: +100        │
├─────────────────────────────────┤
│ Varun (100) vs Bhoopendra (100) │
│ → Match 100                     │
│ Result: Varun settled ✓         │
│         Bhoopendra: 0 ✓         │
└─────────────────────────────────┘
            ↓
Output: Minimal Transactions
┌─────────────────────────────────┐
│ Anand → Bhoopendra: ₹100        │
│ Naman → Bhoopendra: ₹100        │
│ Varun → Bhoopendra: ₹100        │
│ Total: 3 transactions           │
│ All balances: 0 ✓               │
└─────────────────────────────────┘
```

## 10. Clean Architecture Layers

```
┌────────────────────────────────────────────┐
│      Presentation Layer (UI)               │
│  - Screens: Home, Balance, Settlement      │
│  - Widgets: Reusable UI components         │
│  - Widgets bound to nothing except UI      │
└────────────────────────────────────────────┘
                   ↑
        (depends on Provider)
                   ↓
┌────────────────────────────────────────────┐
│    State Management Layer (Provider)       │
│  - ExpenseProvider (CRUD)                  │
│  - BalanceProvider (calculated)            │
│  - SyncProvider (status)                   │
└────────────────────────────────────────────┘
                   ↑
        (depends on Domain/Services)
                   ↓
┌────────────────────────────────────────────┐
│   Domain & Service Layer (Business Logic)  │
│  - SettlementService (algorithm)           │
│  - SyncService (P2P)                       │
│  - Entities (immutable)                    │
└────────────────────────────────────────────┘
                   ↑
        (depends on Data)
                   ↓
┌────────────────────────────────────────────┐
│      Data Layer (Repository)               │
│  - ExpenseRepository (interface)           │
│  - IsarService (implementation)            │
│  - Database operations                     │
└────────────────────────────────────────────┘
                   ↑
        (depends on Storage)
                   ↓
┌────────────────────────────────────────────┐
│      Storage Layer (Local Database)        │
│  - Isar collections                        │
│  - SQLite (Isar backend)                   │
│  - Local filesystem                        │
└────────────────────────────────────────────┘

Key: Each layer depends only on layers below
     Lower layers don't know about upper layers
```

---

These diagrams help visualize how FlatSync works at different levels of abstraction.
