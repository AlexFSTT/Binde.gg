import '../../config/supabase_config.dart';
import '../../core/errors/result.dart';
import '../models/wallet_model.dart';
import '../models/transaction_model.dart';

/// Wallet and transaction operations.
class WalletRepository {
  final _client = SupabaseConfig.client;

  Future<Result<WalletModel>> getWallet(String userId) async {
    try {
      final data = await _client.from('wallets').select().eq('user_id', userId).single();
      return Success(WalletModel.fromJson(data));
    } catch (e) {
      return Failure(e.toString());
    }
  }

  Future<Result<List<TransactionModel>>> getTransactions(String userId, {int limit = 20, int offset = 0}) async {
    try {
      final data = await _client
          .from('wallet_transactions')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);
      return Success(data.map((j) => TransactionModel.fromJson(j)).toList());
    } catch (e) {
      return Failure(e.toString());
    }
  }
}
