import 'dart:async';
import 'package:flutter/foundation.dart';

/// Coalesces change delivery without changing storage admission or durability.
mixin BatchedNotifications on ChangeNotifier {
  int _notificationDepth = 0;
  bool _notificationPending = false;

  Future<T> batchNotifications<T>(FutureOr<T> Function() action) async {
    _notificationDepth++;
    try {
      return await action();
    } finally {
      _notificationDepth--;
      if (_notificationDepth == 0 && _notificationPending) {
        _notificationPending = false;
        publishBatchedNotification();
      }
    }
  }

  @protected
  void publishBatchedNotification() => super.notifyListeners();

  @override
  void notifyListeners() {
    if (_notificationDepth > 0) {
      _notificationPending = true;
    } else {
      super.notifyListeners();
    }
  }
}
