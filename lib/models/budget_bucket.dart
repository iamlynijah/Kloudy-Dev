/// The three high-level buckets a person's income gets split across.
enum BucketType { bills, savings, spending }

/// A single slider-adjustable bucket (Bills / Savings / Spend) with both
/// a system-suggested percentage and the user's current (possibly
/// adjusted) percentage.
class BudgetBucket {
  final BucketType type;
  final String label;

  /// The percentage this bucket would get if computed purely from the
  /// user's actual numbers (bills ÷ income, etc) — shown as a "suggested"
  /// reference point even after the user drags the slider away from it.
  final double suggestedPercent;

  /// The user's current slider position. Starts equal to
  /// [suggestedPercent] and moves independently once they drag it.
  double currentPercent;

  BudgetBucket({
    required this.type,
    required this.label,
    required this.suggestedPercent,
    double? currentPercent,
  }) : currentPercent = currentPercent ?? suggestedPercent;

  double dollarAmount(double monthlyIncome) =>
      monthlyIncome * (currentPercent / 100);
}

/// Computes suggested Bills / Savings / Spend percentages from what the
/// user actually told us, rather than applying a flat rule (e.g. 50/30/20)
/// that ignores whether their real bills already eat most of their income.
///
/// Logic:
/// - Bills % = actual anchor-bill total ÷ monthly income, with a floor of
///   10% (so the bucket isn't meaningless if bills are very low) — this is
///   not a "suggestion" so much as a fact, since bills are fixed.
/// - Savings % defaults to 10%, but: if there's high-APR debt (>10%),
///   nudge a bit more toward savings/debt payoff at spending's expense,
///   since carrying high-interest debt usually outweighs the value of
///   discretionary spending. If bills already consume nearly everything,
///   savings shrinks rather than pretending there's room that isn't there.
/// - Spend % is whatever's left after bills + savings.
///
/// Always returns three percentages that sum to 100, even in tight-budget
/// cases — `isOverextended` flags when bills alone are >= 90% of income,
/// since at that point the suggestion is more "here's what's left" than
/// a meaningful recommendation.
class BucketSuggestion {
  final double billsPercent;
  final double savingsPercent;
  final double spendingPercent;
  final bool isOverextended;

  BucketSuggestion({
    required this.billsPercent,
    required this.savingsPercent,
    required this.spendingPercent,
    required this.isOverextended,
  });

  factory BucketSuggestion.compute({
    required double monthlyIncome,
    required double totalAnchorBills,
    double debtApr = 0,
  }) {
    if (monthlyIncome <= 0) {
      // No income on file — fall back to the classic rule rather than
      // dividing by zero or suggesting nothing at all.
      return BucketSuggestion(
        billsPercent: 50,
        savingsPercent: 20,
        spendingPercent: 30,
        isOverextended: false,
      );
    }

    double billsPercent = (totalAnchorBills / monthlyIncome) * 100;
    billsPercent = billsPercent.clamp(10, 90);

    final remaining = 100 - billsPercent;
    final overextended = billsPercent >= 90;

    if (overextended) {
      // Almost nothing left — put what little remains toward savings
      // first (even a thin buffer matters more than discretionary spend
      // when bills are this tight) rather than suggesting 0% everywhere.
      return BucketSuggestion(
        billsPercent: billsPercent,
        savingsPercent: remaining,
        spendingPercent: 0,
        isOverextended: true,
      );
    }

    // Base savings target within whatever room bills left behind.
    double savingsPercent = 10;

    // High-interest debt (credit cards typically run well above 10%
    // APR) makes paying it down worth more than most discretionary
    // spending, so shift a bit of the "rest goes to you" share toward
    // savings/debt payoff instead.
    if (debtApr > 10) {
      savingsPercent += 5;
    }

    savingsPercent = savingsPercent.clamp(0, remaining);
    final spendingPercent = remaining - savingsPercent;

    return BucketSuggestion(
      billsPercent: billsPercent,
      savingsPercent: savingsPercent,
      spendingPercent: spendingPercent,
      isOverextended: false,
    );
  }
}