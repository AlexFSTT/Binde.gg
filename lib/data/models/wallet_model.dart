/// User wallet — maps to `wallets` table.
class WalletModel {
  final String id;
  final String userId;
  final double balance;
  final double lockedBalance;
  final double totalDeposited;
  final double totalWithdrawn;
  final double totalWagered;
  final double totalWon;
  final DateTime createdAt;
  final DateTime updatedAt;

  const WalletModel({
    required this.id,
    required this.userId,
    this.balance = 0.0,
    this.lockedBalance = 0.0,
    this.totalDeposited = 0.0,
    this.totalWithdrawn = 0.0,
    this.totalWagered = 0.0,
    this.totalWon = 0.0,
    required this.createdAt,
    required this.updatedAt,
  });

  double get availableBalance => balance - lockedBalance;
  double get netProfit => totalWon - totalWagered;

  factory WalletModel.fromJson(Map<String, dynamic> json) {
    return WalletModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
      lockedBalance: (json['locked_balance'] as num?)?.toDouble() ?? 0.0,
      totalDeposited: (json['total_deposited'] as num?)?.toDouble() ?? 0.0,
      totalWithdrawn: (json['total_withdrawn'] as num?)?.toDouble() ?? 0.0,
      totalWagered: (json['total_wagered'] as num?)?.toDouble() ?? 0.0,
      totalWon: (json['total_won'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}
