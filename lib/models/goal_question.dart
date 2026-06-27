enum QuestionType {
  singleChoice,
  multiChoice,
  weightSlider,
  sleepSlider,
  moneySlider,
  percentSlider
}

class GoalQuestion {
  final String id;
  final String section;
  final String question;
  final QuestionType type;
  final List<String>? options;

  // ── Slider config (used by moneySlider / percentSlider) ──
  // Lets one slider widget serve several questions with different
  // ranges — e.g. a $0–$5,000 savings goal vs. a $0–$100,000 debt amount.
  final double? minValue;
  final double? maxValue;
  final int? divisions;
  final double? initialValue;

  GoalQuestion({
    required this.id,
    required this.section,
    required this.question,
    required this.type,
    this.options,
    this.minValue,
    this.maxValue,
    this.divisions,
    this.initialValue,
  });
}