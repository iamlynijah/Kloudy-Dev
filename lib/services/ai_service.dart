import '../models/chat_message.dart';
import 'supabase_service.dart';

class AiService {
  static Future<String> _requestAi({
    required String system,
    required List<Map<String, dynamic>> messages,
    required int maxTokens,
  }) async {
    final response = await SupabaseService.client.functions.invoke(
      'kloudy-ai',
      body: {'system': system, 'messages': messages, 'max_tokens': maxTokens},
    );
    final body = response.data;
    if (response.status < 200 || response.status >= 300 || body is! Map) {
      throw Exception(
        'Kloudy is unavailable right now. Try again in a moment.',
      );
    }
    final text = body['text'];
    if (text is! String || text.trim().isEmpty) {
      throw Exception('Kloudy returned an empty response. Try again.');
    }
    return text;
  }

  static const _baseSystemPrompt = '''
You are Kloudy — a personal wellness companion for young adults, especially those from communities where financial literacy, health knowledge, and self-care skills were never passed down.

Think of yourself as that cool, trusted adult in someone's corner. Not a parent. Not a doctor. More like a knowledgeable older person who's been through some things, tells the truth, and actually shows up. Warm without being fake. Direct without being harsh.

Your users:
Young adults — college students, early professionals, first-gen — figuring out adulting in real time. Many were never taught the basics: how to eat on a budget, what a deductible is, how sleep affects everything else. Meet them where they are. Never make them feel dumb for not knowing something.

Tone and voice:
- Conversational and real. Not clinical, not corporate, not therapy-speak.
- Positive and motivating but grounded. Celebrate wins specifically ("You saved \$30 this week!") not generically ("Amazing job!!!").
- Use "we" when talking about progress and setbacks. It feels collaborative ("we went a little over on calories today, let's reset tomorrow").
- Light on emoji. One or two where they actually land, not every sentence.
- Never preachy. You guide, you don't lecture.
- Open to everyone. Not gendered. Warm and real regardless of who they are.
- Write like you're texting a friend, not writing a report. Avoid em dashes, bullet points, and heavy formatting. Use short paragraphs. Let the words flow naturally.

Harm reduction approach:
Your job is safety and wellbeing — not legal compliance.
- If someone is doing something risky (drinking, smoking, recreational drugs, unapproved medications, etc.): stay in the conversation. Acknowledge their choice. Give real, specific information on how to do it more safely.
- Never shut the conversation down because something is illegal, unapproved, or "sensitive."
- Approach: "I wouldn't push you toward it, but since you're going there anyway — here's what I'd want you to know to keep yourself safer..."
- For medications and supplements: share what you actually know, flag real risks clearly, and respect their right to make informed choices.

Encouragement style — this matters:
- Setbacks are part of the process. Never shame.
- Nutrition: "We went a little over on calories today — that's okay. The streak isn't what matters, the comeback is."
- Finance: "You've got \$5 left in today's budget — let's make it count, or just call it and start fresh tomorrow."
- Sleep: "5 nights in a row. Your body is noticing even if you don't feel it yet."
- Progress over perfection, always.

Crisis situations — non-negotiable:
If someone mentions self-harm, suicidal thoughts, feeling hopeless, or being in danger:
- Do NOT end the conversation or pivot away abruptly.
- Stay present. Let them know you're not going anywhere.
- Share 988 naturally and warmly: "Before we go any further — I want you to have this number. 988. Call or text, any time. No police show up, no consequences — just someone who gets it and wants to listen. Will you save it?"
- Ask if there's a trusted person nearby.
- Keep talking. Stay with them.

Using their data:
You have access to the user's actual logs — sleep, calories, spending, mood, streaks, tasks. Use it to make your responses genuinely personal.
- Spot patterns: "On the nights you get under 6 hours of sleep, you tend to go over budget that week — let's talk about that connection."
- Celebrate specifics: "Your sleep streak just hit 5 days — that's the longest you've had."
- Be their data translator: turn numbers into meaning they can actually act on.

What you are not:
- A replacement for a doctor, therapist, or financial advisor — but you're not going to hide behind that disclaimer to avoid helping.
- A rule enforcer.
- Fake-positive.
- Someone who gives up when the conversation gets real.

You might be the first person in someone's life who actually helped them figure this stuff out. Take that seriously.

Language guardrails — non-negotiable:
Never use phrases that imply endurance or survival in casual, non-crisis contexts. Avoid "made it through", "you survived", "getting through the day", "hanging in there", "another day down" and similar. These are unintentionally triggering to users who may be struggling. Keep greetings and check-ins forward-looking and practical — about what is ahead, not what was endured.
''';

  static String _buildSystemPrompt(Map<String, dynamic>? context) {
    if (context == null || context.isEmpty) return _baseSystemPrompt;

    final buf = StringBuffer(_baseSystemPrompt);
    buf.writeln(
      '\n---\nCurrent user context (use this to personalize every response):\n',
    );

    // Goals
    final goals = <String>[];
    if (context['lose_weight'] == true) goals.add('lose weight');
    if (context['build_muscle'] == true) goals.add('build muscle');
    if (context['improve_nutrition'] == true) goals.add('improve nutrition');
    if (context['improve_sleep'] == true) goals.add('improve sleep');
    if (context['improve_mental_health'] == true)
      goals.add('improve mental health');
    if (context['build_healthier_habits'] == true)
      goals.add('build healthier habits');
    if (context['save_money'] == true) goals.add('save money');
    if (context['build_wealth'] == true) goals.add('build wealth');
    if (goals.isNotEmpty) buf.writeln('Goals: ${goals.join(', ')}');
    final challenges = context['mindset_challenges'] as List? ?? const [];
    final firstToSuffer =
        context['mindset_first_to_suffer'] as List? ?? const [];
    if (challenges.isNotEmpty)
      buf.writeln('Current challenges: ${challenges.join(', ')}');
    if (firstToSuffer.isNotEmpty)
      buf.writeln(
        'Areas that slip first under stress: ${firstToSuffer.join(', ')}',
      );

    // Sleep
    final sleepStreak = context['sleep_streak'] as int?;
    final avgSleep = context['avg_sleep_7d'] as double?;
    final loggedSleepToday = context['logged_sleep_today'] as bool? ?? false;
    if (sleepStreak != null)
      buf.writeln(
        'Sleep streak: $sleepStreak day${sleepStreak == 1 ? '' : 's'}',
      );
    if (avgSleep != null)
      buf.writeln(
        'Avg sleep (last 7 days): ${avgSleep.toStringAsFixed(1)} hrs',
      );
    buf.writeln('Logged sleep today: ${loggedSleepToday ? 'yes' : 'not yet'}');

    // Nutrition
    final calsToday = context['calories_today'] as int?;
    final calsGoal = context['calorie_goal'] as int?;
    if (calsToday != null) {
      buf.writeln(
        'Calories today: $calsToday${calsGoal != null ? ' / $calsGoal target' : ''}',
      );
    }

    // Finance
    final weeklyBudget = context['weekly_budget'] as double?;
    final weeklySpent = context['weekly_spent'] as double?;
    if (weeklyBudget != null && weeklySpent != null) {
      final left = weeklyBudget - weeklySpent;
      buf.writeln(
        'Weekly budget: \$${weeklySpent.toStringAsFixed(0)} spent of \$${weeklyBudget.toStringAsFixed(0)} (\$${left.toStringAsFixed(0)} remaining)',
      );
    }

    // Mood
    final mood = context['mood'] as String?;
    if (mood != null) {
      buf.writeln('Mood logged today: $mood');
      switch (mood.toLowerCase()) {
        case 'tired':
          buf.writeln(
            'Lead with low-effort support and offer help with rest or sleep.',
          );
          break;
        case 'mourning':
          buf.writeln(
            'Respond gently to grief. Offer space to talk; do not rush toward fixing or optimism.',
          );
          break;
        case 'anxious':
        case 'worried':
          buf.writeln(
            'Use calm, grounding language and offer one manageable next step.',
          );
          break;
        case 'lonely':
          buf.writeln(
            'Acknowledge loneliness and invite the user to share more without judgment.',
          );
          break;
        case 'overwhelmed':
          buf.writeln(
            'Keep suggestions brief and help reduce the next step to something small.',
          );
          break;
      }
    }

    // Tasks
    final tasksTotal = context['tasks_total'] as int?;
    final tasksDone = context['tasks_done'] as int?;
    if (tasksTotal != null) {
      buf.writeln('Tasks today: ${tasksDone ?? 0}/$tasksTotal completed');
    }

    return buf.toString();
  }

  static Future<String> generateInsight({
    required Map<String, dynamic> userContext,
  }) async {
    if (SupabaseService.currentUser == null)
      return 'One small step is enough to make today feel more manageable.';
    final hour = DateTime.now().hour;
    final timeLabel = hour < 12
        ? 'morning'
        : hour < 17
        ? 'afternoon'
        : hour < 21
        ? 'evening'
        : 'night';

    final contextLines = <String>[];
    if (userContext['mood'] != null)
      contextLines.add('mood: ${userContext['mood']}');
    if (userContext['calories_today'] != null) {
      final cal = userContext['calories_today'] as int;
      final goal = userContext['calorie_goal'] as int?;
      contextLines.add(
        'calories today: $cal${goal != null ? ' of $goal' : ''}',
      );
    }
    if (userContext['sleep_streak'] != null &&
        (userContext['sleep_streak'] as int) > 0) {
      contextLines.add('sleep streak: ${userContext['sleep_streak']} days');
    }
    if (userContext['avg_sleep_7d'] != null) {
      contextLines.add(
        'avg sleep: ${(userContext['avg_sleep_7d'] as double).toStringAsFixed(1)} hrs',
      );
    }
    final goals = <String>[];
    for (final k in [
      'lose_weight',
      'improve_sleep',
      'save_money',
      'improve_mental_health',
      'build_muscle',
    ]) {
      if (userContext[k] == true) goals.add(k.replaceAll('_', ' '));
    }
    if (goals.isNotEmpty) contextLines.add('goals: ${goals.join(', ')}');

    final contextStr = contextLines.isEmpty
        ? 'No user data yet.'
        : contextLines.join('. ');

    return _requestAi(
      system: _buildSystemPrompt(userContext),
      maxTokens: 80,
      messages: [
        {
          'role': 'user',
          'content':
              'Write a single warm 1-2 sentence home screen greeting for the user. '
              'It is currently $timeLabel. $contextStr '
              'Focus on what is ahead — food, energy, goals, or a simple warm hello. '
              'NEVER use phrases like "made it", "you survived", "getting through", "hanging in there", or any language that implies endurance or hardship. '
              'Keep it forward-looking, practical, and light. Under 30 words. No bullet points, no dashes.',
        },
      ],
    );
  }

  static Future<String> generateReflectionPrompt({
    required List<String> challenges,
  }) async {
    if (SupabaseService.currentUser == null)
      return challenges.isEmpty
          ? 'What is one thing you want to make a little easier this week?'
          : 'What would a kind, realistic next step look like for ${challenges.first}?';
    final challengeStr = challenges.isEmpty
        ? ''
        : 'The user is working on: ${challenges.join(', ')}.';
    return _requestAi(
      system: _baseSystemPrompt,
      maxTokens: 50,
      messages: [
        {
          'role': 'user',
          'content':
              'Write one short wellness journaling prompt, under 18 words. '
              '$challengeStr Open-ended, warm, grounded. '
              'No bullet points, no quotation marks, no em dashes.',
        },
      ],
    );
  }

  static Future<String> respondToReflection({
    required String prompt,
    required String userResponse,
  }) async {
    if (SupabaseService.currentUser == null)
      return 'Thanks for putting that into words. What you noticed matters, and you can take the next step at your own pace.';
    return _requestAi(
      system: _baseSystemPrompt,
      maxTokens: 120,
      messages: [
        {
          'role': 'user',
          'content':
              'I just answered a wellness journal prompt. Prompt: "$prompt". '
              'My response: "$userResponse". '
              'Reply in 2-3 warm, real sentences — like a trusted friend reacting. '
              'No bullet points, no em dashes.',
        },
      ],
    );
  }

  static Future<String> send({
    required List<ChatMessage> history,
    required String message,
    Map<String, dynamic>? userContext,
  }) async {
    if (SupabaseService.currentUser == null)
      return _demoReply(message, userContext ?? const {});
    return _requestAi(
      system: _buildSystemPrompt(userContext),
      maxTokens: 1024,
      messages: [
        ...history.map((m) => m.toApiJson()),
        {'role': 'user', 'content': message},
      ],
    );
  }

  static String _demoReply(String message, Map<String, dynamic> context) {
    final text = message.toLowerCase();
    if (text.contains('dinner') ||
        text.contains('recipe') ||
        text.contains('protein')) {
      return 'A simple option: a bowl with rotisserie chicken or seasoned beans, microwave rice, frozen vegetables, and salsa or Greek yogurt on top. It is filling, easy to customize, and you can swap in whatever is on sale. Want a short grocery list or a no-cook version?';
    }
    if (text.contains('budget') ||
        text.contains('money') ||
        text.contains('spend')) {
      return 'A budget is just a plan for where your money goes. Start with what comes in, subtract bills and basics, then give the rest a few jobs: food, getting around, savings, and fun. We can make the first version together with rough numbers.';
    }
    if (text.contains('appointment') ||
        text.contains('doctor') ||
        text.contains('clinic')) {
      return 'You can say: “Hi, I’m a new patient and I’d like to schedule an appointment for [reason]. What information do you need from me, and what might the visit cost?” Have your insurance card and a few dates handy. It is okay to ask them to slow down or explain anything.';
    }
    if (text.contains('routine') ||
        text.contains('plan') ||
        text.contains('today')) {
      return 'Let’s make it small enough to fit a real day. Choose one must-do, one thing that supports future-you, and one pause. What has to happen today, and when do you usually have the most energy?';
    }
    final goals = <String>[];
    if (context['lose_weight'] == true)
      goals.add('food that supports your goals');
    if (context['save_money'] == true)
      goals.add('keeping spending comfortable');
    if (context['improve_sleep'] == true) goals.add('a gentler wind-down');
    final focus = goals.isEmpty
        ? 'the thing on your mind'
        : goals.join(' and ');
    return 'I’m here to help make $focus feel less complicated. Tell me a little about what’s going on, and we’ll figure out one practical next step together.';
  }
}
