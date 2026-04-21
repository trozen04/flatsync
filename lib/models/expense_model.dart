import 'package:isar_community/isar.dart';

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

  /// User who paid for this expense (backend user ID)
  String paidBy = '';
  
  /// List of participant user IDs (including paidBy)
  List<String> participants = [];

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
    this.participants = const [],
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
      'participants': participants,
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
    // Backend should send an array, but be defensive: some responses may contain
    // `participants` as a count or another unexpected shape.
    final raw = json['participants'];
    final rawParticipants = (raw is List) ? raw : const [];
    final normalizedParticipants = rawParticipants
        .map((e) {
          if (e is String) return e;
          if (e is Map<String, dynamic>) {
            final phone = e['phoneNumber'];
            if (phone is String && phone.isNotEmpty) return phone;
            final user = e['user'];
            if (user is String && user.isNotEmpty) return user;
          }
          return null;
        })
        .whereType<String>()
        .toList();

    final createdBy = json['createdBy'];
    final paidBy = (json['paidBy'] as String?) ??
        (createdBy is Map<String, dynamic>
            ? ((createdBy['_id'] as String?) ??
                (createdBy['phoneNumber'] as String?) ??
                (createdBy['name'] as String?))
            : (createdBy as String?)) ??
        '';

    return ExpenseModel(
      uuid: (json['uuid'] as String?) ??
          (json['_id'] as String?) ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      amount: (json['amount'] as int?) ??
          ((json['totalAmount'] as num?)?.toInt() ?? 0),
      paidBy: paidBy,
      participants: normalizedParticipants,
      createdAt: DateTime.parse(
        (json['createdAt'] as String?) ?? DateTime.now().toUtc().toIso8601String(),
      ),
      lastModifiedAt: DateTime.parse(
        (json['lastModifiedAt'] as String?) ??
            (json['updatedAt'] as String?) ??
            (json['createdAt'] as String?) ??
            DateTime.now().toUtc().toIso8601String(),
      ),
      deviceId: (json['deviceId'] as String?) ?? 'server',
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

