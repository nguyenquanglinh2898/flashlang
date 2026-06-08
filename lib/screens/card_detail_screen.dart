import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/card_provider.dart';
import '../providers/group_provider.dart';
import '../services/tts_service.dart';
import '../widgets/confirm_dialog.dart';
import 'add_edit_card_screen.dart';

class CardDetailScreen extends StatefulWidget {
  const CardDetailScreen({
    super.key,
    required this.cardId,
  });

  final int cardId;

  @override
  State<CardDetailScreen> createState() => _CardDetailScreenState();
}

class _CardDetailScreenState extends State<CardDetailScreen> {
  CardDetailData? _detail;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadCardDetail();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Card Detail'),
      ),
      body: Builder(
        builder: (BuildContext context) {
          if (_isLoading && _detail == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_detail == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _errorMessage ?? 'Card not found.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final card = _detail!.card;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        card.word,
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    IconButton.filledTonal(
                      onPressed: () => TtsService.instance.speak(card.word),
                      icon: const Icon(Icons.volume_up_rounded),
                    ),
                  ],
                ),
                if (card.hasPhonetic) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(
                    card.phonetic!,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                ],
                if (card.hasPartOfSpeech) ...<Widget>[
                  const SizedBox(height: 12),
                  Chip(
                    label: Text(card.partOfSpeech!),
                  ),
                ],
                const SizedBox(height: 20),
                Text(
                  'Meaning',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  card.meaning,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                if (card.hasImage) ...<Widget>[
                  const SizedBox(height: 24),
                  Text(
                    'Image',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 360),
                      width: double.infinity,
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: Image.file(
                        File(card.imagePath!),
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) {
                          return Container(
                            height: 180,
                            alignment: Alignment.center,
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            child: const Text('Image not available'),
                          );
                        },
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Text(
                  'Groups',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 12),
                if (_detail!.groups.isEmpty)
                  const Text('This card is not assigned to any group.')
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _detail!.groups
                        .map((group) => Chip(label: Text(group.name)))
                        .toList(),
                  ),
                const SizedBox(height: 32),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => AddEditCardScreen(cardId: widget.cardId),
                            ),
                          );

                          if (context.mounted) {
                            await _loadCardDetail();
                            context.read<GroupProvider>().loadGroupsWithCount();
                          }
                        },
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Edit'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: _deleteCard,
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: const Text('Delete'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _loadCardDetail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final CardDetailData? detail =
        await context.read<CardProvider>().getCardDetail(widget.cardId);

    if (!mounted) {
      return;
    }

    setState(() {
      _detail = detail;
      _errorMessage = detail == null
          ? (context.read<CardProvider>().errorMessage ?? 'Card not found.')
          : null;
      _isLoading = false;
    });
  }

  Future<void> _deleteCard() async {
    final bool confirmed = await showConfirmDialog(
      context: context,
      title: 'Delete card?',
      message: 'This action cannot be undone.',
    );

    if (!confirmed || !mounted) {
      return;
    }

    final bool deleted = await context.read<CardProvider>().deleteCard(widget.cardId);
    if (!mounted) {
      return;
    }

    if (deleted) {
      await context.read<GroupProvider>().loadGroupsWithCount();
      Navigator.of(context).pop();
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.read<CardProvider>().errorMessage ?? 'Failed to delete card.',
        ),
      ),
    );
  }
}
