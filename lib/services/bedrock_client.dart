import 'dart:convert';

import 'package:aws_common/aws_common.dart';
import 'package:aws_signature_v4/aws_signature_v4.dart';

import '../config/env_config.dart';

/// Configuration for AWS Bedrock Runtime (Converse API).
class BedrockConfig {
  final String region;
  final String modelId;
  final String accessKeyId;
  final String secretAccessKey;
  final String? sessionToken;

  const BedrockConfig({
    required this.region,
    required this.modelId,
    required this.accessKeyId,
    required this.secretAccessKey,
    this.sessionToken,
  });

  bool get isConfigured =>
      region.isNotEmpty &&
      modelId.isNotEmpty &&
      accessKeyId.isNotEmpty &&
      secretAccessKey.isNotEmpty;

  /// Priority: `--dart-define` > `.env` > defaults (no secrets in source).
  static BedrockConfig fromEnvironment() {
    const define = String.fromEnvironment;

    String pick(String defineKey, String envKey, String fallback) {
      final fromDefine = define(defineKey);
      if (fromDefine.isNotEmpty) return fromDefine;
      return EnvConfig.get(envKey) ?? fallback;
    }

    final sessionFromDefine = define('AWS_SESSION_TOKEN');
    final sessionFromEnv = EnvConfig.get('AWS_SESSION_TOKEN');

    return BedrockConfig(
      region: pick('AWS_REGION', 'AWS_REGION', 'us-east-1'),
      modelId: pick(
        'BEDROCK_MODEL_ID',
        'BEDROCK_MODEL_ID',
        'anthropic.claude-3-5-sonnet-20240620-v2:0',
      ),
      accessKeyId: pick('AWS_ACCESS_KEY_ID', 'AWS_ACCESS_KEY_ID', ''),
      secretAccessKey: pick('AWS_SECRET_ACCESS_KEY', 'AWS_SECRET_ACCESS_KEY', ''),
      sessionToken: sessionFromDefine.isNotEmpty
          ? sessionFromDefine
          : sessionFromEnv,
    );
  }
}

/// Signed HTTP client for Amazon Bedrock Runtime Converse API.
class BedrockClient {
  BedrockClient({required this.config});

  final BedrockConfig config;

  static String _encodeModelPath(String modelId) =>
      modelId.replaceAll(':', '%3A');

  Uri _converseUri() {
    final encodedModel = _encodeModelPath(config.modelId);
    return Uri.https(
      'bedrock-runtime.${config.region}.amazonaws.com',
      '/model/$encodedModel/converse',
    );
  }

  AWSSigV4Signer _signer() {
    return AWSSigV4Signer(
      credentialsProvider: AWSCredentialsProvider(
        AWSCredentials(
          config.accessKeyId,
          config.secretAccessKey,
          config.sessionToken,
        ),
      ),
    );
  }

  /// Sends a Converse request and returns assistant text.
  Future<String> converse({
    required String systemPrompt,
    required String userMessage,
    double temperature = 0.3,
    int maxTokens = 2048,
  }) async {
    if (!config.isConfigured) {
      throw Exception(
        'AWS Bedrock is not configured. Set credentials in Settings or '
        'pass --dart-define=AWS_ACCESS_KEY_ID=... --dart-define=AWS_SECRET_ACCESS_KEY=...',
      );
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

    final signedRequest = await _signer().sign(
      request,
      credentialScope: AWSCredentialScope(
        region: config.region,
        service: const AWSService('bedrock'),
      ),
      serviceConfiguration: S3ServiceConfiguration(),
    );

    final response = await signedRequest.send().response.timeout(
      const Duration(seconds: 120),
      onTimeout: () => throw Exception('Bedrock request timeout'),
    );
    final responseBody = await response.decodeBody();

    if (response.statusCode != 200) {
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
}
