import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../database/database_helper.dart';

class CsvService {
  CsvService._();

  static final CsvService instance = CsvService._();

  static const List<String> _expectedHeaders = <String>[
    'word',
    'phonetic',
    'meaning',
    'imagepath',
    'groups',
  ];

  Future<List<ImportedCardRow>> pickAndParseCsv() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['csv'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return <ImportedCardRow>[];
    }

    final PlatformFile file = result.files.single;
    if (file.bytes != null) {
      return parseCsvString(utf8.decode(file.bytes!));
    }

    if (file.path == null) {
      throw const CsvServiceException('Unable to read the selected CSV file.');
    }

    final String content = await File(file.path!).readAsString();
    return parseCsvString(content);
  }

  List<ImportedCardRow> parseCsvString(String content) {
    final List<List<dynamic>> rows = const CsvToListConverter(
      eol: '\n',
      shouldParseNumbers: false,
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

      final ImportedCardRow importedRow = ImportedCardRow.fromCsvRow(
        rowIndex: index + 1,
        row: row,
        headerIndexes: headerIndexes,
      );

      if (!importedRow.isValid) {
        parsedRows.add(importedRow);
        continue;
      }

      parsedRows.add(importedRow);
    }

    return parsedRows;
  }

  Future<String> exportGroupToCsv({
    required int groupId,
    required String groupName,
  }) async {
    final List<ExportableCardRow> rows =
        await DatabaseHelper.instance.getCardsForExportByGroup(groupId);

    final List<List<String>> csvRows = <List<String>>[
      _expectedHeaders,
      ...rows.map((ExportableCardRow row) => row.toCsvRow()),
    ];

    final String sanitizedName = _sanitizeFileName(groupName);
    final String fileName =
        'flashlang_${sanitizedName}_${DateTime.now().millisecondsSinceEpoch}.csv';
    final String csvContent = const ListToCsvConverter().convert(csvRows);

    return _saveCsvContent(
      fileName: fileName,
      csvContent: csvContent,
    );
  }

  Future<String> exportAllCardsToCsv() async {
    final List<ExportableCardRow> rows =
        await DatabaseHelper.instance.getAllCardsForExport();

    final List<List<String>> csvRows = <List<String>>[
      _expectedHeaders,
      ...rows.map((ExportableCardRow row) => row.toCsvRow()),
    ];

    final String csvContent = const ListToCsvConverter().convert(csvRows);
    return _saveCsvContent(
      fileName: 'flashlang_all_cards_${DateTime.now().millisecondsSinceEpoch}.csv',
      csvContent: csvContent,
    );
  }

  Future<String> createSampleCsvFile() async {
    const List<List<String>> csvRows = <List<String>>[
      <String>['word', 'phonetic', 'meaning', 'imagePath', 'groups'],
      <String>['Apple', '/ˈae.pəl/', 'Quả táo', '', 'Fruits;Daily'],
      <String>['Banana', '', 'Quả chuối', '', 'Fruits'],
    ];

    final String csvContent = const ListToCsvConverter().convert(csvRows);
    return _saveCsvContent(
      fileName: 'flashlang_sample_import.csv',
      csvContent: csvContent,
    );
  }

  Future<String> _saveCsvContent({
    required String fileName,
    required String csvContent,
  }) async {
    final Uint8List bytes = Uint8List.fromList(utf8.encode(csvContent));
    final String? outputPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save CSV file',
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

  Map<String, int> _validateAndMapHeaders(List<String> headers) {
    final Map<String, int> headerIndexes = <String, int>{};
    for (int index = 0; index < headers.length; index++) {
      headerIndexes[headers[index]] = index;
    }

    const List<String> requiredHeaders = <String>[
      'word',
      'phonetic',
      'meaning',
      'groups',
    ];

    for (final String header in requiredHeaders) {
      if (!headerIndexes.containsKey(header)) {
        throw CsvServiceException(
          'CSV header is invalid. Expected columns: word, phonetic, meaning, imagePath, groups.',
        );
      }
    }

    if (headers.length < 4) {
      throw CsvServiceException(
        'CSV header is invalid. Expected columns: word, phonetic, meaning, imagePath, groups.',
      );
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
    this.phonetic,
    required this.meaning,
    this.imagePath,
    required this.groupNames,
  });

  final int rowIndex;
  final String word;
  final String? phonetic;
  final String meaning;
  final String? imagePath;
  final List<String> groupNames;

  bool get isValid =>
      word.trim().isNotEmpty &&
      meaning.trim().isNotEmpty &&
      groupNames.isNotEmpty;

  factory ImportedCardRow.fromCsvRow({
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
