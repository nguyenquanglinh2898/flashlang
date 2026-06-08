import 'package:flutter/material.dart';

import '../models/card_model.dart';

class CardTile extends StatelessWidget {
  const CardTile({
    super.key,
    required this.card,
    required this.onTap,
    required this.onSpeak,
  });

  final CardModel card;
  final VoidCallback onTap;
  final VoidCallback onSpeak;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          card.word,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (card.hasPartOfSpeech)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    card.partOfSpeech!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              Text(
                card.meaning,
                style: theme.textTheme.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        trailing: IconButton(
          tooltip: 'Pronounce word',
          onPressed: onSpeak,
          icon: const Icon(Icons.volume_up_rounded),
        ),
      ),
    );
  }
}
