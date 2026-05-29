import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../exceptions/zotero_exception.dart';
import '../models/zotero_item.dart';
import '../services/logger_service.dart';

/// Result sentinel returned when the file already exists in Zotero storage.
class UploadAlreadyExistsResult {
  const UploadAlreadyExistsResult();
}

class ZoteroService {
  ZoteroService({required String apiKey}) : _apiKey = apiKey;

  String _apiKey;
  String? _resolvedUserId;
  final http.Client _client = http.Client();

  static const String _baseUrl = 'https://api.zotero.org';

  String? get resolvedUserId => _resolvedUserId;

  bool get isConfigured => _apiKey.isNotEmpty && _resolvedUserId != null;

  void updateApiKey(String key) {
    _apiKey = key;
    _resolvedUserId = null; // force re-resolve on next call
  }

  // =========================================================================
  // HTTP helpers
  // =========================================================================

  Map<String, String> get _headers => {
        'Zotero-API-Key': _apiKey,
        'Zotero-API-Version': '3',
        'Content-Type': 'application/json',
      };

  Future<http.Response> _request(
    String method,
    Uri uri, {
    Map<String, String>? extraHeaders,
    Object? body,
    int attempt = 1,
  }) async {
    final headers = {..._headers, ...?extraHeaders};
    late http.Response response;

    try {
      switch (method) {
        case 'GET':
          response = await _client
              .get(uri, headers: headers)
              .timeout(const Duration(seconds: 30));
        case 'POST':
          response = await _client
              .post(
                uri,
                headers: headers,
                body: body is String ? body : jsonEncode(body),
              )
              .timeout(const Duration(seconds: 30));
        default:
          throw StateError('Unsupported method: $method');
      }
    } catch (e) {
      throw ZoteroException(
        userMessage: 'Network error connecting to Zotero: $e',
        technicalError: e,
      );
    }

    if (response.statusCode == 429 && attempt <= 2) {
      await Future.delayed(Duration(seconds: attempt * 2));
      return _request(method, uri,
          extraHeaders: extraHeaders, body: body, attempt: attempt + 1);
    }

    _assertOk(response);
    return response;
  }

  void _assertOk(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    switch (response.statusCode) {
      case 403:
        throw ZoteroException(
          userMessage:
              'Zotero API key does not have permission for this action. '
              'Check that the key has library write access.',
          statusCode: 403,
        );
      case 412:
        throw ZoteroException(
          userMessage:
              'Zotero upload conflict (412). The file may already exist '
              'or the item version is stale.',
          statusCode: 412,
        );
      case 429:
        throw ZoteroException(
          userMessage: 'Zotero rate limit exceeded. Please try again shortly.',
          statusCode: 429,
        );
      default:
        throw ZoteroException(
          userMessage:
              'Zotero API error ${response.statusCode}: ${response.reasonPhrase}',
          statusCode: response.statusCode,
        );
    }
  }

  // =========================================================================
  // User ID resolution
  // =========================================================================

  /// Fetches and caches the numeric Zotero user ID from the API key metadata.
  /// Also returns the access info so callers can check write permission.
  Future<Map<String, dynamic>> resolveUserId() async {
    final uri = Uri.parse('$_baseUrl/keys/$_apiKey');
    final response = await _request('GET', uri);
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    _resolvedUserId = data['userID']?.toString();
    return data;
  }

  void setResolvedUserId(String userId) {
    _resolvedUserId = userId;
  }

  String get _userId {
    if (_resolvedUserId == null) {
      throw ZoteroException(
        userMessage:
            'Zotero user ID not resolved. Click "Resolve User ID" in Settings first.',
      );
    }
    return _resolvedUserId!;
  }

  // =========================================================================
  // Collections and items
  // =========================================================================

  Future<List<ZoteroCollection>> listCollections() async {
    final uri = Uri.parse(
        '$_baseUrl/users/$_userId/collections?limit=100&start=0');
    final response = await _request('GET', uri);
    final list = jsonDecode(response.body) as List;
    return list
        .map((e) => ZoteroCollection.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<ZoteroItem>> listCollectionItems(String collectionKey) async {
    final uri = Uri.parse(
        '$_baseUrl/users/$_userId/collections/$collectionKey/items?limit=100&start=0&itemType=attachment,-attachment');
    final response = await _request('GET', uri);
    final list = jsonDecode(response.body) as List;
    return list
        .map((e) => ZoteroItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // =========================================================================
  // PDF download
  // =========================================================================

  /// Downloads the PDF bytes for a given attachment item key.
  Future<Uint8List> downloadPdf(String itemKey) async {
    final uri = Uri.parse('$_baseUrl/users/$_userId/items/$itemKey/file');
    late http.Response response;
    try {
      response = await _client
          .get(uri, headers: _headers)
          .timeout(const Duration(minutes: 5));
    } catch (e) {
      throw ZoteroException(
        userMessage: 'Failed to download PDF from Zotero: $e',
        technicalError: e,
      );
    }
    if (response.statusCode != 200) {
      _assertOk(response);
    }
    return response.bodyBytes;
  }

  // =========================================================================
  // 5-stage upload
  // =========================================================================

  String _md5Hex(Uint8List bytes) {
    final digest = md5.convert(bytes);
    return digest.toString();
  }

  /// Stage 1: Create a parent journal-article item. Returns the new item key.
  Future<String> createParentItem({
    required String collectionKey,
    required String title,
    required String authors,
    String? year,
    String? doi,
  }) async {
    final creatorList = authors
        .split(RegExp(r'[;,]'))
        .map((a) => a.trim())
        .where((a) => a.isNotEmpty)
        .map((a) {
      final parts = a.split(',');
      return {
        'creatorType': 'author',
        'lastName': parts.first.trim(),
        'firstName': parts.length > 1 ? parts[1].trim() : '',
      };
    }).toList();

    final body = [
      {
        'itemType': 'journalArticle',
        'title': title,
        'creators': creatorList,
        if (year != null) 'date': year,
        if (doi != null) 'DOI': doi,
        'collections': [collectionKey],
        'tags': [],
      }
    ];

    final uri = Uri.parse('$_baseUrl/users/$_userId/items');
    final response = await _request('POST', uri, body: body);
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final successful = data['successful'] as Map<String, dynamic>?;
    final key =
        (successful?['0'] as Map<String, dynamic>?)?['key'] as String?;
    if (key == null) {
      throw const ZoteroException(
          userMessage: 'Failed to create parent item in Zotero.');
    }
    return key;
  }

  /// Stage 2: Create an attachment stub linked to the parent item. Returns the
  /// attachment item key and its current version.
  Future<({String key, int version})> createAttachmentStub({
    required String parentKey,
    required String filename,
  }) async {
    final body = [
      {
        'itemType': 'attachment',
        'parentItem': parentKey,
        'linkMode': 'imported_file',
        'title': filename,
        'contentType': 'application/pdf',
        'filename': filename,
        'tags': [],
      }
    ];

    final uri = Uri.parse('$_baseUrl/users/$_userId/items');
    final response = await _request('POST', uri, body: body);
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final successful = data['successful'] as Map<String, dynamic>?;
    final item = successful?['0'] as Map<String, dynamic>?;
    final key = item?['key'] as String?;
    final version = item?['version'] as int?;
    if (key == null || version == null) {
      throw const ZoteroException(
          userMessage: 'Failed to create attachment stub in Zotero.');
    }
    return (key: key, version: version);
  }

  /// Stage 3: Authorize the upload. Returns [UploadAlreadyExistsResult] if the
  /// file already exists (skip stages 4+5). Otherwise returns the auth map
  /// containing url, contentType, prefix, suffix, uploadKey.
  Future<Object> authorizeUpload({
    required String attachmentKey,
    required int attachmentVersion,
    required Uint8List fileBytes,
    required String filename,
    required int mtime,
  }) async {
    final md5Hash = _md5Hex(fileBytes);
    final uri = Uri.parse('$_baseUrl/users/$_userId/items/$attachmentKey/file');

    final body = {
      'md5': md5Hash,
      'filename': filename,
      'filesize': fileBytes.length,
      'mtime': mtime,
    };

    final response = await _client
        .post(
          uri,
          headers: {
            ..._headers,
            'If-None-Match': '*',
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: body.entries
              .map((e) =>
                  '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value.toString())}')
              .join('&'),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 412) {
      throw const ZoteroException(
        userMessage:
            'Zotero upload conflict (412). The attachment version is stale.',
        statusCode: 412,
      );
    }
    if (response.statusCode != 200) {
      _assertOk(response);
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['exists'] == 1) {
      return const UploadAlreadyExistsResult();
    }
    return data;
  }

  /// Stage 4: PUT raw bytes to S3. prefix/suffix are percent-decoded raw bytes.
  Future<void> uploadToS3({
    required String s3Url,
    required String contentType,
    required String prefixStr,
    required String suffixStr,
    required Uint8List fileBytes,
  }) async {
    // Percent-decode then treat as raw Latin-1 byte sequence — do NOT re-encode
    // as UTF-8, which corrupts multi-byte percent sequences and breaks MD5.
    final prefix = _percentDecodedBytes(prefixStr);
    final suffix = _percentDecodedBytes(suffixStr);

    final body = Uint8List(prefix.length + fileBytes.length + suffix.length)
      ..setRange(0, prefix.length, prefix)
      ..setRange(prefix.length, prefix.length + fileBytes.length, fileBytes)
      ..setRange(
          prefix.length + fileBytes.length,
          prefix.length + fileBytes.length + suffix.length,
          suffix);

    late http.Response response;
    try {
      response = await _client
          .put(
            Uri.parse(s3Url),
            headers: {
              'Content-Type': contentType,
              'Content-Length': body.length.toString(),
            },
            body: body,
          )
          .timeout(const Duration(minutes: 10));
    } catch (e) {
      throw ZoteroException(
        userMessage: 'S3 upload failed: $e',
        technicalError: e,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ZoteroException(
        userMessage: 'S3 upload failed with status ${response.statusCode}.',
        statusCode: response.statusCode,
      );
    }
  }

  /// Stage 5: Register the upload with Zotero after a successful S3 PUT.
  Future<void> registerUpload({
    required String attachmentKey,
    required String uploadKey,
  }) async {
    final uri = Uri.parse('$_baseUrl/users/$_userId/items/$attachmentKey/file');
    final response = await _client
        .post(
          uri,
          headers: {
            ..._headers,
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: 'upload=$uploadKey',
        )
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 204) {
      _assertOk(response);
    }
  }

  /// Full 5-stage upload. Handles the `{"exists": 1}` short-circuit.
  Future<void> uploadPdf({
    required String collectionKey,
    required String title,
    required String authors,
    String? year,
    String? doi,
    required Uint8List pdfBytes,
    required String filename,
    required void Function(String message) onProgress,
  }) async {
    onProgress('Stage 1/5: Creating parent item in Zotero...');
    final parentKey = await createParentItem(
      collectionKey: collectionKey,
      title: title,
      authors: authors,
      year: year,
      doi: doi,
    );
    AppLogger.log('Stage 1 complete: parent key=$parentKey',
        category: LogCategory.network);

    onProgress('Stage 2/5: Creating attachment stub...');
    final stub = await createAttachmentStub(
      parentKey: parentKey,
      filename: filename,
    );
    AppLogger.log('Stage 2 complete: attachment key=${stub.key}',
        category: LogCategory.network);

    onProgress('Stage 3/5: Authorizing upload...');
    final mtime = DateTime.now().millisecondsSinceEpoch;
    final authResult = await authorizeUpload(
      attachmentKey: stub.key,
      attachmentVersion: stub.version,
      fileBytes: pdfBytes,
      filename: filename,
      mtime: mtime,
    );
    AppLogger.log('Stage 3 complete: authorized', category: LogCategory.network);

    if (authResult is UploadAlreadyExistsResult) {
      onProgress('File already exists in Zotero — upload skipped.');
      AppLogger.log('Stage 3: file already exists, skipping S3 upload',
          category: LogCategory.network);
      return;
    }

    final auth = authResult as Map<String, dynamic>;
    final s3Url = auth['url'] as String;
    final contentType = auth['contentType'] as String;
    final prefixStr = auth['prefix'] as String;
    final suffixStr = auth['suffix'] as String;
    final uploadKey = auth['uploadKey'] as String;

    onProgress('Stage 4/5: Uploading PDF to storage...');
    await uploadToS3(
      s3Url: s3Url,
      contentType: contentType,
      prefixStr: prefixStr,
      suffixStr: suffixStr,
      fileBytes: pdfBytes,
    );
    AppLogger.log('Stage 4 complete: S3 PUT succeeded',
        category: LogCategory.network);

    onProgress('Stage 5/5: Registering upload...');
    await registerUpload(attachmentKey: stub.key, uploadKey: uploadKey);
    AppLogger.log('Stage 5 complete: upload registered',
        category: LogCategory.network);

    onProgress('Upload complete.');
  }

  // =========================================================================
  // Utilities
  // =========================================================================

  /// Percent-decodes a string and returns the raw byte values (Latin-1 / ISO-8859-1).
  /// This is required for Zotero S3 prefix/suffix fields.
  static Uint8List _percentDecodedBytes(String encoded) {
    final decoded = Uri.decodeComponent(encoded);
    return Uint8List.fromList(decoded.codeUnits);
  }

  void dispose() => _client.close();
}
