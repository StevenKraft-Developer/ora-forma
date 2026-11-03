import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/group.dart';
import '../models/group_invitation.dart';
import '../services/group_service.dart';

class GroupProvider extends ChangeNotifier {
  GroupProvider(this._service);

  final GroupService _service;

  String? _uid;
  int _sessionVersion = 0;
  bool _isDisposed = false;

  List<Group> _groups = [];
  String? _selectedGroupId;

  bool _isLoading = false;
  bool _isLoaded = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  List<Group> get groups => List.unmodifiable(_groups);
  String? get selectedGroupId => _selectedGroupId;

  bool get isLoading => _isLoading;
  bool get isLoaded => _isLoaded;
  bool get hasGroups => _groups.isNotEmpty;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;

  Group? get selectedGroup {
    for (final group in _groups) {
      if (group.id == _selectedGroupId) return group;
    }

    return null;
  }

  bool _isCurrentSession(int version, String uid) {
    return !_isDisposed && version == _sessionVersion && uid == _uid;
  }

  /// Synchronizes account state from a ProxyProvider update.
  ///
  /// Clears old state immediately, but defers notifications and loading
  /// until after the synchronous provider update has finished.
  void syncAccount({required String? uid}) {
    if (_isDisposed || _uid == uid) return;

    final version = ++_sessionVersion;

    _uid = uid;
    _groups = [];
    _selectedGroupId = null;
    _isLoading = false;
    _isLoaded = false;
    _isSubmitting = false;
    _errorMessage = null;

    unawaited(
      Future<void>.microtask(() async {
        if (_isDisposed || version != _sessionVersion || _uid != uid) {
          return;
        }

        if (uid == null) {
          notifyListeners();
          return;
        }

        await _loadCurrentAccount();
      }),
    );
  }

  Future<void> loadGroups(String uid) async {
    if (_isDisposed) return;

    if (_uid == uid && (_isLoaded || _isLoading)) {
      return;
    }

    if (_uid != uid) {
      _sessionVersion++;
      _uid = uid;
      _groups = [];
      _selectedGroupId = null;
      _isLoaded = false;
      _isSubmitting = false;
      _errorMessage = null;
    }

    await _loadCurrentAccount();
  }

  Future<void> refresh() async {
    if (_isDisposed || _uid == null || _isLoading || _isSubmitting) {
      return;
    }

    await _loadCurrentAccount();
  }

  Future<void> _loadCurrentAccount() async {
    final uid = _uid;
    if (_isDisposed || uid == null) return;

    final version = _sessionVersion;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final loadedGroups = await _service.loadGroups(uid);

      if (!_isCurrentSession(version, uid)) return;

      _groups = List<Group>.from(loadedGroups);

      final selectionStillExists = _groups.any(
        (group) => group.id == _selectedGroupId,
      );

      if (!selectionStillExists) {
        _selectedGroupId = _groups.isEmpty ? null : _groups.first.id;
      }

      _isLoaded = true;
    } catch (_) {
      if (!_isCurrentSession(version, uid)) return;

      // Do not leave previously loaded membership visible after
      // a failed attempt to verify the current group list.
      _groups = [];
      _selectedGroupId = null;
      _isLoaded = false;
      _errorMessage = 'Your groups could not be loaded. Please try again.';
    } finally {
      if (_isCurrentSession(version, uid)) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<String?> createGroup({required String name, String? description}) {
    return _runAction<String>(
      operation: () =>
          _service.createGroup(name: name, description: description),
      failureMessage: 'The group could not be created. Please try again.',
      reloadGroups: true,
      selectResultGroup: (groupId) => groupId,
    );
  }

  Future<GroupInvitation?> createGroupInvite({required String groupId}) {
    return _runAction<GroupInvitation>(
      operation: () => _service.createGroupInvite(groupId: groupId),
      failureMessage:
          'The invitation could not be created. Check that you are the group owner and try again.',
    );
  }

  Future<JoinGroupResult?> joinGroup({required String inviteCode}) {
    return _runAction<JoinGroupResult>(
      operation: () => _service.joinGroup(inviteCode: inviteCode),
      failureMessage:
          'The group could not be joined. Check the invitation code and try again.',
      reloadGroups: true,
      selectResultGroup: (result) => result.groupId,
    );
  }

  Future<LeaveGroupResult?> leaveGroup({required String groupId}) {
    return _runAction<LeaveGroupResult>(
      operation: () => _service.leaveGroup(groupId: groupId),
      failureMessage:
          'The group could not be left. Group owners cannot leave yet.',
      reloadGroups: true,
    );
  }

  Future<T?> _runAction<T>({
    required Future<T> Function() operation,
    required String failureMessage,
    bool reloadGroups = false,
    String Function(T result)? selectResultGroup,
  }) async {
    final uid = _uid;

    if (_isDisposed || uid == null || _isLoading || _isSubmitting) {
      return null;
    }

    final version = _sessionVersion;

    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await operation();

      if (!_isCurrentSession(version, uid)) return null;

      if (reloadGroups) {
        await _loadCurrentAccount();

        if (!_isCurrentSession(version, uid)) return null;

        if (_isLoaded && selectResultGroup != null) {
          selectGroup(selectResultGroup(result));
        }
      }

      return result;
    } catch (_) {
      if (!_isCurrentSession(version, uid)) return null;

      _errorMessage = failureMessage;
      return null;
    } finally {
      if (_isCurrentSession(version, uid)) {
        _isSubmitting = false;
        notifyListeners();
      }
    }
  }

  void selectGroup(String groupId) {
    if (_isDisposed || _selectedGroupId == groupId) return;

    if (!_groups.any((group) => group.id == groupId)) return;

    _selectedGroupId = groupId;
    notifyListeners();
  }

  void clear() {
    if (_isDisposed) return;

    _sessionVersion++;
    _uid = null;
    _groups = [];
    _selectedGroupId = null;
    _isLoading = false;
    _isLoaded = false;
    _isSubmitting = false;
    _errorMessage = null;

    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _sessionVersion++;
    super.dispose();
  }
}
