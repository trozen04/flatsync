/// Domain entity for Settlement
/// Shows who should pay whom and how much
/// Immutable representation after calculation
class Settlement {
  final String from;
  final String to;
  final int amount;

  Settlement({
    required this.from,
    required this.to,
    required this.amount,
  });

  @override
  String toString() => '$from → $to ₹${(amount / 100).toStringAsFixed(2)}';
}

/// Domain entity for User Balance
/// Shows total paid and net balance for each user
class UserBalance {
  final String user;
  final int totalPaid;
  final int perPersonShare;
  final int netBalance; // positive = receives, negative = owes

  UserBalance({
    required this.user,
    required this.totalPaid,
    required this.perPersonShare,
    required this.netBalance,
  });

  bool get isOwing => netBalance < 0;

  bool get isReceiving => netBalance > 0;

  @override
  String toString() =>
      '$user: Paid ₹${(totalPaid / 100).toStringAsFixed(2)}, Balance ₹${(netBalance / 100).toStringAsFixed(2)}';
}

