import Flutter
import UIKit
import GoogleMobileAds
import PrebidMobile
import os
import OSLog

///Plugin's main class that is called once and allows to interact with iOS via Dart code
public class SetupadPrebidFlutterPlugin: NSObject, FlutterPlugin {
    private var _methodChannel: FlutterMethodChannel?
    static let customLog = OSLog(subsystem: "setupad.prebid.plugin", category: "PrebidPluginLog")

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "setupad.plugin.setupad_prebid_flutter/myChannel_0", binaryMessenger: registrar.messenger())
        ///Getting Prebid account ID through method channel and initializing Prebid Mobile SDK
        channel.setMethodCallHandler({
            (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
            switch call.method {
            case "startPrebid":
                let argument = call.arguments as! Dictionary<String, Any>
                let accountId = argument["accountID"] as? String ?? ""
                let urlServer = argument["urlServer"] as? String ?? ""
                let timeoutMillis = argument["timeoutMillis"] as? Int ?? 3000
                let pbs = argument["pbsDebug"] as? Bool ?? false
                if (accountId != ""){
                    Prebid.shared.prebidServerAccountId = accountId
                    Prebid.shared.pbsDebug = pbs
                    Prebid.shared.shareGeoLocation = true
                    try! Prebid.initializeSDK(
                                serverURL: urlServer,
                                gadMobileAdsVersion: string(for: MobileAds.shared.versionNumber)
                            ) { status, error in
                                switch status {
                                    case .succeeded:
                                        print("Prebid SDK successfully initialized")
                                    case .failed:
                                        if let error = error {
                                            print("An error occurred during Prebid SDK initialization: \(error.localizedDescription)")
                                        }
                                    case .serverStatusWarning:
                                        if let error = error {
                                            print("Prebid Server status checking failed: \(error.localizedDescription)")
                                        }
                                    default:
                                        break
                                    }
                            }
                    Prebid.shared.timeoutMillis = timeoutMillis
                }

            default:
                result(FlutterMethodNotImplemented)
            }
        })
        registrar.register(PrebidViewFactory(messenger: registrar.messenger()), withId: "setupad.plugin.setupad_prebid_flutter")
    }
}
