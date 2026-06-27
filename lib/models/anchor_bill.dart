/// A recurring fixed monthly expense (rent, utilities, subscriptions,
/// car payment, etc) — the "anchors" that make up the Bills bucket.
class AnchorBill {
  final String id;
  String name;
  double monthlyAmount;

  AnchorBill({
    required this.id,
    required this.name,
    required this.monthlyAmount,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'monthly_amount': monthlyAmount,
      };

  factory AnchorBill.fromJson(Map<String, dynamic> json) => AnchorBill(
        id: json['id'] as String,
        name: json['name'] as String,
        monthlyAmount: (json['monthly_amount'] as num).toDouble(),
      );
}

/// A preset shown on the finance onboarding screen so common bills can
/// be tapped to add rather than typed from scratch.
class AnchorBillPreset {
  final String name;

  const AnchorBillPreset({required this.name});
}

const List<AnchorBillPreset> anchorBillPresets = [
  AnchorBillPreset(name: 'Rent / Mortgage'),
  AnchorBillPreset(name: 'Car payment'),
  AnchorBillPreset(name: 'Car insurance'),
  AnchorBillPreset(name: 'Phone bill'),
  AnchorBillPreset(name: 'Internet'),
  AnchorBillPreset(name: 'Utilities'),
  AnchorBillPreset(name: 'Streaming subscriptions'),
  AnchorBillPreset(name: 'Gym membership'),
];

/// A recurring discretionary "extra" — things you spend on regularly
/// but that aren't fixed bills (nails, haircut, etc). Tracked separately
/// from anchor bills since these typically come out of the Spend bucket
/// rather than Bills, and the amount may vary month to month.
class RecurringExtra {
  final String id;
  String name;
  double estimatedMonthlyAmount;

  RecurringExtra({
    required this.id,
    required this.name,
    required this.estimatedMonthlyAmount,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'estimated_monthly_amount': estimatedMonthlyAmount,
      };

  factory RecurringExtra.fromJson(Map<String, dynamic> json) =>
      RecurringExtra(
        id: json['id'] as String,
        name: json['name'] as String,
        estimatedMonthlyAmount:
            (json['estimated_monthly_amount'] as num).toDouble(),
      );
}

const List<AnchorBillPreset> recurringExtraPresets = [
  AnchorBillPreset(name: 'Nails'),
  AnchorBillPreset(name: 'Haircut'),
  AnchorBillPreset(name: 'Skincare'),
  AnchorBillPreset(name: 'Dining out'),
  AnchorBillPreset(name: 'Coffee'),
  AnchorBillPreset(name: 'Rideshare/gas'),
];