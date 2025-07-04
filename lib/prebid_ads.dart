import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:setupad_prebid_flutter/prebid_ads_controller.dart';

class PrebidAd extends StatelessWidget {
  const PrebidAd({
    Key? key,
    required this.adType,
    required this.configId,
    required this.adUnitId,
    required this.width,
    required this.height,
    required this.refreshInterval,
    required this.controller,
  }) : super(key: key);

  final String adType;
  final String configId;
  final String adUnitId;
  final int width;
  final int height;
  final int refreshInterval;
  final PrebidAdController controller;

  @override
  Widget build(BuildContext context) {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return SizedBox(
          width: adType == "banner" ? width.toDouble() : 1,
          height: adType == "banner" ? height.toDouble() : 1,
          child: AndroidView(
              viewType: 'setupad.plugin.setupad_prebid_flutter',
              onPlatformViewCreated: (int id) {
                onPlatformViewCreated(id);
                controller.setViewId(id);
              }),
        );
      case TargetPlatform.iOS:
        return SizedBox(
          width: adType == "banner" ? width.toDouble() : 1,
          height: adType == "banner" ? height.toDouble() : 1,
          child: UiKitView(
              viewType: 'setupad.plugin.setupad_prebid_flutter',
              onPlatformViewCreated: (int id) {
                onPlatformViewCreated(id);
                controller.setViewId(id);
              }),
        );
      default:
        return Text(
            '$defaultTargetPlatform is not yet supported by the plugin');
    }
  }

  ///A method that passes ad parameters to the PassParameters class
  ///The unique ID is used for method channel communication
  void onPlatformViewCreated(int id) {
    // PassParameters( adType, configId, adUnitId, height, width, refreshInterval, id);
    MethodChannel _channel =
        MethodChannel('setupad.plugin.setupad_prebid_flutter/myChannel_$id');
    debugPrint("PrebidPluginLog on platform view created");
    _channel.invokeMethod('setParams', {
      "adType": adType,
      "configId": configId,
      "adUnitId": adUnitId,
      "height": height,
      "width": width,
      "refreshInterval": refreshInterval
    });
  }
}
