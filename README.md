# Setupad Prebid plugin

This is a [Setupad's] Flutter plugin that allows its user to display [Prebid Mobile SDK] banner and interstitial ads in Flutter mobile applications.

# Plugin integration
## Prerequisites
* Flutter version at least `2.10.5`
### Android
* `minSdkVersion` at least `24`
* `compileSdkVersion` at least `33`

### iOS
* Minimum deployment target at least `12.0`

## pubspec.yaml
In your `pubspec.yaml` file’s dependencies include Setupad's Prebid plugin for Flutter and run 'flutter pub get' command in the terminal.
```yaml
dependencies:
 setupad_prebid_flutter: 1.0.0
```

## Adding app ID
After adding plugin to your project, the next step is to add Google Ad Manager app ID to the project.
### Android
Locate your `AndroidManifest.xml` file, then include the `<meta-data>` tag inside the `<application>` tag with your app ID.
```xml
<application>
   <meta-data
       android:name="com.google.android.gms.ads.APPLICATION_ID"
       android:value="ca-app-pub-################~##########"/>
   <!--...-->
</application>
```


### iOS
Locate your `Info.plist` file, then include the `GADApplicationIdentifier` with your app ID  provided by Google Ad Manager. It is optional to include [SKAdNetworkItems] items to your `Info.plist` file.
```xml
<key>GADApplicationIdentifier</key>
<string>ca-app-pub-################~##########</string>
```

## SDK initialization
Prebid Mobile initialization is only needed to be done once and it is recommended to initialize it as early as possible in your project.
To initialize it, first include this import in your Dart file:
```dart
import 'package:setupad_prebid_flutter/prebid_mobile.dart';
```

Then, add `initializeSDK()`method.
```dart
const PrebidMobile().initializeSDK(ACCOUNT_ID, TIMEOUT, PBSDEBUG)
```
* `ACCOUNT_ID` is a placeholder for your Prebid account ID.
*  `TIMEOUT` is a parameter that sets how much time bidders have to submit their bids. It is important to choose a sufficient timeout - if it is too short, there is a chance to get less bids, and if it is too long, it can slow down ad loading and user might wait too long for the ads to appear.
* `PBSDEBUG` is a boolean type parameter, if it is set to `true`, it adds a debug flag (“test”: 1) into Prebid auction request, which allows to display only test ads and see full Prebid auction response. If none of this is required, you can set it to false.

# Ads integration
Currently this plugin supports two ad formats: banners and interstitial ads. When creating ad object, it is necessary to specify what ad type it is. Ad type can be written in lowercase (“banner”), uppercase (“BANNER”) or capitalization (“Banner”).

The first step in displaying ads is to import ads library:
```dart
import 'package:setupad_prebid_flutter/prebid_ads.dart';
```

## Banner
To display a banner, you need to create a `PrebidAd` class object inside your widget.
```dart
final _bannerController = PrebidAdController();
//...
@override
  Widget build(BuildContext context) {
    //...
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children:[
            PrebidAd(
                adType: 'banner',
                configId: 'CONFIG_ID',
                adUnitId: 'AD_UNIT_ID',
                width: 300,
                height: 250,
                refreshInterval: 30,
                controller: _bannerController,
              );, 
            //..
         ],
        ),
      ),
    );
  }
```
`AD_UNIT_ID` and `CONFIG_ID` are placeholders for the ad unit ID and config ID parameters. The minimum refresh interval is 30 seconds, and the maximum is 120 seconds.

### Controlling banner auction
It is necessary to stop the auction when leaving a screen where the banner ad is displayed because if not stopped, the auction continues happening and displaying ads that are not seen by anyone. To avoid this, use `pauseAuction()` and `resumeAuction` methods. In addition, if there is a need, a banner object can be destroyed using the `destroyAuction` method.
```dart
_bannerController.pause();
_bannerController.resume();
_bannerController.destroy();
```
To correctly control Prebid auction, you need to use the banner controller; in this case it is `_bannerController`.

## Interstitial ad
To display an interstitial ad, you need to use a `PrebidAd` class object.
```dart
  final _interstitialController = PrebidAdController();

  //...

  PrebidAd(
    adType: 'interstitial',
    configId: CONFIG_ID,
    adUnitId: AD_UNIT_D,
    width: 80,
    height: 60,
    refreshInterval: 0,
    controller: _interstitialController,
  );
```
`AD_UNIT_ID` and `CONFIG_ID` are placeholders. The refresh interval is set to zero because interstitial ads do not refresh. Unlike in the banner ads, in the interstitial ads the width and height variables are used to indicate the minimum screen's width and height in percent that the interstitial ad can take. In this case 80x60 means that the minimum width of the interstitial ad will be at least 80% of the screen and at least 60% of the height. As these size parameters are optional, you can opt out of specifying them by writing zero as their value.

If you want to display an interstitial ad on button press, it is necessary to use `setState()` with a boolean variable.
```dart
bool _showInterstitial = false;
//...
ElevatedButton(
  child: const Text('Press me!'),
  onPressed: () {
    setState(() {
      _showInterstitial = true;
    });
  },
),
if (_showInterstitial)
  PrebidAd(
    adType: 'interstitial',
    configId: CONFIG_ID,
    adUnitId: AD_UNIT_D,
    width: 80,
    height: 60,
    refreshInterval: 0,
    controller: _interstitialController,
  );
),
//...
```

----
[Setupad's]: https://setupad.com/
