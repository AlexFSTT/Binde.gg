/// Wallet transaction — maps to `wallet_transactions` table.
class TransactionModel {
  final String id;
  final String walletId;
  final String userId;
  final String? matchId;
  final String type;
  final double amount;
  final double fee;
  final double balanceBefore;
  final double balanceAfter;
  final String status;
  final String? description;
  final String? externalRef;
  final DateTime createdAt;

  const TransactionModel({
    required this.id,
    required this.walletId,
    required this.userId,
    this.matchId,
    required this.type,
    required this.amount,
    this.fee = 0.0,
    required this.balanceBefore,
    required this.balanceAfter,
    this.status = 'pending',
    this.description,
    this.externalRef,
    required this.createdAt,
  });

  bool get isCredit => ['deposit', 'winnings', 'refund', 'bonus'].contains(type);
  bool get isDebit => ['withdrawal', 'entry_fee', 'rake'].contains(type);

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'] as String,
      walletId: json['wallet_id'] as String,
      userId: json['user_id'] as String,
      matchId: json['match_id'] as String?,
      type: json['type'] as String,
      amount: (json['amount'] as num).toDouble(),
      fee: (json['fee'] as num?)?.toDouble() ?? 0.0,
      balanceBefore: (json['balance_before'] as num).toDouble(),
      balanceAfter: (json['balance_after'] as num).toDouble(),
      status: json['status'] as String? ?? 'pending',
      description: json['description'] as String?,
      externalRef: json['external_ref'] as String?,
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
