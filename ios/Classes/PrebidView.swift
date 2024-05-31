import Foundation
import Flutter
import UIKit
import PrebidMobile
import GoogleMobileAds
import AppTrackingTransparency
import OSLog
import os

///A class that is responsible for creating and adding banner and interstitial ads to the Flutter app's view, as well as pausing and resuming auction
class PrebidView: NSObject, FlutterPlatformView, GADBannerViewDelegate, GADFullScreenContentDelegate {
    private var _methodChannel: FlutterMethodChannel
    private var bannerLayout: UIView!

    private var gamBanner: GAMBannerView!
    private var bannerAdUnit: BannerAdUnit!
    private var interstitialAdUnit: InterstitialAdUnit!

    private var errorText: String
    let customLog = OSLog(subsystem: "setupad.prebid.plugin", category: "PrebidPluginLog")

    ///Setting channel method, configuring banner layout and checking tracking permission
    init(frame: CGRect,
         viewIdentifier viewId: Int64,
         arguments args: Any?,
         binaryMessenger messenger: FlutterBinaryMessenger) {
        _methodChannel = FlutterMethodChannel(name: "setupad.plugin.setupad_prebid_flutter/myChannel_\(viewId)", binaryMessenger: messenger)
        errorText="No errors"
        super.init()

        _methodChannel.setMethodCallHandler(onMethodCall)

        bannerLayout=UIView(frame: frame)

        if #available(iOS 14, *) {
            ATTrackingManager.requestTrackingAuthorization { status in
                if status == .authorized {
                    os_log("Permission to track granted", log: self.customLog, type: .info)
                } else {
                    os_log("Permission to track denied", log: self.customLog, type: .info)
                }
            }
        } else {
            os_log("Not available on iOS versions prior to 14", log: customLog, type: .info)
        }
    }

    ///Adding a view to the UI where banner will be added
    func view() -> UIView {
        return bannerLayout
    }

    ///Disposing view and destroying Prebid auction
    func dispose() {
        bannerLayout = nil
        _methodChannel.setMethodCallHandler(nil)
        onDestroy()
    }

    ///Checking which method was called and then calling the corresponding method
    func onMethodCall(call: FlutterMethodCall, result: FlutterResult) {
        switch(call.method){
        case "setParams":
            settingParameters(call:call, result:result)
        case "pauseAuction":
            onPause()
        case "resumeAuction":
            onResume()
        case "destroyAuction":
            onDestroy()
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    ///Getting the parameters user wrote and then validating them
    func settingParameters(call: FlutterMethodCall, result: FlutterResult){
        os_log("Setting ad parameters", log: customLog, type: .info)
        let argument = call.arguments as! Dictionary<String, Any>
        let adType = argument["adType"] as? String ?? ""
        let adUnitId = argument["adUnitId"] as? String ?? ""
        let configId = argument["configId"] as? String ?? ""
        let width = argument["width"] as? Int ?? 0
        let height = argument["height"] as? Int ?? 0
        let refreshInterval = argument["refreshInterval"] as? Int ?? 0

        ///These two conditional statements are used to check if the ad type is not empy and correctly written
        if(adType == ""){
            os_log("Ad type is empty", log: customLog, type: .error)
        }
        else if (adType.lowercased() != "banner" && adType.lowercased() != "interstitial"){
            os_log("Ad type not recognized, did you mean banner or interstitial?", log: customLog, type: .error)
        }
        else{
            ///This switch case is used to check ad unit ID and config ID are not empty.
            ///If at least one of them is, an error is displayed in console.
            switch (adUnitId, configId){
            case ("", let config) where !config.isEmpty: /// Ad unit ID is empty
                os_log("Ad unit ID is empty", log: customLog, type: .error)

            case (let adUnit, "") where !adUnit.isEmpty: /// Config ID is empty
                os_log("Config ID is empty", log: customLog, type: .error)

            case ("", ""): /// Ad unit ID and config ID are empty
                os_log("Ad unit ID and config ID are empty", log: customLog, type: .error)

            case (_, _) where refreshInterval < 30 && adType.lowercased() != "interstitial": /// Refresh interval is less than 30 seconds and the ad type is not banner
                os_log("Refresh interval should be at least 30 seconds", log: customLog, type: .error)
                
            case (_, _) where refreshInterval > 120 && adType.lowercased() != "interstitial": /// Refresh interval is less than 30 seconds and the ad type is not banner
                os_log("Refresh interval should be no more than 120 seconds", log: customLog, type: .error)

            default: ///If there is no problem, either createBanner or createInterstitial is called
                os_log("Parameters set successfully!", log: customLog, type: .info)
                if (adType == "banner"){
                    createBanner(adUnitId, configId, width, height, refreshInterval)
                }
                else {
                    createInterstitial(adUnitId, configId, width, height)
                    ///Banner layout, which was created at the beggining of this class in the init method, and which is sized as a 1x1, is being hidden from the view
                    DispatchQueue.main.async {
                        self.bannerLayout.isHidden = true
                    }
                }
            }
        }
    }

    ///Setting banner parameters and fetching demand
    func createBanner(_ AD_UNIT_ID: String, _ CONFIG_ID: String, _ width: Int, _ height: Int, _ refreshInterval: Int){
        bannerAdUnit = BannerAdUnit(configId: CONFIG_ID, size: CGSize(width: width, height: height))
        bannerAdUnit.setAutoRefreshMillis(time: Double(refreshInterval*1000))

        let parameters = BannerParameters()
        parameters.api = [Signals.Api.MRAID_3]
        bannerAdUnit.bannerParameters = parameters

        ///DispatchQueue is used to avoid problems when changing banner layout (by adding a gamBanner to it) due to the banner ayout being in main thread
        DispatchQueue.main.async { [self] in
            gamBanner = GAMBannerView(adSize: GADAdSizeFromCGSize(CGSize(width: width, height: height)))
            gamBanner.adUnitID=AD_UNIT_ID
            gamBanner.rootViewController = UIApplication.shared.delegate!.window!!.rootViewController!
            gamBanner.delegate = self
            addBannerViewToView(gamBanner)
            let request = GAMRequest()
            bannerAdUnit.fetchDemand(adObject: request){ [weak self] resultCode in
                os_log("Prebid demand fetch for GAM result: %@",
                       log: self!.customLog,
                       type: .info,
                       resultCode.name())
                self!.gamBanner.load(request)
            }
        }
    }

    ///Setting interstitial ad parameters and fetching demand
    func createInterstitial(_ AD_UNIT_ID: String, _ CONFIG_ID: String, _ width: Int, _ height: Int){
        if(width != 0 && height != 0){
            interstitialAdUnit = InterstitialAdUnit(configId: CONFIG_ID, minWidthPerc: width, minHeightPerc: height)
        }
        else{
            interstitialAdUnit = InterstitialAdUnit(configId: CONFIG_ID)
        }
            
        let gamRequest = GAMRequest()
        interstitialAdUnit.fetchDemand(adObject: gamRequest) { [weak self] resultCode in
            os_log("Prebid demand fetch for GAM result: %@",
                   log: self!.customLog,
                   type: .info,
                   resultCode.name())

            GAMInterstitialAd.load(withAdManagerAdUnitID: AD_UNIT_ID, request: gamRequest) { ad, error in
                guard let self = self else { return }

                if let error = error {
                    os_log("%{error}: Failed to load interstitial ad with error: %@",
                           log: self.customLog,
                           type: .error,
                           error.localizedDescription)
                } else if let ad = ad {
                    ad.fullScreenContentDelegate = self
                    guard let rootViewController = UIApplication.shared.delegate?.window??.rootViewController else {
                        os_log("Error: Could not find root view controller to present the ad", log: self.customLog, type: .error)
                        return
                    }
                    ad.present(fromRootViewController: rootViewController)
                }
            }
        }
    }

    ///Resizing banner
    func bannerViewDidReceiveAd(_ bannerView: GADBannerView) {
        AdViewUtils.findPrebidCreativeSize(bannerView, success: { size in
            guard let bannerView = bannerView as? GAMBannerView else { return }
            bannerView.resize(GADAdSizeFromCGSize(size))
            os_log("Success in finding Prebid creative size", log: self.customLog, type: .info)
        }, failure: { (error) in
            os_log("Failure in finding Prebid creative size: %{error} ",
                   log: self.customLog,
                   type: .error,
                   error.localizedDescription)
        })
    }

    ///Adding banner to the banner layout
    func addBannerViewToView(_ bannerView: GAMBannerView) {
        bannerLayout.translatesAutoresizingMaskIntoConstraints = false
        bannerLayout.addSubview(bannerView)
        bannerLayout.addConstraints(
            [NSLayoutConstraint(item: bannerView,
                                attribute: .bottom,
                                relatedBy: .equal,
                                toItem: bannerLayout.safeAreaLayoutGuide,
                                attribute: .bottom,
                                multiplier: 1,
                                constant: 0),
             NSLayoutConstraint(item: bannerView,
                                attribute: .centerX,
                                relatedBy: .equal,
                                toItem: bannerLayout,
                                attribute: .centerX,
                                multiplier: 1,
                                constant: 0)
            ])
    }

    ///A function for resuming auction
    func onResume(){
        os_log("Resuming Prebid auction", log: customLog, type: .info)
        bannerAdUnit?.resumeAutoRefresh()
    }

    ///A function for stopping auction
    func onPause(){
        os_log("Pausing Prebid auction", log: customLog, type: .info)
        bannerAdUnit?.stopAutoRefresh()
    }

    ///A function for stopping auction and removing reference to the bannerAdUnit, as well as hiding banner layout from the view
    func onDestroy() {
        bannerAdUnit?.stopAutoRefresh()
        os_log("Destroying Prebid auction", log: customLog, type: .info)
        bannerAdUnit = nil
    }
}
