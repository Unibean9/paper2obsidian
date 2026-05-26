import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:xml/xml.dart' as xml;
import 'bedrock_client.dart';
import 'logger_service.dart';

/// ResearchApiService handles external API integrations for research document processing.
/// Supports: Grobid (PDF structure), OpenAlex (metadata), AWS Bedrock (summary & RAG chat).
class ResearchApiService {
  final String grobidUrl;
  final BedrockClient bedrockClient;
  final http.Client httpClient;

  ResearchApiService({
    this.grobidUrl = 'http://localhost:8070',
    required this.bedrockClient,
    http.Client? httpClient,
  }) : httpClient = httpClient ?? http.Client();

  /// Sends PDF to Grobid server and returns structured TEI XML
  /// Returns XML string containing metadata like title, authors, abstract
  /// Throws exception if Grobid service unavailable or processing fails
  Future<String> processPdfWithGrobid(File pdfFile) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$grobidUrl/api/processFulltextDocument'),
      );

      final bytes = await pdfFile.readAsBytes();
      request.files.add(
        http.MultipartFile.fromBytes(
          'input',
          bytes,
          filename: pdfFile.uri.pathSegments.isNotEmpty
              ? pdfFile.uri.pathSegments.last
              : 'upload.pdf',
          contentType: MediaType('application', 'pdf'),
        ),
      );

      request.fields['consolidateHeader'] = '1';
      request.fields['consolidateMetadata'] = '1';

      final streamedResponse = await httpClient
          .send(request)
          .timeout(
            const Duration(seconds: 120),
            onTimeout: () => throw Exception(
              'Grobid processing timeout - server may be unavailable',
            ),
          );

      if (streamedResponse.statusCode == 200) {
        final responseBody = await streamedResponse.stream.bytesToString();
        return responseBody;
      } else {
        throw Exception(
          'Grobid error: ${streamedResponse.statusCode} - ${streamedResponse.reasonPhrase}',
        );
      }
    } on SocketException catch (e) {
      AppLogger.log(
        'Cannot connect to Grobid at $grobidUrl',
        category: LogCategory.network,
        error: e,
      );
      throw Exception(
        'Cannot connect to Grobid server at $grobidUrl. '
        'Please ensure Grobid is running via Docker: docker-compose up grobid',
      );
    } catch (e) {
      AppLogger.log(
        'Grobid processing failed',
        category: LogCategory.network,
        error: e,
      );
      throw Exception('Grobid processing failed: ${e.toString()}');
    }
  }

  /// Fetches metadata from OpenAlex API.
  Future<Map<String, dynamic>> fetchOpenAlexMetadata(String title) async {
    if (title.trim().isEmpty) {
      return {};
    }

    try {
      final encodedTitle = Uri.encodeComponent(title);
      final url = Uri.parse(
        'https://api.openalex.org/works?search=$encodedTitle&per-page=1',
      );

      final response = await httpClient
          .get(url)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw Exception('OpenAlex API timeout'),
          );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = data['results'] as List?;

        if (results != null && results.isNotEmpty) {
          final work = results.first;
          return _parseOpenAlexWork(work);
        }
        return {};
      } else if (response.statusCode == 429) {
        throw Exception(
          'OpenAlex rate limit exceeded. Please try again in a moment.',
        );
      } else {
        throw Exception('OpenAlex API error: ${response.statusCode}');
      }
    } on SocketException catch (e) {
      AppLogger.log(
        'Network error connecting to OpenAlex',
        category: LogCategory.network,
        error: e,
      );
      throw Exception('Network error connecting to OpenAlex API');
    } catch (e) {
      AppLogger.log(
        'OpenAlex metadata fetch failed',
        category: LogCategory.network,
        error: e,
      );
      throw Exception('OpenAlex metadata fetch failed: ${e.toString()}');
    }
  }

  static Map<String, dynamic> _parseOpenAlexWork(Map<String, dynamic> work) {
    try {
      final authorsData = work['authorships'] as List? ?? [];
      final authors = authorsData
          .map((a) => (a['author']?['display_name'] ?? 'Unknown') as String)
          .join(', ');

      final publicationDate = work['publication_date'] as String?;
      final year = publicationDate?.split('-').first ?? '';

      return {
        'title': work['title'] ?? '',
        'authors': authors.isNotEmpty ? authors : 'Not Given',
        'year': year.isNotEmpty ? year : 'Not Given',
        'doi':
            work['doi']?.toString().replaceFirst('https://doi.org/', '') ??
            'Not Given',
        'venue':
            work['primary_location']?['source']?['display_name'] ??
            work['type'] ??
            'Not Given',
        'citedByCount': work['cited_by_count']?.toString() ?? '0',
        'openalex_id': work['id'] ?? '',
      };
    } catch (e) {
      return {'error': 'Failed to parse OpenAlex metadata: ${e.toString()}'};
    }
  }

  /// AWS Bedrock for summarization, metadata extraction, and RAG chat.
  static String _limitText(String text, int maxChars) {
    if (text.length <= maxChars) return text;
    return '${text.substring(0, maxChars)}...';
  }

  static Map<String, dynamic> _parseJsonFromModel(String raw) {
    final trimmed = raw.trim();
    try {
      return Map<String, dynamic>.from(jsonDecode(trimmed) as Map);
    } catch (_) {
      final start = trimmed.indexOf('{');
      final end = trimmed.lastIndexOf('}');
      if (start >= 0 && end > start) {
        return Map<String, dynamic>.from(
          jsonDecode(trimmed.substring(start, end + 1)) as Map,
        );
      }
      rethrow;
    }
  }

  /// Extracts structured metadata + summary from paper text (Step 4 pipeline).
  Future<({String summary, Map<String, dynamic> extraData})>
  extractPaperMetadataWithBedrock(
    String pdfText, {
    double temperature = 0.1,
  }) async {
    if (pdfText.trim().isEmpty) {
      return (summary: 'Not Given', extraData: <String, dynamic>{});
    }

    const systemPrompt =
        'You are a research assistant. Extract metadata from the paper text. '
        'Return ONLY valid JSON with keys: title (paper title as printed), '
        'dataset (comma-separated dataset names, no "and"), '
        'problem_statement, limitation, keywords (comma-separated), summary. '
        'Use "Not Given" when unavailable.';

    try {
      final content = await bedrockClient.converse(
        systemPrompt: systemPrompt,
        userMessage: 'Text from paper:\n${_limitText(pdfText, 8000)}',
        temperature: temperature,
        maxTokens: 2048,
      );

      final extraData = _parseJsonFromModel(content);
      final summary = extraData['summary']?.toString() ?? content;
      return (summary: summary, extraData: extraData);
    } catch (e) {
      AppLogger.log(
        'Bedrock metadata extraction failed',
        category: LogCategory.parse,
        error: e,
      );
      throw Exception('Bedrock metadata extraction failed: ${e.toString()}');
    }
  }

  /// Generates a concise paper summary using AWS Bedrock.
  Future<String> generateSummaryWithBedrock(
    String pdfText, {
    double temperature = 0.3,
  }) async {
    if (pdfText.trim().isEmpty) {
      return 'Not Given';
    }

    try {
      final content = await bedrockClient.converse(
        systemPrompt:
            'You are a research assistant. Provide a concise 2-3 sentence summary '
            'of the paper in English. Be specific about the main contribution. '
            'Respond with plain text only.',
        userMessage: 'Summarize this paper:\n${_limitText(pdfText, 3000)}',
        temperature: temperature,
        maxTokens: 512,
      );
      return content.trim().isNotEmpty ? content.trim() : 'Not Given';
    } catch (e) {
      AppLogger.log(
        'Summary generation failed',
        category: LogCategory.parse,
        error: e,
      );
      throw Exception('Summary generation failed: ${e.toString()}');
    }
  }

  /// Chat with paper context using AWS Bedrock (RAG-style).
  Future<String> chatWithPaperContext(
    String userQuestion,
    String pdfContext, {
    double temperature = 0.5,
  }) async {
    if (userQuestion.trim().isEmpty) {
      return 'Please ask a question.';
    }

    try {
      return await bedrockClient.converse(
        systemPrompt:
            'You are an expert research assistant. Answer questions about the paper '
            'based on the provided context. Be precise and cite specific parts if relevant. '
            'Respond in English.',
        userMessage:
            'Paper context:\n${_limitText(pdfContext, 4000)}\n\nQuestion: $userQuestion',
        temperature: temperature,
        maxTokens: 1024,
      );
    } catch (e) {
      AppLogger.log(
        'Chat with paper context failed',
        category: LogCategory.network,
        error: e,
      );
      throw Exception('Chat failed: ${e.toString()}');
    }
  }

  // =========================================================================
  // 4. GROBID XML PARSING UTILITIES
  // =========================================================================

  static Map<String, dynamic> parseGrobidXml(String xmlString) {
    try {
      final document = xml.XmlDocument.parse(xmlString);
      final root = document.rootElement;

      String title = '';
      String authors = '';
      String abstract = '';
      String keywords = '';
      String year = '';

      final titleElement = root.findAllElements('title').firstOrNull;
      title = titleElement?.text ?? '';

      final authorElements = root.findAllElements('author').toList();
      final authorNames = <String>[];

      for (var author in authorElements) {
        final persName = author.findElements('persName').firstOrNull;
        if (persName != null) {
          final forename =
              persName.findElements('forename').firstOrNull?.text ?? '';
          final surname =
              persName.findElements('surname').firstOrNull?.text ?? '';
          if (surname.isNotEmpty) {
            authorNames.add(
              '$surname${forename.isNotEmpty ? ', $forename' : ''}',
            );
          }
        }
      }
      authors = authorNames.join('; ');

      final abstractElement = root.findAllElements('abstract').firstOrNull;
      abstract = abstractElement?.text ?? '';

      final keywordElements = root.findAllElements('term').toList();
      keywords = keywordElements
          .map((e) => e.text)
          .where((k) => k.isNotEmpty)
          .join(', ');

      final dateElement = root
          .findAllElements('imprint')
          .expand((e) => e.findAllElements('date'))
          .firstOrNull;
      year = dateElement?.getAttribute('when')?.substring(0, 4) ?? '';

      final biblStructElements = root.findAllElements('biblStruct').toList();
      final citationsList = <String>[];
      for (var bibl in biblStructElements) {
        final analyticTitle = bibl
            .findElements('analytic')
            .expand((e) => e.findElements('title'))
            .firstOrNull
            ?.text;
        final monogrTitle = bibl
            .findElements('monogr')
            .expand((e) => e.findElements('title'))
            .firstOrNull
            ?.text;
        final citeTitle = analyticTitle ?? monogrTitle ?? '';

        if (citeTitle.isNotEmpty && title.isNotEmpty) {
          final citeLower = citeTitle
              .toLowerCase()
              .replaceAll(RegExp(r'\s+'), ' ')
              .trim();
          final mainLower = title
              .toLowerCase()
              .replaceAll(RegExp(r'\s+'), ' ')
              .trim();
          if (citeLower == mainLower ||
              citeLower.contains(mainLower) ||
              mainLower.contains(citeLower)) {
            continue;
          }
        }

        final authorsList = <String>[];
        final authorsNodes = bibl.findAllElements('author');
        for (var author in authorsNodes) {
          final surname =
              author.findAllElements('surname').firstOrNull?.text ?? '';
          if (surname.isNotEmpty) authorsList.add(surname);
        }

        if (citeTitle.isNotEmpty) {
          String cite = citeTitle;
          if (authorsList.isNotEmpty) {
            cite = '${authorsList.join(', ')} - $citeTitle';
          }
          citationsList.add(cite);
        }
      }

      return {
        'title': title.trim(),
        'authors': authors.isNotEmpty ? authors : 'Not Given',
        'abstract': abstract.isNotEmpty ? abstract : 'Not Given',
        'keywords': keywords.isNotEmpty ? keywords : 'Not Given',
        'year': year.isNotEmpty ? year : 'Not Given',
        'citations': citationsList,
      };
    } catch (e) {
      return {
        'error': 'Failed to parse Grobid XML: ${e.toString()}',
        'title': '',
        'authors': '',
        'abstract': '',
        'keywords': '',
        'year': '',
        'citations': <String>[],
      };
    }
  }
}
