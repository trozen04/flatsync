class TransactionModel {
  String transactionId;
  String fromUserId;
  String toUserId;
  int amount;
  DateTime createdAt;
  DateTime updatedAt;
  String? relatedExpenseId;

  TransactionModel({
    this.transactionId = '',
    this.fromUserId = '',
    this.toUserId = '',
    this.amount = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.relatedExpenseId,
  })  : createdAt = (createdAt ?? DateTime.now()).toUtc(),
        updatedAt = (updatedAt ?? createdAt ?? DateTime.now()).toUtc();

  static String _extractUserId(dynamic user) {
    if (user is String) return user;
    if (user is Map<String, dynamic>) {
      final id = user['_id'] ?? user['id'];
      if (id is String) return id;
      final phone = user['phoneNumber'];
      if (phone is String) return phone;
    }
    return '';
  }

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    final fromUserId = _extractUserId(json['fromUser']);
    final toUserId = _extractUserId(json['toUser']);

    final relatedExpense = json['relatedExpense'];
    String? relatedExpenseId;
    if (relatedExpense is String) {
      relatedExpenseId = relatedExpense;
    } else if (relatedExpense is Map<String, dynamic>) {
      relatedExpenseId = (relatedExpense['_id'] ?? relatedExpense['id']) as String?;
    }

    final transactionId = (json['_id'] as String?) ??
        (json['transactionId'] as String?) ??
        '${fromUserId}_${toUserId}_${(json['createdAt'] as String?) ?? DateTime.now().toUtc().toIso8601String()}';

    return TransactionModel(
      transactionId: transactionId,
      fromUserId: fromUserId,
      toUserId: toUserId,
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse((json['createdAt'] as String?) ?? '') ?? DateTime.now().toUtc(),
      updatedAt: DateTime.tryParse(
            (json['updatedAt'] as String?) ?? (json['createdAt'] as String?) ?? '',
          ) ??
          DateTime.now().toUtc(),
      relatedExpenseId: relatedExpenseId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'transactionId': transactionId,
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'amount': amount,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'relatedExpenseId': relatedExpenseId,
    };
  }
}
