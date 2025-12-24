import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiService {
  static final GeminiService _instance = GeminiService._internal();
  factory GeminiService() => _instance;
  GeminiService._internal();

  late final GenerativeModel _model;

  void init() {
    final apiKey = dotenv.env['GEMINI_API_KEY']!;
    if (apiKey.isEmpty) {
      throw Exception('GEMINI_API_KEY not found or empty');
    }

    _model = GenerativeModel(
      model: 'gemini-2.5-flash', // ← Model mới nhất miễn phí tốt
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.7,
        topK: 40,
        topP: 0.95,
        maxOutputTokens: 4096, // Model mới hỗ trợ nhiều hơn
      ),
    );
  }

  Future<GenerateContentResponse> generateContent(String prompt) async {
    return await _model.generateContent([Content.text(prompt)]);
  }

  Stream<GenerateContentResponse> streamContent(String prompt) async* {
    final response = _model.generateContentStream([Content.text(prompt)]);
    await for (final chunk in response) {
      yield chunk;
    }
  }
}
