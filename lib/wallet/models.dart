import 'package:flutter/foundation.dart';

enum TxStatus { posted, flagged, disputed }

enum TxCategory {
  digitalGoods('Digital goods'),
  foodAndDrink('Food & drink'),
  transport('Transport'),
  groceries('Groceries'),
  income('Income');

  const TxCategory(this.label);
  final String label;
}

@immutable
class Transaction {
  const Transaction({
    required this.id,
    required this.merchant,
    required this.category,
    required this.amountCents,
    required this.date,
    this.detail,
    this.status = TxStatus.posted,
  });

  final String id;
  final String merchant;
  final TxCategory category;

  /// Negative for money out, positive for money in. Integer cents, never a
  /// double, so amounts add up exactly.
  final int amountCents;
  final DateTime date;
  final String? detail;
  final TxStatus status;

  bool get isDebit => amountCents < 0;

  Transaction copyWith({TxStatus? status}) => Transaction(
    id: id,
    merchant: merchant,
    category: category,
    amountCents: amountCents,
    date: date,
    detail: detail,
    status: status ?? this.status,
  );

  /// The shape the support agent receives from get_recent_transactions.
  Map<String, Object> toAgentJson() => {
    'transaction_id': id,
    'merchant': merchant,
    'category': category.label,
    'amount_usd': amountCents / 100,
    'date': date.toIso8601String(),
    'detail': ?detail,
    'status': status.name,
  };
}

/// Values the agent sends when it opens a case. Unknown values fall back to
/// the default instead of being stored as free text.
enum CaseCategory {
  fraud('fraud'),
  accountSecurity('account_security'),
  billing('billing'),
  card('card'),
  other('other');

  const CaseCategory(this.wire);
  final String wire;

  static CaseCategory parse(Object? value) =>
      values.firstWhere((c) => c.wire == value, orElse: () => other);
}

enum CasePriority {
  normal('normal'),
  urgent('urgent');

  const CasePriority(this.wire);
  final String wire;

  static CasePriority parse(Object? value) =>
      values.firstWhere((p) => p.wire == value, orElse: () => normal);
}

@immutable
class SupportCase {
  const SupportCase({
    required this.id,
    required this.category,
    required this.summary,
    required this.priority,
    required this.conversationId,
    required this.createdAt,
  });

  final String id;
  final CaseCategory category;
  final String summary;
  final CasePriority priority;

  /// Links the case to the conversation so a specialist can pick up with
  /// full context instead of asking the customer to start over.
  final String? conversationId;
  final DateTime createdAt;
}

enum DisputeOutcome { opened, alreadyDisputed, notFound, notDisputable }
