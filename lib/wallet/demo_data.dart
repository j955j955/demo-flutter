import 'models.dart';

/// Fictional account data: no real card numbers, people or merchants.
abstract final class DemoData {
  static const customerName = 'Alex Morgan';
  static const cardLast4 = '7314';
  static const emailMasked = 'a•••@example.com';
  static const balanceCents = 248130;

  /// Recent activity relative to [now], so the demo always looks current.
  static List<Transaction> transactions(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    return [
      Transaction(
        id: 'tx_9f31',
        merchant: 'GAMEVAULT*DIGITAL',
        category: TxCategory.digitalGoods,
        amountCents: -38999,
        date: today.subtract(const Duration(hours: 22, minutes: 46)),
        detail: 'Online purchase from a new device',
        status: TxStatus.flagged,
      ),
      Transaction(
        id: 'tx_9f2c',
        merchant: 'Corner Café',
        category: TxCategory.foodAndDrink,
        amountCents: -640,
        date: today.subtract(const Duration(hours: 15, minutes: 12)),
      ),
      Transaction(
        id: 'tx_9f1a',
        merchant: 'Metro Transit',
        category: TxCategory.transport,
        amountCents: -290,
        date: today.subtract(const Duration(days: 1, hours: 6)),
      ),
      Transaction(
        id: 'tx_9e88',
        merchant: 'Groceria Market',
        category: TxCategory.groceries,
        amountCents: -8412,
        date: today.subtract(const Duration(days: 2, hours: 4)),
      ),
      Transaction(
        id: 'tx_9e41',
        merchant: 'Salary deposit',
        category: TxCategory.income,
        amountCents: 315000,
        date: today.subtract(const Duration(days: 3, hours: 9)),
      ),
    ];
  }
}
