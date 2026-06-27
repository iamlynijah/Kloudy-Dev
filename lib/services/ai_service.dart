import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/chat_message.dart';

class AiService {
  static const _url = 'https://api.anthropic.com/v1/messages';
  static const _model = 'claude-sonnet-4-6';

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
    buf.writeln('\n---\nCurrent user context (use this to personalize every response):\n');

    // Goals
    final goals = <String>[];
    if (context['lose_weight'] == true) goals.add('lose weight');
    if (context['build_muscle'] == true) goals.add('build muscle');
    if (context['improve_nutrition'] == true) goals.add('improve nutrition');
    if (context['improve_sleep'] == true) goals.add('improve sleep');
    if (context['improve_mental_health'] == true) goals.add('improve mental health');
    if (context['build_healthier_habits'] == true) goals.add('build healthier habits');
    if (context['save_money'] == true) goals.add('save money');
    if (context['build_wealth'] == true) goals.add('build wealth');
    if (goals.isNotEmpty) buf.writeln('Goals: ${goals.join(', ')}');

    // Sleep
    final sleepStreak = context['sleep_streak'] as int?;
    final avgSleep = context['avg_sleep_7d'] as double?;
    final loggedSleepToday = context['logged_sleep_today'] as bool? ?? false;
    if (sleepStreak != null) buf.writeln('Sleep streak: $sleepStreak day${sleepStreak == 1 ? '' : 's'}');
    if (avgSleep != null) buf.writeln('Avg sleep (last 7 days): ${avgSleep.toStringAsFixed(1)} hrs');
    buf.writeln('Logged sleep today: ${loggedSleepToday ? 'yes' : 'not yet'}');

    // Nutrition
    final calsToday = context['calories_today'] as int?;
    final calsGoal = context['calorie_goal'] as int?;
    if (calsToday != null) {
      buf.writeln('Calories today: $calsToday${calsGoal != null ? ' / $calsGoal target' : ''}');
    }

    // Finance
    final weeklyBudget = context['weekly_budget'] as double?;
    final weeklySpent = context['weekly_spent'] as double?;
    if (weeklyBudget != null && weeklySpent != null) {
      final left = weeklyBudget - weeklySpent;
      buf.writeln('Weekly budget: \$${weeklySpent.toStringAsFixed(0)} spent of \$${weeklyBudget.toStringAsFixed(0)} (\$${left.toStringAsFixed(0)} remaining)');
    }

    // Mood
    final mood = context['mood'] as String?;
    if (mood != null) buf.writeln('Mood logged today: $mood');

    // Tasks
    final tasksTotal = context['tasks_total'] as int?;
    final tasksDone = context['tasks_done'] as int?;
    if (tasksTotal != null) {
      buf.writeln('Tasks today: ${tasksDone ?? 0}/$tasksTotal completed');
    }

    return buf.toString();
  }

  static Future<String> generateInsight({
    required String apiKey,
    required Map<String, dynamic> userContext,
  }) async {
    final hour = DateTime.now().hour;
    final timeLabel = hour < 12
        ? 'morning'
        : hour < 17
            ? 'afternoon'
            : hour < 21
                ? 'evening'
                : 'night';

    final contextLines = <String>[];
    if (userContext['mood'] != null) contextLines.add('mood: ${userContext['mood']}');
    if (userContext['calories_today'] != null) {
      final cal = userContext['calories_today'] as int;
      final goal = userContext['calorie_goal'] as int?;
      contextLines.add('calories today: $cal${goal != null ? ' of $goal' : ''}');
    }
    if (userContext['sleep_streak'] != null && (userContext['sleep_streak'] as int) > 0) {
      contextLines.add('sleep streak: ${userContext['sleep_streak']} days');
    }
    if (userContext['avg_sleep_7d'] != null) {
      contextLines.add('avg sleep: ${(userContext['avg_sleep_7d'] as double).toStringAsFixed(1)} hrs');
    }
    final goals = <String>[];
    for (final k in ['lose_weight', 'improve_sleep', 'save_money', 'improve_mental_health', 'build_muscle']) {
      if (userContext[k] == true) goals.add(k.replaceAll('_', ' '));
    }
    if (goals.isNotEmpty) contextLines.add('goals: ${goals.join(', ')}');

    final contextStr = contextLines.isEmpty
        ? 'No user data yet.'
        : contextLines.join('. ');

    final response = await http.post(
      Uri.parse(_url),
      headers: {
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
      },
      body: jsonEncode({
        'model': _model,
        'max_tokens': 80,
        'system': _baseSystemPrompt,
        'messages': [
          {
            'role': 'user',
            'content': 'Write a single warm 1-2 sentence home screen greeting for the user. '
                'It is currently $timeLabel. $contextStr '
                'Focus on what is ahead — food, energy, goals, or a simple warm hello. '
                'NEVER use phrases like "made it", "you survived", "getting through", "hanging in there", or any language that implies endurance or hardship. '
                'Keep it forward-looking, practical, and light. Under 30 words. No bullet points, no dashes.',
          }
        ],
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final content = data['content'] as List<dynamic>;
      return (content.first as Map<String, dynamic>)['text'] as String;
    }
    throw Exception('${response.statusCode}');
  }

  static Future<String> generateReflectionPrompt({
    required String apiKey,
    required List<String> challenges,
  }) async {
    final challengeStr = challenges.isEmpty
        ? ''
        : 'The user is working on: ${challenges.join(', ')}.';
    final response = await http.post(
      Uri.parse(_url),
      headers: {
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
      },
      body: jsonEncode({
        'model': _model,
        'max_tokens': 50,
        'system': _baseSystemPrompt,
        'messages': [
          {
            'role': 'user',
            'content':
                'Write one short wellness journaling prompt, under 18 words. '
                '$challengeStr Open-ended, warm, grounded. '
                'No bullet points, no quotation marks, no em dashes.',
          }
        ],
      }),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final content = data['content'] as List<dynamic>;
      return (content.first as Map<String, dynamic>)['text'] as String;
    }
    throw Exception('${response.statusCode}');
  }

  static Future<String> respondToReflection({
    required String apiKey,
    required String prompt,
    required String userResponse,
  }) async {
    final response = await http.post(
      Uri.parse(_url),
      headers: {
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
      },
      body: jsonEncode({
        'model': _model,
        'max_tokens': 120,
        'system': _baseSystemPrompt,
        'messages': [
          {
            'role': 'user',
            'content':
                'I just answered a wellness journal prompt. Prompt: "$prompt". '
                'My response: "$userResponse". '
                'Reply in 2-3 warm, real sentences — like a trusted friend reacting. '
                'No bullet points, no em dashes.',
          }
        ],
      }),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final content = data['content'] as List<dynamic>;
      return (content.first as Map<String, dynamic>)['text'] as String;
    }
    throw Exception('${response.statusCode}');
  }

  static Future<String> send({
    required String apiKey,
    required List<ChatMessage> history,
    required String message,
    Map<String, dynamic>? userContext,
  }) async {
    final response = await http.post(
      Uri.parse(_url),
      headers: {
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
      },
      body: jsonEncode({
        'model': _model,
        'max_tokens': 1024,
        'system': _buildSystemPrompt(userContext),
        'messages': [
          ...history.map((m) => m.toApiJson()),
          {'role': 'user', 'content': message},
        ],
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final content = data['content'] as List<dynamic>;
      return (content.first as Map<String, dynamic>)['text'] as String;
    }

    throw Exception('Kloudy is unavailable right now (${response.statusCode}). Try again in a moment.');
  }
}
