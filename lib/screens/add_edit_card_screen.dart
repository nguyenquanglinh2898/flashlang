import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/card_model.dart';
import '../models/group_model.dart';
import '../providers/card_provider.dart';
import '../providers/group_provider.dart';
import '../widgets/multi_select_group.dart';

class AddEditCardScreen extends StatefulWidget {
  const AddEditCardScreen({
    super.key,
    this.cardId,
    this.initialGroupIds = const <int>[],
  });

  final int? cardId;
  final List<int> initialGroupIds;

  bool get isEdit => cardId != null;

  @override
  State<AddEditCardScreen> createState() => _AddEditCardScreenState();
}

class _AddEditCardScreenState extends State<AddEditCardScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _wordController = TextEditingController();
  final TextEditingController _phoneticController = TextEditingController();
  final TextEditingController _meaningController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  bool _isSaving = false;
  bool _isLoadingInitialData = false;
  List<int> _selectedGroupIds = <int>[];
  String? _imagePath;
  DateTime? _createdAt;
  DateTime? _lastPushedAt;

  @override
  void initState() {
    super.initState();
    _selectedGroupIds = List<int>.from(widget.initialGroupIds);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<GroupProvider>().loadGroups();
      if (widget.isEdit) {
        await _loadExistingCard();
      }
    });
  }

  @override
  void dispose() {
    _wordController.dispose();
    _phoneticController.dispose();
    _meaningController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final GroupProvider groupProvider = context.watch<GroupProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEdit ? 'Edit Card' : 'Add Card'),
      ),
      body: _isLoadingInitialData
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: <Widget>[
                  TextFormField(
                    controller: _wordController,
                    decoration: const InputDecoration(
                      labelText: 'Word',
                      hintText: 'Example: Apple',
                    ),
                    textCapitalization: TextCapitalization.none,
                    validator: (String? value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Word is required.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _phoneticController,
                    decoration: const InputDecoration(
                      labelText: 'Phonetic',
                      hintText: 'Example: /ˈae.pəl/',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _meaningController,
                    decoration: const InputDecoration(
                      labelText: 'Meaning',
                      hintText: 'Example: Quả táo',
                    ),
                    maxLines: 3,
                    validator: (String? value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Meaning is required.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Image',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 12),
                  if (_imagePath != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 280),
                        width: double.infinity,
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        child: Image.file(
                          File(_imagePath!),
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Container(
                            height: 140,
                            alignment: Alignment.center,
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            child: const Text('Image not available'),
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      height: 160,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      alignment: Alignment.center,
                      child: const Text('No image selected'),
                    ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: <Widget>[
                      FilledButton.icon(
                        onPressed: _pickImage,
                        icon: const Icon(Icons.image_outlined),
                        label: Text(_imagePath == null ? 'Choose Image' : 'Change Image'),
                      ),
                      if (_imagePath != null)
                        OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _imagePath = null;
                            });
                          },
                          icon: const Icon(Icons.close_rounded),
                          label: const Text('Remove Image'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  MultiSelectGroup(
                    groups: groupProvider.groups,
                    selectedGroupIds: _selectedGroupIds,
                    onSelectionChanged: (List<int> groupIds) {
                      setState(() {
                        _selectedGroupIds = groupIds;
                      });
                    },
                    onCreateGroup: (String name) async {
                      final GroupModel? group =
                          await context.read<GroupProvider>().addGroup(name);
                      if (group != null && mounted) {
                        await context.read<GroupProvider>().loadGroups();
                      }
                      return group;
                    },
                  ),
                  const SizedBox(height: 32),
                  FilledButton(
                    onPressed: _isSaving ? null : _saveCard,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Future<void> _loadExistingCard() async {
    setState(() {
      _isLoadingInitialData = true;
    });

    try {
      final CardProvider cardProvider = context.read<CardProvider>();
      final CardModel? card = await cardProvider.getCardById(widget.cardId!);
      final List<int> groupIds = await cardProvider.getSelectedGroupIds(widget.cardId!);

      if (!mounted || card == null) {
        return;
      }

      setState(() {
        _wordController.text = card.word;
        _phoneticController.text = card.phonetic ?? '';
        _meaningController.text = card.meaning;
        _imagePath = card.imagePath;
        _selectedGroupIds = groupIds;
        _createdAt = card.createdAt;
        _lastPushedAt = card.lastPushedAt;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingInitialData = false;
        });
      }
    }
  }

  Future<void> _pickImage() async {
    final XFile? image = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (image == null || !mounted) {
      return;
    }

    setState(() {
      _imagePath = image.path;
    });
  }

  Future<void> _saveCard() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final CardProvider cardProvider = context.read<CardProvider>();
      final List<int> groupIds = _selectedGroupIds.toSet().toList();

      if (widget.isEdit) {
        final bool success = await cardProvider.updateCard(
          cardId: widget.cardId!,
          word: _wordController.text.trim(),
          phonetic: _phoneticController.text.trim(),
          meaning: _meaningController.text.trim(),
          imagePath: _imagePath,
          groupIds: groupIds,
          createdAt: _createdAt,
          lastPushedAt: _lastPushedAt,
        );

        if (!mounted) {
          return;
        }

        if (!success) {
          _showMessage(cardProvider.errorMessage ?? 'Failed to update card.');
          return;
        }
      } else {
        final int? cardId = await cardProvider.addCard(
          word: _wordController.text.trim(),
          phonetic: _phoneticController.text.trim(),
          meaning: _meaningController.text.trim(),
          imagePath: _imagePath,
          groupIds: groupIds,
        );

        if (!mounted) {
          return;
        }

        if (cardId == null) {
          _showMessage(cardProvider.errorMessage ?? 'Failed to add card.');
          return;
        }
      }

      await context.read<GroupProvider>().loadGroupsWithCount();
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
