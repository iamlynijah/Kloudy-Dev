enum IncomeFrequency { weekly, biweekly, semimonthly, monthly }

extension IncomeFrequencyX on IncomeFrequency {
  String get label {
    switch (this) {
      case IncomeFrequency.weekly:      return 'Every week';
      case IncomeFrequency.biweekly:    return 'Every 2 weeks';
      case IncomeFrequency.semimonthly: return 'Twice a month';
      case IncomeFrequency.monthly:     return 'Once a month';
    }
  }

  double get monthlyMultiplier {
    switch (this) {
      case IncomeFrequency.weekly:      return 52 / 12;
      case IncomeFrequency.biweekly:    return 26 / 12;
      case IncomeFrequency.semimonthly: return 2.0;
      case IncomeFrequency.monthly:     return 1.0;
    }
  }
}

IncomeFrequency incomeFrequencyFromString(String s) =>
    IncomeFrequency.values.firstWhere(
      (f) => f.name == s,
      orElse: () => IncomeFrequency.monthly,
    );

class FinanceGoal {
  final String id;
  String name;
  double targetAmount;
  double currentAmount;
  int targetMonths;
  bool isDebt;
  double? debtMinPayment;

  FinanceGoal({
    required this.id,
    required this.name,
    required this.targetAmount,
    this.currentAmount = 0,
    required this.targetMonths,
    this.isDebt = false,
    this.debtMinPayment,
  });

  double get remaining =>
      (targetAmount - currentAmount).clamp(0.0, double.infinity);

  double get percentComplete =>
      targetAmount > 0 ? (currentAmount / targetAmount).clamp(0.0, 1.0) : 0;

  double get suggestedMonthlyContribution {
    if (targetMonths <= 0 || remaining <= 0) return 0;
    return remaining / targetMonths;
  }

  String get timelineLabel {
    final m = targetMonths;
    if (m <= 0) return '';
    if (m < 12) return '${m}mo';
    final y = m ~/ 12;
    final leftover = m % 12;
    if (leftover == 0) return '${y}yr';
    return '${y}yr ${leftover}mo';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'target_amount': targetAmount,
        'current_amount': currentAmount,
        'target_months': targetMonths,
        'is_debt': isDebt,
        'debt_min_payment': debtMinPayment,
      };

  factory FinanceGoal.fromJson(Map<String, dynamic> j) => FinanceGoal(
        id: j['id'] as String,
        name: j['name'] as String,
        targetAmount: (j['target_amount'] as num).toDouble(),
        currentAmount: (j['current_amount'] as num? ?? 0).toDouble(),
        targetMonths: j['target_months'] as int,
        isDebt: j['is_debt'] as bool? ?? false,
        debtMinPayment: (j['debt_min_payment'] as num?)?.toDouble(),
      );
}

const List<String> savingsGoalPresets = [
  'Emergency Fund',
  'Vacation',
  'New Car',
  'Down Payment',
  'Wedding',
  'Education',
];

const List<String> debtPresets = [
  'Credit Card',
  'Car Loan',
  'Student Loans',
  'Medical Debt',
  'Personal Loan',
];
