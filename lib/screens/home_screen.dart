import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../database/database_helper.dart';
import '../models/group_model.dart';
import '../providers/card_provider.dart';
import '../providers/group_provider.dart';
import '../widgets/group_tile.dart';
import 'card_list_screen.dart';
import 'data_screen.dart';
import 'review_setup_screen.dart';
import 'review_session_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GroupProvider>().loadGroupsWithCount();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: const <Widget>[
          _HomeGroupsView(),
          DataScreen(),
          SettingsScreen(),
        ],
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton.extended(
              onPressed: _showCreateGroupDialog,
              icon: const Icon(Icons.add_rounded),
              label: const Text('New Group'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.storage_outlined),
            selectedIcon: Icon(Icons.storage_rounded),
            label: 'Data',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  Future<void> _showCreateGroupDialog() async {
    final String? groupName = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => const _CreateGroupDialog(),
    );

    if (!mounted || groupName == null || groupName.trim().isEmpty) {
      return;
    }

    final GroupProvider groupProvider = context.read<GroupProvider>();
    final result = await groupProvider.addGroup(groupName);
    if (!mounted) {
      return;
    }

    if (result == null) {
      _showMessage(groupProvider.errorMessage ?? 'Unable to create group.');
      return;
    }

    _showMessage('Group created.');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _HomeGroupsView extends StatelessWidget {
  const _HomeGroupsView();

  @override
  Widget build(BuildContext context) {
    return Consumer<GroupProvider>(
      builder: (BuildContext context, GroupProvider groupProvider, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('FlashLang'),
            actions: <Widget>[
              IconButton(
                tooltip: 'Review',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ReviewSetupScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.school_outlined),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: groupProvider.loadGroupsWithCount,
            child: Builder(
              builder: (BuildContext context) {
                if (groupProvider.isLoading &&
                    groupProvider.groupsWithCount.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (groupProvider.errorMessage != null &&
                    groupProvider.groupsWithCount.isEmpty) {
                  return _StatusView(
                    icon: Icons.error_outline_rounded,
                    title: 'Could not load groups',
                    message: groupProvider.errorMessage!,
                  );
                }

                if (groupProvider.groupsWithCount.isEmpty) {
                  return const _StatusView(
                    icon: Icons.style_outlined,
                    title: 'No groups yet',
                    message:
                        'Create your first flashcard group to get started.',
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.05,
                  ),
                  itemCount: groupProvider.groupsWithCount.length,
                  itemBuilder: (BuildContext context, int index) {
                    final group = groupProvider.groupsWithCount[index];
                    return GroupTile(
                      group: group,
                      onEdit: () =>
                          _showRenameGroupDialog(context, group.id, group.name),
                      onDelete: () =>
                          _confirmDeleteGroup(context, group.id, group.name),
                      onReview: () => _openGroupReview(context, group),
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => CardListScreen(
                              groupId: group.id!,
                              groupName: group.name,
                            ),
                          ),
                        );

                        if (context.mounted) {
                          context.read<GroupProvider>().loadGroupsWithCount();
                        }
                      },
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _openGroupReview(
    BuildContext context,
    GroupWithCount group,
  ) async {
    if (group.id == null) {
      return;
    }

    final List<ReviewCardData> reviewCards = await context
        .read<CardProvider>()
        .getReviewCards(groupIds: <int>[group.id!]);
    if (!context.mounted) {
      return;
    }

    if (reviewCards.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No cards found in "${group.name}".')),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReviewSessionScreen(cards: reviewCards),
      ),
    );
  }

  Future<void> _confirmDeleteGroup(
    BuildContext context,
    int? groupId,
    String groupName,
  ) async {
    if (groupId == null) {
      return;
    }

    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              title: const Text('Delete group?'),
              content: Text(
                'Delete "$groupName" and all cards that belong to this group?',
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmed || !context.mounted) {
      return;
    }

    final GroupProvider groupProvider = context.read<GroupProvider>();
    final bool success = await groupProvider.deleteGroup(groupId);
    if (!context.mounted) {
      return;
    }

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            groupProvider.errorMessage ?? 'Unable to delete group.',
          ),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Deleted "$groupName".')));
  }

  Future<void> _showRenameGroupDialog(
    BuildContext context,
    int? groupId,
    String currentName,
  ) async {
    if (groupId == null) {
      return;
    }

    final String? updatedName = await showDialog<String>(
      context: context,
      builder: (BuildContext context) =>
          _CreateGroupDialog(title: 'Rename Group', initialValue: currentName),
    );

    if (!context.mounted || updatedName == null || updatedName.trim().isEmpty) {
      return;
    }

    final GroupProvider groupProvider = context.read<GroupProvider>();
    final GroupModel? group = await groupProvider.renameGroup(
      groupId,
      updatedName,
    );
    if (!context.mounted) {
      return;
    }

    if (group == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            groupProvider.errorMessage ?? 'Unable to rename group.',
          ),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Group updated.')));
  }
}

class _CreateGroupDialog extends StatefulWidget {
  const _CreateGroupDialog({
    this.title = 'Create Group',
    this.initialValue = '',
  });

  final String title;
  final String initialValue;

  @override
  State<_CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends State<_CreateGroupDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.none,
        decoration: const InputDecoration(
          labelText: 'Group name',
          hintText: 'Example: fruits',
        ),
        textInputAction: TextInputAction.done,
        onSubmitted: (_) {
          Navigator.of(context).pop(_controller.text.trim());
        },
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _StatusView extends StatelessWidget {
  const _StatusView({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: <Widget>[
        const SizedBox(height: 120),
        Icon(icon, size: 56, color: theme.colorScheme.primary),
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
