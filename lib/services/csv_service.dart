import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../database/database_helper.dart';

enum ImportExportFormat {
  csv,
  txt,
}

class CsvService {
  CsvService._();

  static final CsvService instance = CsvService._();

  Future<List<ImportedCardRow>> pickAndParseFile(ImportExportFormat format) async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: <String>[format.extension],
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return <ImportedCardRow>[];
    }

    final PlatformFile file = result.files.single;
    final String content;
    if (file.bytes != null) {
      content = utf8.decode(file.bytes!);
    } else if (file.path != null) {
      content = await File(file.path!).readAsString();
    } else {
      throw CsvServiceException(
        'Unable to read the selected ${format.label} file.',
      );
    }

    return parseContent(content, format);
  }

  Future<List<ImportedCardRow>> pickAndParseCsv() {
    return pickAndParseFile(ImportExportFormat.csv);
  }

  List<ImportedCardRow> parseContent(String content, ImportExportFormat format) {
    return _parseDelimitedContent(content, fieldDelimiter: ',');
  }

  List<ImportedCardRow> parseCsvString(String content) {
    return parseContent(content, ImportExportFormat.csv);
  }

  Future<String> exportGroupToCsv({
    required int groupId,
    required String groupName,
  }) async {
    return _exportGroup(
      groupId: groupId,
      groupName: groupName,
      format: ImportExportFormat.csv,
    );
  }

  Future<String> exportGroupToTxt({
    required int groupId,
    required String groupName,
  }) async {
    return _exportGroup(
      groupId: groupId,
      groupName: groupName,
      format: ImportExportFormat.txt,
    );
  }

  Future<String> exportAllCardsToCsv() {
    return _exportAllCards(ImportExportFormat.csv);
  }

  Future<String> exportAllCardsToTxt() {
    return _exportAllCards(ImportExportFormat.txt);
  }

  Future<String> createSampleCsvFile() {
    return _createSampleFile(ImportExportFormat.csv);
  }

  Future<String> createSampleTxtFile() {
    return _createSampleFile(ImportExportFormat.txt);
  }

  List<ImportedCardRow> _parseDelimitedContent(
    String content, {
    required String fieldDelimiter,
  }) {
    final List<List<dynamic>> rows = CsvToListConverter(
      eol: '\n',
      shouldParseNumbers: false,
      fieldDelimiter: fieldDelimiter,
    ).convert(content);

    if (rows.isEmpty) {
      return <ImportedCardRow>[];
    }

    final List<String> headers = rows.first
        .map((dynamic value) => value.toString().trim().toLowerCase())
        .toList();
    final Map<String, int> headerIndexes = _validateAndMapHeaders(headers);

    final List<ImportedCardRow> parsedRows = <ImportedCardRow>[];
    for (int index = 1; index < rows.length; index++) {
      final List<dynamic> row = rows[index];
      if (_isRowEmpty(row)) {
        continue;
      }

      parsedRows.add(
        ImportedCardRow.fromDelimitedRow(
          rowIndex: index + 1,
          row: row,
          headerIndexes: headerIndexes,
        ),
      );
    }

    return parsedRows;
  }

  Future<String> _exportGroup({
    required int groupId,
    required String groupName,
    required ImportExportFormat format,
  }) async {
    final List<ExportableCardRow> rows =
        await DatabaseHelper.instance.getCardsForExportByGroup(groupId);
    return _saveExportRows(
      rows: rows,
      fileName:
          'flashlang_${_sanitizeFileName(groupName)}_${DateTime.now().millisecondsSinceEpoch}.${format.extension}',
      format: format,
    );
  }

  Future<String> _exportAllCards(ImportExportFormat format) async {
    final List<ExportableCardRow> rows =
        await DatabaseHelper.instance.getAllCardsForExport();
    return _saveExportRows(
      rows: rows,
      fileName:
          'flashlang_all_cards_${DateTime.now().millisecondsSinceEpoch}.${format.extension}',
      format: format,
    );
  }

  Future<String> _createSampleFile(ImportExportFormat format) async {
    const List<List<String>> rows = <List<String>>[
      <String>[
        'word',
        'partOfSpeech',
        'phonetic',
        'meaning',
        'imagePath',
        'groups',
      ],
      <String>['apple', 'noun', '/ˈae.pəl/', 'Quả táo', '', 'Fruits;Daily'],
      <String>['take off', 'phrasal verb', '', 'Cất cánh', '', 'Travel'],
    ];

    final String content = _encodeRows(rows, format);
    return _saveFile(
      fileName: 'flashlang_sample_import.${format.extension}',
      content: content,
      format: format,
    );
  }

  Future<String> _saveExportRows({
    required List<ExportableCardRow> rows,
    required String fileName,
    required ImportExportFormat format,
  }) {
    final List<List<String>> data = <List<String>>[
      <String>[
        'word',
        'partOfSpeech',
        'phonetic',
        'meaning',
        'imagePath',
        'groups',
      ],
      ...rows.map((ExportableCardRow row) => row.toCsvRow()),
    ];

    return _saveFile(
      fileName: fileName,
      content: _encodeRows(data, format),
      format: format,
    );
  }

  Future<String> _saveFile({
    required String fileName,
    required String content,
    required ImportExportFormat format,
  }) async {
    final Uint8List bytes = Uint8List.fromList(utf8.encode(content));
    final String? outputPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save ${format.label.toUpperCase()} file',
      fileName: fileName,
      bytes: bytes,
    );

    if (outputPath != null && outputPath.trim().isNotEmpty) {
      return outputPath;
    }

    final Directory directory = await getTemporaryDirectory();
    final String fallbackPath = p.join(directory.path, fileName);
    final File file = File(fallbackPath);
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  String _encodeRows(List<List<String>> rows, ImportExportFormat format) {
    return const ListToCsvConverter().convert(rows);
  }

  Map<String, int> _validateAndMapHeaders(List<String> headers) {
    final Map<String, int> headerIndexes = <String, int>{};
    for (int index = 0; index < headers.length; index++) {
      headerIndexes[headers[index]] = index;
    }

    const List<String> requiredHeaders = <String>[
      'word',
      'partofspeech',
      'phonetic',
      'meaning',
      'groups',
    ];

    for (final String header in requiredHeaders) {
      if (!headerIndexes.containsKey(header)) {
        throw const CsvServiceException(
          'Header không hợp lệ. Cần các cột: word, partOfSpeech, phonetic, meaning, imagePath, groups.',
        );
      }
    }

    return headerIndexes;
  }

  bool _isRowEmpty(List<dynamic> row) {
    return row.every((dynamic value) => value.toString().trim().isEmpty);
  }

  String _sanitizeFileName(String value) {
    final String sanitized = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return sanitized.isEmpty ? 'group' : sanitized;
  }
}

class ImportedCardRow {
  const ImportedCardRow({
    required this.rowIndex,
    required this.word,
    this.partOfSpeech,
    this.phonetic,
    required this.meaning,
    this.imagePath,
    required this.groupNames,
  });

  final int rowIndex;
  final String word;
  final String? partOfSpeech;
  final String? phonetic;
  final String meaning;
  final String? imagePath;
  final List<String> groupNames;

  bool get isValid =>
      word.trim().isNotEmpty &&
      meaning.trim().isNotEmpty &&
      groupNames.isNotEmpty;

  factory ImportedCardRow.fromDelimitedRow({
    required int rowIndex,
    required List<dynamic> row,
    required Map<String, int> headerIndexes,
  }) {
    String cellValue(String header) {
      final int? index = headerIndexes[header];
      if (index == null || index >= row.length) {
        return '';
      }
      return row[index].toString().trim();
    }

    final List<String> groupNames = cellValue('groups')
        .split(';')
        .map((String value) => value.trim())
        .where((String value) => value.isNotEmpty)
        .toList();

    return ImportedCardRow(
      rowIndex: rowIndex,
      word: cellValue('word'),
      partOfSpeech:
          cellValue('partofspeech').isEmpty ? null : cellValue('partofspeech'),
      phonetic: cellValue('phonetic').isEmpty ? null : cellValue('phonetic'),
      meaning: cellValue('meaning'),
      imagePath: cellValue('imagepath').isEmpty ? null : cellValue('imagepath'),
      groupNames: groupNames,
    );
  }
}

class CsvServiceException implements Exception {
  const CsvServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

extension on ImportExportFormat {
  String get extension => this == ImportExportFormat.csv ? 'csv' : 'txt';

  String get label => this == ImportExportFormat.csv ? 'csv' : 'txt';
}
