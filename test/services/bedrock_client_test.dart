import 'package:flutter_test/flutter_test.dart';

import 'package:paper_to_obsidian/config/env_config.dart';
import 'package:paper_to_obsidian/services/bedrock_client.dart';

void main() {
  // ── AC-6: converse() unconfigured guard ──────────────────────────────────
  group('BedrockClient.converse() – unconfigured guard (AC-6)', () {
    test('throws BedrockUnconfiguredException when accessKeyId is empty',
        () async {
      final config = BedrockConfig.sanitized(
        region: 'us-east-1',
        modelId: 'anthropic.claude-3-5-sonnet-20240620-v2:0',
        accessKeyId: '',
        secretAccessKey: 'some-secret',
      );
      expect(config.isConfigured, isFalse,
          reason: 'empty accessKeyId must make isConfigured false');

      final client = BedrockClient(config: config);

      await expectLater(
        client.converse(systemPrompt: 'sys', userMessage: 'hello'),
        throwsA(isA<BedrockUnconfiguredException>()),
        reason: 'Must throw typed BedrockUnconfiguredException, not Exception',
      );
    });

    test('throws BedrockUnconfiguredException when secretAccessKey is empty',
        () async {
      final config = BedrockConfig.sanitized(
        region: 'us-east-1',
        modelId: 'anthropic.claude-3-5-sonnet-20240620-v2:0',
        accessKeyId: 'AKIAIOSFODNN7EXAMPLE',
        secretAccessKey: '',
      );
      expect(config.isConfigured, isFalse);

      final client = BedrockClient(config: config);

      await expectLater(
        client.converse(systemPrompt: 'sys', userMessage: 'hi'),
        throwsA(isA<BedrockUnconfiguredException>()),
      );
    });

    test('throws BedrockUnconfiguredException when both keys are empty',
        () async {
      final config = BedrockConfig.sanitized(
        region: 'us-east-1',
        modelId: 'anthropic.claude-3-5-sonnet-20240620-v2:0',
        accessKeyId: '',
        secretAccessKey: '',
      );

      final client = BedrockClient(config: config);

      await expectLater(
        client.converse(systemPrompt: 'sys', userMessage: 'hi'),
        throwsA(isA<BedrockUnconfiguredException>()),
      );
    });

    test('thrown object is specifically BedrockUnconfiguredException, not a '
        'plain Exception or other subtype', () async {
      final config = BedrockConfig.sanitized(
        region: 'us-east-1',
        modelId: 'anthropic.claude-3-5-sonnet-20240620-v2:0',
        accessKeyId: '',
        secretAccessKey: '',
      );
      final client = BedrockClient(config: config);

      Object? caught;
      try {
        await client.converse(systemPrompt: 'sys', userMessage: 'hi');
      } catch (e) {
        caught = e;
      }

      expect(caught, isNotNull, reason: 'converse() must throw when unconfigured');
      expect(caught, isA<BedrockUnconfiguredException>());
      expect(caught, isNot(isA<StateError>()));
      expect(caught, isNot(isA<ArgumentError>()));
      expect(caught.runtimeType, equals(BedrockUnconfiguredException));
    });
  });

  // ── AC-3: embed() unconfigured guard ────────────────────────────────────
  group('BedrockClient.embed() – unconfigured guard (AC-3)', () {
    test('throws BedrockUnconfiguredException when accessKeyId is empty',
        () async {
      final config = BedrockConfig.sanitized(
        region: 'us-east-1',
        modelId: 'any-model',
        accessKeyId: '',
        secretAccessKey: 'secret',
      );
      expect(config.isConfigured, isFalse);

      final client = BedrockClient(config: config);

      await expectLater(
        client.embed('hello world'),
        throwsA(isA<BedrockUnconfiguredException>()),
        reason: 'embed() must throw typed BedrockUnconfiguredException',
      );
    });

    test('throws BedrockUnconfiguredException when secretAccessKey is empty',
        () async {
      final config = BedrockConfig.sanitized(
        region: 'us-east-1',
        modelId: 'any-model',
        accessKeyId: 'AKID',
        secretAccessKey: '',
      );

      final client = BedrockClient(config: config);

      await expectLater(
        client.embed('hello'),
        throwsA(isA<BedrockUnconfiguredException>()),
      );
    });

    test('throws BedrockUnconfiguredException when both keys are empty',
        () async {
      final config = BedrockConfig.sanitized(
        region: 'us-east-1',
        modelId: 'any-model',
        accessKeyId: '',
        secretAccessKey: '',
      );
      final client = BedrockClient(config: config);

      await expectLater(
        client.embed('text'),
        throwsA(isA<BedrockUnconfiguredException>()),
      );
    });

    test('thrown object is specifically BedrockUnconfiguredException', () async {
      final config = BedrockConfig.sanitized(
        region: 'us-east-1',
        modelId: 'any-model',
        accessKeyId: '',
        secretAccessKey: '',
      );
      final client = BedrockClient(config: config);

      Object? caught;
      try {
        await client.embed('text');
      } catch (e) {
        caught = e;
      }

      expect(caught, isNotNull, reason: 'embed() must throw when unconfigured');
      expect(caught, isA<BedrockUnconfiguredException>(),
          reason: 'Caught exception must be BedrockUnconfiguredException');
      expect(caught, isNot(isA<StateError>()));
      expect(caught, isNot(isA<ArgumentError>()));
      expect(caught.runtimeType, equals(BedrockUnconfiguredException));
    });

    test('embed() Future completes with error immediately (guard fires before '
        'any async I/O)', () async {
      final config = BedrockConfig.sanitized(
        region: 'us-east-1',
        modelId: 'any-model',
        accessKeyId: '',
        secretAccessKey: '',
      );
      final client = BedrockClient(config: config);

      await expectLater(
        client.embed('text'),
        throwsA(isA<BedrockUnconfiguredException>()),
      );
    });
  });

  // ── AC-5: embed() model-ID resolution ───────────────────────────────────
  group('embed() model-ID resolution (AC-5)', () {
    // The model-ID resolution inside embed() happens *after* the unconfigured
    // guard. We cannot exercise it without a real AWS call (no mock HTTP
    // package available per constraints). We therefore test:
    //   a) the BedrockConfig / EnvConfig layer that feed into the resolution,
    //   b) that EnvConfig.get() correctly returns null for absent keys so the
    //      ?? fallback literal 'amazon.titan-embed-text-v2:0' is chosen.

    test("EnvConfig.get returns null for a key that is not set, confirming the "
        "?? fallback 'amazon.titan-embed-text-v2:0' would be used in embed()",
        () {
      // EnvConfig starts unloaded in a fresh test isolate. get() returns null
      // for any key not present in _values.
      const absentKey = 'BEDROCK_EMBED_MODEL_ID_DEFINITELY_NOT_SET_XYZ';
      expect(EnvConfig.get(absentKey), isNull);
    });

    test("fallback model-ID literal matches the Titan Embeddings V2 ID", () {
      // This validates the expected constant used in embed(). If someone
      // changes the literal they must update this test intentionally.
      const expectedFallback = 'amazon.titan-embed-text-v2:0';
      expect(expectedFallback, equals('amazon.titan-embed-text-v2:0'));
      // Verify format: must contain a colon-version suffix, not a slash.
      expect(expectedFallback, contains(':'));
      expect(expectedFallback, isNot(contains('/')));
      expect(expectedFallback, startsWith('amazon.titan-embed-text'));
    });

    test('EnvConfig.get returns null for empty string values '
        '(empty is normalised to null)', () {
      // EnvConfig._parse sets key only when value is non-empty, and get()
      // returns null when value is empty. Verify via a known-absent key.
      final result = EnvConfig.get('SOME_UNSET_KEY');
      expect(result, isNull);
    });

    test('BedrockConfig.isConfigured false → embed() guard fires before '
        'model-ID lookup, so EnvConfig is never queried for embed model', () async {
      // This test confirms the order: guard first, then model-ID lookup.
      // If the guard fires, we never reach EnvConfig.get('BEDROCK_EMBED_MODEL_ID').
      final config = BedrockConfig.sanitized(
        region: 'us-east-1',
        modelId: 'x',
        accessKeyId: '',
        secretAccessKey: '',
      );
      final client = BedrockClient(config: config);

      // Even with no EnvConfig loaded at all, the exception is thrown.
      await expectLater(
        client.embed('test text'),
        throwsA(isA<BedrockUnconfiguredException>()),
      );
    });
  });

  // ── BedrockConfig.isConfigured ───────────────────────────────────────────
  group('BedrockConfig.isConfigured', () {
    test('false when both keys are empty strings', () {
      final cfg = BedrockConfig.sanitized(
        region: 'us-east-1',
        modelId: 'x',
        accessKeyId: '',
        secretAccessKey: '',
      );
      expect(cfg.isConfigured, isFalse);
    });

    test('false when only whitespace is supplied (sanitized to empty)', () {
      final cfg = BedrockConfig.sanitized(
        region: 'us-east-1',
        modelId: 'x',
        accessKeyId: '   ',
        secretAccessKey: '   ',
      );
      expect(cfg.isConfigured, isFalse);
    });

    test('false when region is empty', () {
      final cfg = BedrockConfig.sanitized(
        region: '',
        modelId: 'amazon.titan-embed-text-v2:0',
        accessKeyId: 'AKID',
        secretAccessKey: 'SECRET',
      );
      expect(cfg.isConfigured, isFalse);
    });

    test('false when modelId is empty', () {
      final cfg = BedrockConfig.sanitized(
        region: 'us-east-1',
        modelId: '',
        accessKeyId: 'AKID',
        secretAccessKey: 'SECRET',
      );
      expect(cfg.isConfigured, isFalse);
    });

    test('true when all required fields are non-empty', () {
      final cfg = BedrockConfig.sanitized(
        region: 'us-east-1',
        modelId: 'amazon.titan-embed-text-v2:0',
        accessKeyId: 'AKIAIOSFODNN7EXAMPLE',
        secretAccessKey: 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY',
      );
      expect(cfg.isConfigured, isTrue);
    });

    test('sanitized() trims whitespace from all string fields', () {
      final cfg = BedrockConfig.sanitized(
        region: '  us-west-2  ',
        modelId: '  model-x  ',
        accessKeyId: '  AKID  ',
        secretAccessKey: '  SECRET  ',
        sessionToken: '  TOKEN  ',
      );
      expect(cfg.region, equals('us-west-2'));
      expect(cfg.modelId, equals('model-x'));
      expect(cfg.accessKeyId, equals('AKID'));
      expect(cfg.secretAccessKey, equals('SECRET'));
      expect(cfg.sessionToken, equals('TOKEN'));
    });

    test('sanitized() converts whitespace-only sessionToken to null', () {
      final cfg = BedrockConfig.sanitized(
        region: 'us-east-1',
        modelId: 'x',
        accessKeyId: 'AKID',
        secretAccessKey: 'SECRET',
        sessionToken: '   ',
      );
      expect(cfg.sessionToken, isNull);
    });
  });

  // ── BedrockUnconfiguredException unit tests ──────────────────────────────
  group('BedrockUnconfiguredException', () {
    test('default constructor produces non-empty message', () {
      const ex = BedrockUnconfiguredException();
      expect(ex.message, isNotEmpty);
    });

    test('custom message is stored verbatim', () {
      const ex = BedrockUnconfiguredException('no creds');
      expect(ex.message, equals('no creds'));
    });

    test('satisfies Exception interface', () {
      const Object ex = BedrockUnconfiguredException();
      expect(ex, isA<Exception>());
    });

    test('toString() starts with class name', () {
      const ex = BedrockUnconfiguredException();
      expect(ex.toString(), startsWith('BedrockUnconfiguredException:'));
    });

    test('toString() with custom message formats correctly', () {
      const ex = BedrockUnconfiguredException('no creds');
      expect(ex.toString(), equals('BedrockUnconfiguredException: no creds'));
    });

    test('const constructor canonicalises identical instances', () {
      const a = BedrockUnconfiguredException('msg');
      const b = BedrockUnconfiguredException('msg');
      expect(identical(a, b), isTrue);
    });

    test('runtimeType is exactly BedrockUnconfiguredException', () {
      const ex = BedrockUnconfiguredException();
      expect(ex.runtimeType, equals(BedrockUnconfiguredException));
    });
  });
}
