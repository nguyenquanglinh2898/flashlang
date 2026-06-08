import 'package:flutter/material.dart';

import '../models/group_model.dart';

typedef CreateGroupCallback = Future<GroupModel?> Function(String name);
typedef SelectionChangedCallback = ValueChanged<List<int>>;

class MultiSelectGroup extends StatefulWidget {
  const MultiSelectGroup({
    super.key,
    required this.groups,
    required this.selectedGroupIds,
    required this.onSelectionChanged,
    required this.onCreateGroup,
    this.labelText = 'Groups',
  });

  final List<GroupModel> groups;
  final List<int> selectedGroupIds;
  final SelectionChangedCallback onSelectionChanged;
  final CreateGroupCallback onCreateGroup;
  final String labelText;

  @override
  State<MultiSelectGroup> createState() => _MultiSelectGroupState();
}

class _MultiSelectGroupState extends State<MultiSelectGroup> {
  late final TextEditingController _groupNameController;
  late List<int> _selectedGroupIds;
  bool _isCreatingGroup = false;

  @override
  void initState() {
    super.initState();
    _groupNameController = TextEditingController();
    _selectedGroupIds = List<int>.from(widget.selectedGroupIds);
  }

  @override
  void didUpdateWidget(covariant MultiSelectGroup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedGroupIds != widget.selectedGroupIds) {
      _selectedGroupIds = List<int>.from(widget.selectedGroupIds);
    }
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          widget.labelText,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        if (widget.groups.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border.all(color: theme.dividerColor),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'No groups yet. Create one below.',
              style: theme.textTheme.bodyMedium,
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.groups.map(_buildGroupChip).toList(),
          ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _groupNameController,
                textCapitalization: TextCapitalization.none,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Create group inline',
                  hintText: 'Example: daily',
                ),
                onSubmitted: (_) => _createGroup(),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: _isCreatingGroup ? null : _createGroup,
              icon: _isCreatingGroup
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_rounded),
              label: const Text('Add'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGroupChip(GroupModel group) {
    final bool isSelected = _selectedGroupIds.contains(group.id);

    return FilterChip(
      label: Text(group.name),
      selected: isSelected,
      onSelected: (_) => _toggleSelection(group.id),
    );
  }

  void _toggleSelection(int? groupId) {
    if (groupId == null) {
      return;
    }

    setState(() {
      if (_selectedGroupIds.contains(groupId)) {
        _selectedGroupIds.remove(groupId);
      } else {
        _selectedGroupIds.add(groupId);
      }
    });

    widget.onSelectionChanged(List<int>.from(_selectedGroupIds));
  }

  Future<void> _createGroup() async {
    final String name = _groupNameController.text.trim();
    if (name.isEmpty || _isCreatingGroup) {
      return;
    }

    setState(() {
      _isCreatingGroup = true;
    });

    try {
      final GroupModel? newGroup = await widget.onCreateGroup(name);
      if (!mounted) {
        return;
      }

      if (newGroup?.id != null && !_selectedGroupIds.contains(newGroup!.id)) {
        setState(() {
          _selectedGroupIds.add(newGroup.id!);
          _groupNameController.clear();
        });
        widget.onSelectionChanged(List<int>.from(_selectedGroupIds));
      } else {
        setState(() {
          _groupNameController.clear();
        });
      }
    } finally {
      if (!mounted) {
        return;
      }

      setState(() {
        _isCreatingGroup = false;
      });
    }
  }
}
