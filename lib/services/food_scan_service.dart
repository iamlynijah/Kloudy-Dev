import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class FoodScanResult {
  final String name;
  final int calories;
  final double protein;
  final double carbs;
  final double fat;
  final String serving;

  const FoodScanResult({
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.serving,
  });

  FoodScanResult scaled(double quantity) => FoodScanResult(
        name: name,
        calories: (calories * quantity).round(),
        protein: protein * quantity,
        carbs: carbs * quantity,
        fat: fat * quantity,
        serving: serving,
      );
}

class FoodScanService {
  static Future<FoodScanResult?> analyzeImage(Uint8List imageBytes) async {
    final base64Image = base64Encode(imageBytes);
    final response = await http.post(
      Uri.parse('https://api.anthropic.com/v1/messages'),
      headers: {
        'x-api-key': kAnthropicApiKey,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
      },
      body: jsonEncode({
        'model': 'claude-haiku-4-5-20251001',
        'max_tokens': 256,
        'messages': [
          {
            'role': 'user',
            'content': [
              {
                'type': 'image',
                'source': {
                  'type': 'base64',
                  'media_type': 'image/jpeg',
                  'data': base64Image,
                },
              },
              {
                'type': 'text',
                'text':
                    'Identify the food in this image and estimate nutrition for the portion shown.\n\nReturn ONLY a JSON object — no other text:\n{"name":"food name","calories":0,"protein":0.0,"carbs":0.0,"fat":0.0,"serving":"portion description"}\n\nServing examples: "1 cup", "medium portion", "2 slices (~4 oz)", "1 banana (118g)"\n\nIf food cannot be identified clearly, return: {"error":"unrecognized"}',
              },
            ],
          },
        ],
      }),
    );

    if (response.statusCode != 200) return null;
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final content = (data['content'] as List?)?.firstOrNull;
    if (content == null) return null;
    return _parseJson(content['text'] as String? ?? '');
  }

  static Future<FoodScanResult?> lookupBarcode(String barcode) async {
    final response = await http.get(
      Uri.parse(
        'https://world.openfoodfacts.org/api/v2/product/$barcode.json'
        '?fields=product_name,nutriments,serving_size',
      ),
      headers: {'User-Agent': 'Kloudy/1.0 (lynijahr@gmail.com)'},
    );

    if (response.statusCode != 200) return null;
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if ((data['status'] as int? ?? 0) != 1) return null;

    final product = data['product'] as Map<String, dynamic>? ?? {};
    final name = (product['product_name'] as String?)?.trim();
    if (name == null || name.isEmpty) return null;

    final n = product['nutriments'] as Map<String, dynamic>? ?? {};
    final calories =
        (n['energy-kcal_serving'] ?? n['energy-kcal_100g'] ?? 0) as num;
    if (calories == 0) return null;

    return FoodScanResult(
      name: name,
      calories: calories.toInt(),
      protein: ((n['proteins_serving'] ?? n['proteins_100g'] ?? 0) as num)
          .toDouble(),
      carbs:
          ((n['carbohydrates_serving'] ?? n['carbohydrates_100g'] ?? 0) as num)
              .toDouble(),
      fat: ((n['fat_serving'] ?? n['fat_100g'] ?? 0) as num).toDouble(),
      serving: (product['serving_size'] as String?)?.trim() ?? '1 serving',
    );
  }

  static FoodScanResult? _parseJson(String text) {
    text = text.replaceAll(RegExp(r'```[a-z]*\n?'), '').trim();
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    try {
      final j = jsonDecode(text.substring(start, end + 1)) as Map<String, dynamic>;
      if (j['error'] != null) return null;
      return FoodScanResult(
        name: j['name'] as String? ?? 'Unknown food',
        calories: (j['calories'] as num? ?? 0).toInt(),
        protein: (j['protein'] as num? ?? 0).toDouble(),
        carbs: (j['carbs'] as num? ?? 0).toDouble(),
        fat: (j['fat'] as num? ?? 0).toDouble(),
        serving: j['serving'] as String? ?? '1 serving',
      );
    } catch (_) {
      return null;
    }
  }
}
