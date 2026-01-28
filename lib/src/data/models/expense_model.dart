import 'package:isar/isar.dart';

part 'expense_model.g.dart';

/// Expense model with Isar annotations for local persistence
/// Every device maintains a complete copy of all expenses
/// Sync matches by UUID and uses lastModifiedAt for conflict resolution
@Collection()
class ExpenseModel {
  Id? id; // Isar internal ID

  /// Unique identifier for the expense (same across all devices)
  @Index(unique: true)
  String uuid = '';

  /// Amount in smallest currency unit (e.g., paise for INR)
  int amount = 0;

  /// User who paid for this expense (dynamic string instead of enum)
  String paidBy = '';

  /// Timestamp when expense was created (UTC)
  DateTime createdAt = DateTime.now().toUtc();

  /// Timestamp when expense was last modified (UTC) - used for sync conflict resolution
  DateTime lastModifiedAt = DateTime.now().toUtc();

  /// Device ID of the device that created this expense
  String deviceId = '';

  /// Optional description of the expense
  String? description;

  /// For sync tracking - helps avoid re-syncing same record
  @Index()
  DateTime syncedAt = DateTime.now().toUtc();

  /// Soft delete flag - deleted items are excluded from calculations but kept for history
  bool isDeleted = false;

  /// Timestamp when expense was deleted (if deleted)
  DateTime? deletedAt;

  ExpenseModel({
    this.id,
    required this.uuid,
    required this.amount,
    required this.paidBy,
    required this.createdAt,
    required this.lastModifiedAt,
    required this.deviceId,
    this.description,
    this.isDeleted = false,
    this.deletedAt,
  });

  /// Convert to JSON for network transmission
  Map<String, dynamic> toJson() {
    return {
      'uuid': uuid,
      'amount': amount,
      'paidBy': paidBy,
      'createdAt': createdAt.toIso8601String(),
      'lastModifiedAt': lastModifiedAt.toIso8601String(),
      'deviceId': deviceId,
      'description': description,
      'isDeleted': isDeleted,
      'deletedAt': deletedAt?.toIso8601String(),
    };
  }

  /// Create from JSON received from network
  factory ExpenseModel.fromJson(Map<String, dynamic> json) {
    return ExpenseModel(
      uuid: json['uuid'] as String,
      amount: json['amount'] as int,
      paidBy: json['paidBy'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastModifiedAt: DateTime.parse(json['lastModifiedAt'] as String),
      deviceId: json['deviceId'] as String,
      description: json['description'] as String?,
      isDeleted: json['isDeleted'] as bool? ?? false,
      deletedAt: json['deletedAt'] != null ? DateTime.parse(json['deletedAt'] as String) : null,
    );
  }

  /// Create a copy with updated fields
  ExpenseModel copyWith({
    String? uuid,
    int? amount,
    String? paidBy,
    DateTime? createdAt,
    DateTime? lastModifiedAt,
    String? deviceId,
    String? description,
  }) {
    return ExpenseModel(
      uuid: uuid ?? this.uuid,
      amount: amount ?? this.amount,
      paidBy: paidBy ?? this.paidBy,
      createdAt: createdAt ?? this.createdAt,
      lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
      deviceId: deviceId ?? this.deviceId,
      description: description ?? this.description,
    );
  }
}
