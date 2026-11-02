import 'dart:collection';
import 'dart:math';

import 'package:flutter/widgets.dart';

import 'demo_data.dart';
import 'models.dart';

/// The customer's account, held in memory for the demo.
///
/// State is private: it only changes through the methods below, which apply
/// the rules and notify listeners. In production these would call the bank's
/// backend and this class would mirror its responses.
class WalletState extends ChangeNotifier {
  WalletState({DateTime Function()? clock, Random? random})
    : _clock = clock ?? DateTime.now,
      _random = random ?? Random() {
    _seed();
  }

  final DateTime Function() _clock;
  final Random _random;

  String _customerName = DemoData.customerName;
  late int _balanceCents;
  late bool _cardFrozen;
  late bool _accountSecured;
  late List<Transaction> _transactions;
  final List<SupportCase> _cases = [];

  /// Editable from the avatar on the home screen; the agent greets the
  /// customer by the first word.
  String get customerName => _customerName;
  String get firstName => _customerName.split(' ').first;
  String get initial => _customerName.characters.first.toUpperCase();
  int get balanceCents => _balanceCents;
  bool get cardFrozen => _cardFrozen;
  bool get accountSecured => _accountSecured;
  String get cardLast4 => DemoData.cardLast4;
  String get emailMasked => DemoData.emailMasked;
  UnmodifiableListView<Transaction> get transactions => UnmodifiableListView(_transactions);
  UnmodifiableListView<SupportCase> get cases => UnmodifiableListView(_cases);

  Transaction? get flaggedTransaction {
    for (final tx in _transactions) {
      if (tx.status == TxStatus.flagged) return tx;
    }
    return null;
  }

  void updateName(String name) {
    final trimmed = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (trimmed.isEmpty || trimmed == _customerName) return;
    _customerName = trimmed;
    notifyListeners();
  }

  /// Returns false if the card was already frozen.
  bool freezeCard() {
    if (_cardFrozen) return false;
    _cardFrozen = true;
    notifyListeners();
    return true;
  }

  ({DisputeOutcome outcome, Transaction? transaction}) disputeTransaction(String id) {
    final index = _transactions.indexWhere((tx) => tx.id == id);
    if (index < 0) return (outcome: DisputeOutcome.notFound, transaction: null);
    final tx = _transactions[index];
    if (!tx.isDebit) {
      return (outcome: DisputeOutcome.notDisputable, transaction: tx);
    }
    if (tx.status == TxStatus.disputed) {
      return (outcome: DisputeOutcome.alreadyDisputed, transaction: tx);
    }
    final disputed = tx.copyWith(status: TxStatus.disputed);
    _transactions[index] = disputed;
    notifyListeners();
    return (outcome: DisputeOutcome.opened, transaction: disputed);
  }

  /// Returns false if the account was already secured.
  bool secureAccount() {
    if (_accountSecured) return false;
    _accountSecured = true;
    notifyListeners();
    return true;
  }

  SupportCase openCase({
    required CaseCategory category,
    required String summary,
    required CasePriority priority,
    required String? conversationId,
  }) {
    final supportCase = SupportCase(
      id: 'DW-${1000 + _random.nextInt(9000)}',
      category: category,
      summary: summary,
      priority: priority,
      conversationId: conversationId,
      createdAt: _clock(),
    );
    _cases.insert(0, supportCase);
    notifyListeners();
    return supportCase;
  }

  /// Restores the demo data so the flow can be shown again.
  void resetDemo() {
    _seed();
    notifyListeners();
  }

  void _seed() {
    _balanceCents = DemoData.balanceCents;
    _cardFrozen = false;
    _accountSecured = false;
    _transactions = DemoData.transactions(_clock());
    _cases.clear();
  }
}

/// Makes [WalletState] available to the widget tree.
class WalletScope extends InheritedNotifier<WalletState> {
  const WalletScope({super.key, required WalletState wallet, required super.child})
    : super(notifier: wallet);

  static WalletState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<WalletScope>()!.notifier!;

  static WalletState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<WalletScope>()!.notifier!;
}
