import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../database/database_helper.dart';
import '../providers/card_provider.dart';
import '../providers/group_provider.dart';
import 'review_session_screen.dart';

class ReviewSetupScreen extends StatefulWidget {
  const ReviewSetupScreen({
    super.key,
    this.initialSelectedGroupIds = const <int>[],
  });

  final List<int> initialSelectedGroupIds;

  @override
  State<ReviewSetupScreen> createState() => _ReviewSetupScreenState();
}

class _ReviewSetupScreenState extends State<ReviewSetupScreen> {
  final Set<int> _selectedGroupIds = <int>{};
  bool _isLoadingCards = false;

  @override
  void initState() {
    super.initState();
    _selectedGroupIds.addAll(widget.initialSelectedGroupIds);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GroupProvider>().loadGroupsWithCount();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GroupProvider>(
      builder: (BuildContext context, GroupProvider groupProvider, _) {
        final List<GroupWithCount> groups = groupProvider.groupsWithCount;

        final bool allSelected =
            groups.isNotEmpty &&
            groups.every(
              (GroupWithCount group) => _selectedGroupIds.contains(group.id),
            );

        return Scaffold(
          appBar: AppBar(title: const Text('Review')),
          body: RefreshIndicator(
            onRefresh: groupProvider.loadGroupsWithCount,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: <Widget>[
                Text(
                  'Choose groups to review',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  'We will shuffle all cards from the selected groups and show one card at a time.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                Card(
                  child: ListTile(
                    leading: Checkbox(
                      value: allSelected,
                      onChanged: groups.isEmpty
                          ? null
                          : (bool? value) {
                              setState(() {
                                if (value ?? false) {
                                  _selectedGroupIds
                                    ..clear()
                                    ..addAll(
                                      groups
                                          .map(
                                            (GroupWithCount group) => group.id,
                                          )
                                          .whereType<int>(),
                                    );
                                } else {
                                  _selectedGroupIds.clear();
                                }
                              });
                            },
                    ),
                    title: const Text('All groups'),
                    subtitle: Text('${groups.length} group(s)'),
                    onTap: groups.isEmpty
                        ? null
                        : () {
                            setState(() {
                              if (allSelected) {
                                _selectedGroupIds.clear();
                              } else {
                                _selectedGroupIds
                                  ..clear()
                                  ..addAll(
                                    groups
                                        .map((GroupWithCount group) => group.id)
                                        .whereType<int>(),
                                  );
                              }
                            });
                          },
                  ),
                ),
                const SizedBox(height: 12),
                if (groupProvider.isLoading && groups.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (groups.isEmpty)
                  const _ReviewStatusView(
                    icon: Icons.style_outlined,
                    title: 'No groups available',
                    message:
                        'Create a group and add some cards before starting review.',
                  )
                else
                  ...groups.map(
                    (GroupWithCount group) => Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: Checkbox(
                          value: _selectedGroupIds.contains(group.id),
                          onChanged: group.id == null
                              ? null
                              : (bool? value) {
                                  setState(() {
                                    if (value ?? false) {
                                      _selectedGroupIds.add(group.id!);
                                    } else {
                                      _selectedGroupIds.remove(group.id);
                                    }
                                  });
                                },
                        ),
                        title: Text(group.name),
                        subtitle: Text('${group.cardCount} card(s)'),
                        onTap: group.id == null
                            ? null
                            : () {
                                setState(() {
                                  if (_selectedGroupIds.contains(group.id)) {
                                    _selectedGroupIds.remove(group.id);
                                  } else {
                                    _selectedGroupIds.add(group.id!);
                                  }
                                });
                              },
                      ),
                    ),
                  ),
              ],
            ),
          ),
          bottomNavigationBar: SafeArea(
            minimum: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: FilledButton.icon(
              onPressed: _isLoadingCards ? null : _startReview,
              icon: _isLoadingCards
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow_rounded),
              label: const Text('Start Review'),
            ),
          ),
        );
      },
    );
  }

  Future<void> _startReview() async {
    if (_selectedGroupIds.isEmpty) {
      _showMessage('Select at least one group.');
      return;
    }

    setState(() {
      _isLoadingCards = true;
    });

    try {
      final reviewCards = await context.read<CardProvider>().getReviewCards(
        groupIds: _selectedGroupIds.toList(),
      );
      if (!mounted) {
        return;
      }

      if (reviewCards.isEmpty) {
        _showMessage('No cards found in the selected groups.');
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ReviewSessionScreen(cards: reviewCards),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingCards = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ReviewStatusView extends StatelessWidget {
  const _ReviewStatusView({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(icon, size: 40, color: colorScheme.primary),
          const SizedBox(height: 12),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
