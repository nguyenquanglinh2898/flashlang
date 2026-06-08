import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/card_provider.dart';
import '../providers/group_provider.dart';
import '../services/csv_service.dart';

class DataScreen extends StatefulWidget {
  const DataScreen({super.key});

  @override
  State<DataScreen> createState() => _DataScreenState();
}

class _DataScreenState extends State<DataScreen> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Data'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          Text(
            'Import & Export',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Import all cards from a CSV file, download a sample file, or export your entire vocabulary database.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'CSV columns',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  const Text('word, phonetic, meaning, imagePath, groups'),
                  const SizedBox(height: 4),
                  const Text('Use ";" to separate multiple groups in one row.'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _isProcessing ? null : _importAllData,
            icon: const Icon(Icons.file_upload_outlined),
            label: const Text('Import CSV'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _isProcessing ? null : _downloadSampleCsv,
            icon: const Icon(Icons.download_outlined),
            label: const Text('Download Sample CSV'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _isProcessing ? null : _exportAllData,
            icon: const Icon(Icons.file_download_outlined),
            label: const Text('Export All Data'),
          ),
          const SizedBox(height: 20),
          if (_isProcessing)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: CircularProgressIndicator(),
              ),
            ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Image paths are exported too. Imported cards can show images again only if those image files still exist at the same path on the device.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _importAllData() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final List<ImportedCardRow> rows = await CsvService.instance.pickAndParseCsv();
      if (rows.isEmpty || !mounted) {
        return;
      }

      final CardProvider cardProvider = context.read<CardProvider>();
      int importedCount = 0;
      int duplicateCount = 0;
      int invalidCount = 0;

      for (final ImportedCardRow row in rows) {
        if (!row.isValid) {
          invalidCount++;
          continue;
        }

        final result = await cardProvider.importCardRowWithResult(
          word: row.word,
          phonetic: row.phonetic,
          meaning: row.meaning,
          imagePath: row.imagePath,
          groupNames: row.groupNames,
        );

        if (result.isInserted) {
          importedCount++;
        } else if (result.isDuplicate) {
          duplicateCount++;
        } else if (result.isInvalid) {
          invalidCount++;
        }
      }

      if (!mounted) {
        return;
      }

      await context.read<GroupProvider>().loadGroupsWithCount();
      _showMessage(
        _buildImportSummary(
          importedCount: importedCount,
          duplicateCount: duplicateCount,
          invalidCount: invalidCount,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage('Import failed: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _downloadSampleCsv() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final String filePath = await CsvService.instance.createSampleCsvFile();
      if (!mounted) {
        return;
      }
      _showMessage('Sample CSV saved to: $filePath');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage('Could not create sample CSV: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _exportAllData() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final String filePath = await CsvService.instance.exportAllCardsToCsv();
      if (!mounted) {
        return;
      }
      _showMessage('CSV saved to: $filePath');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage('Export failed: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  String _buildImportSummary({
    required int importedCount,
    required int duplicateCount,
    required int invalidCount,
  }) {
    final List<String> parts = <String>[
      'Imported $importedCount card(s).',
    ];

    if (duplicateCount > 0) {
      parts.add('$duplicateCount duplicate row(s) skipped.');
    }

    if (invalidCount > 0) {
      parts.add('$invalidCount invalid row(s) skipped.');
    }

    return parts.join(' ');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
