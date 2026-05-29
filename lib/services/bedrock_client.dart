import 'dart:convert';

import 'package:aws_common/aws_common.dart';
import 'package:aws_signature_v4/aws_signature_v4.dart';

import '../config/env_config.dart';
import 'logger_service.dart';

class BedrockUnconfiguredException implements Exception {
  const BedrockUnconfiguredException([
    this.message =
        'AWS Bedrock is not configured. '
        'Import .env in Settings or set AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY.',
  ]);

  final String message;

  @override
  String toString() => 'BedrockUnconfiguredException: $message';
}

class BedrockTextModel {
  const BedrockTextModel({required this.modelId});

  final String modelId;

  static const String _defaultModelId = 'google.gemma-3-4b-it';

  static BedrockTextModel fromEnvironment() {
    const define = String.fromEnvironment('BEDROCK_TEXT_MODEL_ID');
    final id = define.isNotEmpty
        ? define
        : (EnvConfig.get('BEDROCK_TEXT_MODEL_ID') ?? _defaultModelId);
    return BedrockTextModel(modelId: id.trim());
  }

  bool get isSet => modelId.isNotEmpty;

  @override
  String toString() => 'BedrockTextModel($modelId)';
}

class BedrockEmbedModel {
  const BedrockEmbedModel({required this.modelId, this.dimensions = 1024});

  final String modelId;

  final int dimensions;

  static const String _defaultModelId = 'amazon.titan-embed-text-v2:0';

  static BedrockEmbedModel fromEnvironment() {
    const define = String.fromEnvironment('BEDROCK_EMBED_MODEL_ID');
    final id = define.isNotEmpty
        ? define
        : (EnvConfig.get('BEDROCK_EMBED_MODEL_ID') ?? _defaultModelId);
    return BedrockEmbedModel(modelId: id.trim()); // key unchanged
  }

  bool get isSet => modelId.isNotEmpty;

  @override
  String toString() => 'BedrockEmbedModel($modelId, ${dimensions}d)';
}

class BedrockConfig {
  const BedrockConfig({
    required this.region,
    required this.textModel,
    required this.embedModel,
    required this.accessKeyId,
    required this.secretAccessKey,
    this.sessionToken,
  });

  final String region;

  final BedrockTextModel textModel;

  final BedrockEmbedModel embedModel;

  final String accessKeyId;
  final String secretAccessKey;
  final String? sessionToken;

  bool get isConfigured =>
      region.isNotEmpty &&
      textModel.isSet &&
      embedModel.isSet &&
      accessKeyId.isNotEmpty &&
      secretAccessKey.isNotEmpty;

  static BedrockConfig fromEnvironment() {
    const regionDefine = String.fromEnvironment('AWS_REGION');
    const accessKeyDefine = String.fromEnvironment('AWS_ACCESS_KEY_ID');
    const secretKeyDefine = String.fromEnvironment('AWS_SECRET_ACCESS_KEY');
    const sessionTokenDefine = String.fromEnvironment('AWS_SESSION_TOKEN');

    final sessionToken = sessionTokenDefine.isNotEmpty
        ? sessionTokenDefine
        : EnvConfig.get('AWS_SESSION_TOKEN');

    return BedrockConfig(
      region: regionDefine.isNotEmpty
          ? regionDefine
          : (EnvConfig.get('AWS_REGION') ?? 'us-east-1'),
      textModel: BedrockTextModel.fromEnvironment(),
      embedModel: BedrockEmbedModel.fromEnvironment(),
      accessKeyId: accessKeyDefine.isNotEmpty
          ? accessKeyDefine
          : (EnvConfig.get('AWS_ACCESS_KEY_ID') ?? ''),
      secretAccessKey: secretKeyDefine.isNotEmpty
          ? secretKeyDefine
          : (EnvConfig.get('AWS_SECRET_ACCESS_KEY') ?? ''),
      sessionToken: sessionToken?.trim().isEmpty == true
          ? null
          : sessionToken?.trim(),
    );
  }
}

class BedrockClient {
  BedrockClient({required this.config});

  final BedrockConfig config;

  static String _encodedModelId(String modelId) => Uri.encodeComponent(modelId);

  Uri _converseUri() => Uri.parse(
    'https://bedrock-runtime.${config.region}.amazonaws.com'
    '/model/${_encodedModelId(config.textModel.modelId)}/converse',
  );

  Uri _invokeUri(String modelId) => Uri.parse(
    'https://bedrock-runtime.${config.region}.amazonaws.com'
    '/model/${_encodedModelId(modelId)}/invoke',
  );

  AWSSigV4Signer _signer() => AWSSigV4Signer(
    credentialsProvider: AWSCredentialsProvider(
      AWSCredentials(
        config.accessKeyId,
        config.secretAccessKey,
        config.sessionToken,
      ),
    ),
  );

  AWSCredentialScope get _scope => AWSCredentialScope(
    region: config.region,
    service: const AWSService('bedrock'),
  );

  Future<String> converse({
    required String systemPrompt,
    required String userMessage,
    double temperature = 0.3,
    int maxTokens = 2048,
  }) async {
    if (!config.isConfigured) {
      throw const BedrockUnconfiguredException();
    }

    final body = jsonEncode({
      'system': [
        {'text': systemPrompt},
      ],
      'messages': [
        {
          'role': 'user',
          'content': [
            {'text': userMessage},
          ],
        },
      ],
      'inferenceConfig': {'maxTokens': maxTokens, 'temperature': temperature},
    });

    final request = AWSHttpRequest(
      method: AWSHttpMethod.post,
      uri: _converseUri(),
      headers: {
        AWSHeaders.contentType: 'application/json',
        AWSHeaders.accept: 'application/json',
      },
      body: utf8.encode(body),
    );

    final signed = await _signer().sign(
      request,
      credentialScope: _scope,
      serviceConfiguration: const BaseServiceConfiguration(),
    );

    final response = await signed.send().response.timeout(
      const Duration(seconds: 120),
      onTimeout: () => throw Exception('Bedrock converse request timeout'),
    );
    final responseBody = await response.decodeBody();

    if (response.statusCode != 200) {
      AppLogger.log(
        'Bedrock converse HTTP ${response.statusCode}',
        category: LogCategory.network,
        error: responseBody,
      );
      throw Exception('Bedrock error ${response.statusCode}: $responseBody');
    }

    return _extractAssistantText(responseBody);
  }

  static String _extractAssistantText(String responseBody) {
    final data = jsonDecode(responseBody) as Map<String, dynamic>;
    final output = data['output'] as Map<String, dynamic>?;
    final message = output?['message'] as Map<String, dynamic>?;
    final content = message?['content'] as List<dynamic>? ?? [];

    for (final block in content) {
      if (block is Map<String, dynamic>) {
        final text = block['text'] as String?;
        if (text != null && text.isNotEmpty) return text.trim();
      }
    }

    throw Exception('Bedrock returned no text content');
  }

  Future<List<double>> embed(String text) async {
    if (!config.isConfigured) {
      throw const BedrockUnconfiguredException();
    }

    final embedModel = config.embedModel;

    final body = jsonEncode({
      'inputText': text,
      'dimensions': embedModel.dimensions,
      'normalize': true,
    });

    final request = AWSHttpRequest(
      method: AWSHttpMethod.post,
      uri: _invokeUri(embedModel.modelId),
      headers: {
        AWSHeaders.contentType: 'application/json',
        AWSHeaders.accept: 'application/json',
      },
      body: utf8.encode(body),
    );

    final signed = await _signer().sign(
      request,
      credentialScope: _scope,
      serviceConfiguration: const BaseServiceConfiguration(),
    );

    final response = await signed.send().response.timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw Exception('Bedrock embed request timeout'),
    );
    final responseBody = await response.decodeBody();

    if (response.statusCode != 200) {
      AppLogger.log(
        'Bedrock embed HTTP ${response.statusCode}',
        category: LogCategory.network,
        error: responseBody,
      );
      throw Exception(
        'Bedrock embed error ${response.statusCode}: $responseBody',
      );
    }

    final data = jsonDecode(responseBody) as Map<String, dynamic>;
    final raw = data['embedding'] as List<dynamic>?;
    if (raw == null || raw.isEmpty) {
      throw Exception('Bedrock embed returned no embedding vector');
    }
    if (raw.length != embedModel.dimensions) {
      throw Exception(
        'Bedrock embed: expected ${embedModel.dimensions} dimensions, '
        'got ${raw.length}. Check BEDROCK_EMBED_MODEL_ID.',
      );
    }
    // Use (e as num).toDouble() — Titan may return integer-valued coefficients.
    return raw.map((e) => (e as num).toDouble()).toList();
  }
}
