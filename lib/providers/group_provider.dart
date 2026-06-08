import 'package:flutter/foundation.dart';

import '../database/database_helper.dart';
import '../models/group_model.dart';

class GroupProvider extends ChangeNotifier {
  GroupProvider({DatabaseHelper? databaseHelper})
      : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _databaseHelper;

  List<GroupModel> _groups = <GroupModel>[];
  List<GroupWithCount> _groupsWithCount = <GroupWithCount>[];
  bool _isLoading = false;
  String? _errorMessage;

  List<GroupModel> get groups => List<GroupModel>.unmodifiable(_groups);
  List<GroupWithCount> get groupsWithCount =>
      List<GroupWithCount>.unmodifiable(_groupsWithCount);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasGroups => _groups.isNotEmpty;

  Future<void> loadGroups() async {
    _setLoading(true);
    _clearError();

    try {
      _groups = await _databaseHelper.getAllGroups();
      notifyListeners();
    } catch (error) {
      _setError('Failed to load groups: $error');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadGroupsWithCount() async {
    _setLoading(true);
    _clearError();

    try {
      _groupsWithCount = await _databaseHelper.getGroupsWithCardCount();
      _groups = _groupsWithCount
          .map(
            (GroupWithCount group) => GroupModel(
              id: group.id,
              name: group.name,
              createdAt: group.createdAt,
            ),
          )
          .toList();
      notifyListeners();
    } catch (error) {
      _setError('Failed to load groups with counts: $error');
    } finally {
      _setLoading(false);
    }
  }

  Future<GroupModel?> getGroupById(int groupId) async {
    _clearError();

    try {
      return await _databaseHelper.getGroupById(groupId);
    } catch (error) {
      _setError('Failed to get group: $error');
      return null;
    }
  }

  Future<GroupModel?> addGroup(String name) async {
    final String trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      _setError('Group name cannot be empty.');
      return null;
    }

    _setLoading(true);
    _clearError();

    try {
      final GroupModel group = await _databaseHelper.createGroupIfNotExists(trimmedName);
      await _reloadCollections();
      return group;
    } catch (error) {
      _setError('Failed to add group: $error');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> deleteGroup(int groupId) async {
    _setLoading(true);
    _clearError();

    try {
      await _databaseHelper.deleteGroup(groupId);
      await _reloadCollections();
      return true;
    } catch (error) {
      _setError('Failed to delete group: $error');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  GroupModel? findGroupById(int groupId) {
    try {
      return _groups.firstWhere((GroupModel group) => group.id == groupId);
    } catch (_) {
      return null;
    }
  }

  GroupModel? findGroupByName(String name) {
    final String normalizedQuery = name.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return null;
    }

    try {
      return _groups.firstWhere(
        (GroupModel group) => group.name.trim().toLowerCase() == normalizedQuery,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> refresh() async {
    await _reloadCollections();
  }

  void clearError() {
    if (_errorMessage == null) {
      return;
    }

    _errorMessage = null;
    notifyListeners();
  }

  Future<void> _reloadCollections() async {
    _groupsWithCount = await _databaseHelper.getGroupsWithCardCount();
    _groups = _groupsWithCount
        .map(
          (GroupWithCount group) => GroupModel(
            id: group.id,
            name: group.name,
            createdAt: group.createdAt,
          ),
        )
        .toList();
    notifyListeners();
  }

  void _setLoading(bool value) {
    if (_isLoading == value) {
      return;
    }

    _isLoading = value;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }
}
