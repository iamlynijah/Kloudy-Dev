/// A single spending transaction, shaped to mirror the fields Plaid's
/// `/transactions/sync` endpoint returns (`name`, `amount`, `date`,
/// `personal_finance_category`) so swapping this mock source for a real
/// Plaid integration later means changing where the list comes from,
/// not changing how it's displayed.
class Transaction {
  final String id;
  final String merchantName;
  final double amount;
  final DateTime date;
  final String category;
  final String? accountId;
  final bool isTransfer;
  final String? transferType; // 'loan_payment', 'transfer', or null

  Transaction({
    required this.id,
    required this.merchantName,
    required this.amount,
    required this.date,
    required this.category,
    this.accountId,
    this.isTransfer = false,
    this.transferType,
  });

  factory Transaction.fromJson(Map<String, dynamic> j) => Transaction(
        id: j['id'] as String,
        merchantName: j['merchantName'] as String,
        amount: (j['amount'] as num).toDouble(),
        date: DateTime.parse(j['date'] as String),
        category: j['category'] as String,
        accountId: j['accountId'] as String?,
        isTransfer: j['isTransfer'] as bool? ?? false,
        transferType: j['transferType'] as String?,
      );
}

class PlaidAccount {
  final String id;
  final String name;
  final String type;

  const PlaidAccount({required this.id, required this.name, required this.type});

  factory PlaidAccount.fromJson(Map<String, dynamic> j) => PlaidAccount(
        id: j['id'] as String,
        name: j['name'] as String,
        type: j['type'] as String,
      );

  String get displayName {
    final t = type.toLowerCase();
    if (t == 'checking') return '$name (Checking)';
    if (t == 'savings') return '$name (Savings)';
    if (t.contains('credit')) return '$name (Credit)';
    return name;
  }
}

/// Whether the user has connected a bank via Plaid Link. Until real
/// Plaid integration exists, this just gates whether mock transactions
/// are shown vs. a "Connect your bank" prompt — see the note on
/// FinancesScreen for what real integration requires (a backend
/// token-exchange step; Plaid's secret key can never live in the app).
class PlaidConnectionState {
  final bool isConnected;
  final String? institutionName;

  const PlaidConnectionState({
    required this.isConnected,
    this.institutionName,
  });

  static const disconnected = PlaidConnectionState(isConnected: false);
}

/// Mock weekly spending log, standing in for real Plaid transaction
/// sync. Replace the body of this function with a real fetch once
/// Plaid Link + a backend token exchange exist.
List<Transaction> mockWeeklyTransactions() {
  final now = DateTime.now();
  DateTime daysAgo(int n) => now.subtract(Duration(days: n));

  return [
    Transaction(
      id: 'txn-1',
      merchantName: 'Chipotle',
      amount: 12.47,
      date: daysAgo(0),
      category: 'Food & Drink',
    ),
    Transaction(
      id: 'txn-2',
      merchantName: 'Walmart',
      amount: 34.92,
      date: daysAgo(1),
      category: 'Groceries',
    ),
    Transaction(
      id: 'txn-3',
      merchantName: 'Shell',
      amount: 28.10,
      date: daysAgo(1),
      category: 'Gas',
    ),
    Transaction(
      id: 'txn-4',
      merchantName: 'Starbucks',
      amount: 6.75,
      date: daysAgo(2),
      category: 'Food & Drink',
    ),
    Transaction(
      id: 'txn-5',
      merchantName: 'Amazon',
      amount: 41.23,
      date: daysAgo(3),
      category: 'Shopping',
    ),
    Transaction(
      id: 'txn-6',
      merchantName: 'Target',
      amount: 19.60,
      date: daysAgo(4),
      category: 'Shopping',
    ),
    Transaction(
      id: 'txn-7',
      merchantName: 'Chick-fil-A',
      amount: 9.85,
      date: daysAgo(5),
      category: 'Food & Drink',
    ),
  ];
}