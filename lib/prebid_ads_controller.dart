import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class PrebidAdController {
  int? _viewId;

  void setViewId(int id) {
    _viewId = id;
  }

  bool get _isReady => _viewId != null;

  MethodChannel get _channel =>
      MethodChannel('setupad.plugin.setupad_prebid_flutter/myChannel_$_viewId');

  void pauseAuction() {
    if (_isReady) {
      debugPrint("PrebidPluginLog auction paused");
      _channel.invokeMethod('pauseAuction');
    }
  }

  void resumeAuction() {
    if (_isReady) {
      debugPrint("PrebidPluginLog auction resumed");
      _channel.invokeMethod('resumeAuction');
    }
  }

  void destroyAuction() {
    if (_isReady) {
      debugPrint("PrebidPluginLog auction destroyed");
      _channel.invokeMethod('destroyAuction');
    }
  }
}
