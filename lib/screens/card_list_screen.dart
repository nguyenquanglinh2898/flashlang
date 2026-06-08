import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/card_provider.dart';
import '../providers/group_provider.dart';
import '../services/csv_service.dart';
import '../services/tts_service.dart';
import '../widgets/card_tile.dart';
import '../widgets/confirm_dialog.dart';
import 'add_edit_card_screen.dart';
import 'card_detail_screen.dart';

class CardListScreen extends StatefulWidget {
  const CardListScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  final int groupId;
  final String groupName;

  @override
  State<CardListScreen> createState() => _CardListScreenState();
}

class _CardListScreenState extends State<CardListScreen> {
  String _formatLabel(ImportExportFormat format) {
    return format == ImportExportFormat.csv ? 'CSV' : 'TXT';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CardProvider>().loadCardsByGroup(widget.groupId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CardProvider>(
      builder: (BuildContext context, CardProvider cardProvider, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(widget.groupName),
            actions: <Widget>[
              PopupMenuButton<_CardListMenuAction>(
                onSelected: (action) async {
                  switch (action) {
                    case _CardListMenuAction.importCsv:
                      await _importFile(ImportExportFormat.csv);
                      break;
                    case _CardListMenuAction.downloadSampleCsv:
                      await _downloadSampleFile(ImportExportFormat.csv);
                      break;
                    case _CardListMenuAction.exportCsv:
                      await _exportFile(ImportExportFormat.csv);
                      break;
                    case _CardListMenuAction.exportAllCsv:
                      await _exportAllFile(ImportExportFormat.csv);
                      break;
                    case _CardListMenuAction.importTxt:
                      await _importFile(ImportExportFormat.txt);
                      break;
                    case _CardListMenuAction.downloadSampleTxt:
                      await _downloadSampleFile(ImportExportFormat.txt);
                      break;
                    case _CardListMenuAction.exportTxt:
                      await _exportFile(ImportExportFormat.txt);
                      break;
                    case _CardListMenuAction.exportAllTxt:
                      await _exportAllFile(ImportExportFormat.txt);
                      break;
                  }
                },
                itemBuilder: (BuildContext context) =>
                    const <PopupMenuEntry<_CardListMenuAction>>[
                  PopupMenuItem<_CardListMenuAction>(
                    value: _CardListMenuAction.importCsv,
                    child: Text('Import CSV'),
                  ),
                  PopupMenuItem<_CardListMenuAction>(
                    value: _CardListMenuAction.downloadSampleCsv,
                    child: Text('Download Sample CSV'),
                  ),
                  PopupMenuItem<_CardListMenuAction>(
                    value: _CardListMenuAction.exportCsv,
                    child: Text('Export This Group'),
                  ),
                  PopupMenuItem<_CardListMenuAction>(
                    value: _CardListMenuAction.exportAllCsv,
                    child: Text('Export All Cards'),
                  ),
                  PopupMenuItem<_CardListMenuAction>(
                    value: _CardListMenuAction.importTxt,
                    child: Text('Import TXT'),
                  ),
                  PopupMenuItem<_CardListMenuAction>(
                    value: _CardListMenuAction.downloadSampleTxt,
                    child: Text('Download Sample TXT'),
                  ),
                  PopupMenuItem<_CardListMenuAction>(
                    value: _CardListMenuAction.exportTxt,
                    child: Text('Export This Group TXT'),
                  ),
                  PopupMenuItem<_CardListMenuAction>(
                    value: _CardListMenuAction.exportAllTxt,
                    child: Text('Export All Cards TXT'),
                  ),
                ],
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () => cardProvider.loadCardsByGroup(widget.groupId),
            child: Builder(
              builder: (BuildContext context) {
                if (cardProvider.isLoading && cardProvider.cards.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (cardProvider.errorMessage != null && cardProvider.cards.isEmpty) {
                  return _CardListStatusView(
                    title: 'Could not load cards',
                    message: cardProvider.errorMessage!,
                    icon: Icons.error_outline_rounded,
                  );
                }

                if (cardProvider.cards.isEmpty) {
                  return const _CardListStatusView(
                    title: 'No cards in this group',
                    message: 'Tap the button below to add your first vocabulary card.',
                    icon: Icons.style_outlined,
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  itemCount: cardProvider.cards.length,
                  itemBuilder: (BuildContext context, int index) {
                    final card = cardProvider.cards[index];
                    return Dismissible(
                      key: ValueKey<int>(card.id ?? index),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (_) => _confirmDelete(card.id),
                      onDismissed: (_) async {
                        if (card.id != null) {
                          await context.read<CardProvider>().deleteCard(card.id!);
                          if (context.mounted) {
                            context.read<GroupProvider>().loadGroupsWithCount();
                          }
                        }
                      },
                      background: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.centerRight,
                        child: Icon(
                          Icons.delete_outline_rounded,
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                      child: CardTile(
                        card: card,
                        onTap: () async {
                          if (card.id == null) {
                            return;
                          }

                          await Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => CardDetailScreen(cardId: card.id!),
                            ),
                          );

                          if (context.mounted) {
                            await context.read<CardProvider>().loadCardsByGroup(widget.groupId);
                            context.read<GroupProvider>().loadGroupsWithCount();
                          }
                        },
                        onSpeak: () => TtsService.instance.speak(card.word),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => AddEditCardScreen(
                    initialGroupIds: <int>[widget.groupId],
                  ),
                ),
              );

              if (context.mounted) {
                await context.read<CardProvider>().loadCardsByGroup(widget.groupId);
                context.read<GroupProvider>().loadGroupsWithCount();
              }
            },
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Card'),
          ),
        );
      },
    );
  }

  Future<bool> _confirmDelete(int? cardId) async {
    if (cardId == null) {
      return false;
    }

    return showConfirmDialog(
      context: context,
      title: 'Delete card?',
      message: 'This vocabulary card will be removed from all groups.',
    );
  }

  Future<void> _importFile(ImportExportFormat format) async {
    try {
      final List<ImportedCardRow> rows =
          await CsvService.instance.pickAndParseFile(format);
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

        final List<String> groupNames = row.groupNames.isEmpty
            ? <String>[widget.groupName]
            : row.groupNames;
        final result = await cardProvider.importCardRowWithResult(
          word: row.word,
          partOfSpeech: row.partOfSpeech,
          phonetic: row.phonetic,
          meaning: row.meaning,
          imagePath: row.imagePath,
          groupNames: groupNames,
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

      await cardProvider.loadCardsByGroup(widget.groupId);
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
      _showMessage(error.toString());
    }
  }

  Future<void> _exportFile(ImportExportFormat format) async {
    try {
      final String filePath = format == ImportExportFormat.csv
          ? await CsvService.instance.exportGroupToCsv(
              groupId: widget.groupId,
              groupName: widget.groupName,
            )
          : await CsvService.instance.exportGroupToTxt(
              groupId: widget.groupId,
              groupName: widget.groupName,
            );
      if (!mounted) {
        return;
      }
      _showMessage('${_formatLabel(format)} saved to: $filePath');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage('Export failed: $error');
    }
  }

  Future<void> _exportAllFile(ImportExportFormat format) async {
    try {
      final String filePath = format == ImportExportFormat.csv
          ? await CsvService.instance.exportAllCardsToCsv()
          : await CsvService.instance.exportAllCardsToTxt();
      if (!mounted) {
        return;
      }
      _showMessage('${_formatLabel(format)} saved to: $filePath');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage('Export failed: $error');
    }
  }

  Future<void> _downloadSampleFile(ImportExportFormat format) async {
    try {
      final String filePath = format == ImportExportFormat.csv
          ? await CsvService.instance.createSampleCsvFile()
          : await CsvService.instance.createSampleTxtFile();
      if (!mounted) {
        return;
      }
      _showMessage('Sample ${_formatLabel(format)} saved to: $filePath');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage('Could not create sample CSV: $error');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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
}

enum _CardListMenuAction {
  importCsv,
  downloadSampleCsv,
  exportCsv,
  exportAllCsv,
  importTxt,
  downloadSampleTxt,
  exportTxt,
  exportAllTxt,
}

class _CardListStatusView extends StatelessWidget {
  const _CardListStatusView({
    required this.title,
    required this.message,
    required this.icon,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: <Widget>[
        const SizedBox(height: 120),
        Icon(icon, size: 54, color: theme.colorScheme.primary),
        const SizedBox(height: 16),
        Center(
          child: Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge,
          ),
        ),
      ],
    );
  }
}
