import 'dart:convert';

import 'package:aws_common/aws_common.dart';
import 'package:aws_signature_v4/aws_signature_v4.dart';

import '../config/env_config.dart';
import 'logger_service.dart';

/// Thrown when [BedrockClient.embed] or [BedrockClient.converse] is called
/// but AWS credentials are not configured.
///
/// [VaultIndexService] catches this typed exception to activate the BM25
/// keyword-search fallback path (Phase 3).
class BedrockUnconfiguredException implements Exception {
  const BedrockUnconfiguredException([
    this.message = 'AWS Bedrock is not configured. '
        'Import .env in Settings or set AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY.',
  ]);

  final String message;

  @override
  String toString() => 'BedrockUnconfiguredException: $message';
}

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

  factory BedrockConfig.sanitized({
    required String region,
    required String modelId,
    required String accessKeyId,
    required String secretAccessKey,
    String? sessionToken,
  }) {
    return BedrockConfig(
      region: region.trim(),
      modelId: modelId.trim(),
      accessKeyId: accessKeyId.trim(),
      secretAccessKey: secretAccessKey.trim(),
      sessionToken: sessionToken?.trim().isEmpty == true
          ? null
          : sessionToken?.trim(),
    );
  }

  bool get isConfigured =>
      region.isNotEmpty &&
      modelId.isNotEmpty &&
      accessKeyId.isNotEmpty &&
      secretAccessKey.isNotEmpty;

  /// Priority: `--dart-define` > `.env` > defaults (no secrets in source).
  static BedrockConfig fromEnvironment() {
    const regionDefine = String.fromEnvironment('AWS_REGION');
    const modelIdDefine = String.fromEnvironment('BEDROCK_MODEL_ID');
    const accessKeyDefine = String.fromEnvironment('AWS_ACCESS_KEY_ID');
    const secretKeyDefine = String.fromEnvironment('AWS_SECRET_ACCESS_KEY');
    const sessionTokenDefine = String.fromEnvironment('AWS_SESSION_TOKEN');

    return BedrockConfig.sanitized(
      region: regionDefine.isNotEmpty
          ? regionDefine
          : (EnvConfig.get('AWS_REGION') ?? 'us-east-1'),
      modelId: modelIdDefine.isNotEmpty
          ? modelIdDefine
          : (EnvConfig.get('BEDROCK_MODEL_ID') ??
              'anthropic.claude-3-5-sonnet-20240620-v2:0'),
      accessKeyId: accessKeyDefine.isNotEmpty
          ? accessKeyDefine
          : (EnvConfig.get('AWS_ACCESS_KEY_ID') ?? ''),
      secretAccessKey: secretKeyDefine.isNotEmpty
          ? secretKeyDefine
          : (EnvConfig.get('AWS_SECRET_ACCESS_KEY') ?? ''),
      sessionToken: sessionTokenDefine.isNotEmpty
          ? sessionTokenDefine
          : EnvConfig.get('AWS_SESSION_TOKEN'),
    );
  }
}

/// Signed HTTP client for Amazon Bedrock Runtime Converse API.
class BedrockClient {
  BedrockClient({required this.config});

  final BedrockConfig config;

  /// Model id stays raw in the URL path (`:0`). Signer encodes once for SigV4.
  Uri _converseUri() {
    return Uri.parse(
      'https://bedrock-runtime.${config.region}.amazonaws.com'
      '/model/${config.modelId}/converse',
    );
  }

  /// InvokeModel endpoint for Titan embeddings (and any non-Converse model).
  Uri _invokeUri(String modelId) {
    return Uri.parse(
      'https://bedrock-runtime.${config.region}.amazonaws.com'
      '/model/$modelId/invoke',
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

    final signedRequest = await _signer().sign(
      request,
      credentialScope: AWSCredentialScope(
        region: config.region,
        service: const AWSService('bedrock'),
      ),
      serviceConfiguration: const BaseServiceConfiguration(),
    );

    final response = await signedRequest.send().response.timeout(
      const Duration(seconds: 120),
      onTimeout: () => throw Exception('Bedrock request timeout'),
    );
    final responseBody = await response.decodeBody();

    if (response.statusCode != 200) {
      AppLogger.log(
        'Bedrock HTTP error ${response.statusCode}',
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

  /// Embeds [text] using the Titan Embeddings V2 model via InvokeModel.
  ///
  /// Returns exactly 1024 unit-normalised float values suitable for
  /// cosine-similarity search (dot product of two unit vectors).
  ///
  /// Throws [BedrockUnconfiguredException] when AWS credentials are absent.
  /// IMPORTANT: call this method DIRECTLY from [VaultIndexService] — do not
  /// route through api_service.dart wrappers, which catch and re-wrap all
  /// exceptions as generic [Exception], destroying the typed error needed to
  /// trigger the BM25 keyword-search fallback (Phase 3).
  Future<List<double>> embed(String text) async {
    if (!config.isConfigured) {
      throw const BedrockUnconfiguredException();
    }

    // Read embed model ID from .env; fall back to Titan Embeddings V2.
    final embedModelId =
        EnvConfig.get('BEDROCK_EMBED_MODEL_ID') ?? 'amazon.titan-embed-text-v2:0';

    final body = jsonEncode({
      'inputText': text,
      'dimensions': 1024,
      'normalize': true,
    });

    final request = AWSHttpRequest(
      method: AWSHttpMethod.post,
      uri: _invokeUri(embedModelId),
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
      serviceConfiguration: const BaseServiceConfiguration(),
    );

    final response = await signedRequest.send().response.timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw Exception('Bedrock embed request timeout'),
    );
    final responseBody = await response.decodeBody();

    if (response.statusCode != 200) {
      AppLogger.log(
        'Bedrock embed HTTP error ${response.statusCode}',
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
    // Titan may return integer-valued coefficients (e.g. 0 or 1); use num
    // promotion instead of a lazy cast<double>() that throws TypeError lazily.
    if (raw.length != 1024) {
      throw Exception(
        'Bedrock embed: expected 1024 dimensions, got ${raw.length}. '
        'Check BEDROCK_EMBED_MODEL_ID — model must support dimensions=1024.',
      );
    }
    return raw.map((e) => (e as num).toDouble()).toList();
  }
}
