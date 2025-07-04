package setupad.plugin.setupad_prebid_flutter

import android.app.Activity
import android.content.Context
import android.util.Log
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import com.google.android.gms.ads.AdListener
import com.google.android.gms.ads.AdSize
import com.google.android.gms.ads.LoadAdError
import com.google.android.gms.ads.admanager.AdManagerAdRequest
import com.google.android.gms.ads.admanager.AdManagerAdView
import com.google.android.gms.ads.admanager.AdManagerInterstitialAd
import com.google.android.gms.ads.admanager.AdManagerInterstitialAdLoadCallback
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.platform.PlatformView
import org.prebid.mobile.BannerAdUnit
import org.prebid.mobile.BannerParameters
import org.prebid.mobile.InterstitialAdUnit
import org.prebid.mobile.Signals
import org.prebid.mobile.addendum.AdViewUtils
import org.prebid.mobile.addendum.PbFindSizeError

/**
 * A class that is responsible for creating and adding banner and interstitial ads to the Flutter app's view, as well as pausing and resuming auction
 */
class PrebidView internal constructor(
    context: Context,
    messenger: BinaryMessenger,
    id: Int,
    activity: Activity
) :
    PlatformView, MethodCallHandler {
    private var applicationContext: Context = context
    private var appActivity: Activity = activity
    private val channel = MethodChannel(messenger, "setupad.plugin.setupad_prebid_flutter/myChannel_$id")
    private var bannerLayout: ViewGroup?

    private var bannerAdUnit: BannerAdUnit? = null
    private var interstitialAdUnit: InterstitialAdUnit? = null

    private val Tag = "PrebidPluginLog"

    /**
     * Setting channel method, configuring banner layout
     */
    init {
        try {
            channel.setMethodCallHandler(this)
        } catch (e: Exception) {
            Log.e(Tag, "Error setting method call handler: $e")
        }
        bannerLayout = FrameLayout(applicationContext)
        val params = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.WRAP_CONTENT,
            FrameLayout.LayoutParams.WRAP_CONTENT
        )
        params.gravity = Gravity.BOTTOM
    }

    /**
     * Adding a view to the UI where banner will be added
     */
    override fun getView(): View? {
        return bannerLayout
    }

    /**
     * Disposing view and destroying Prebid auction
     */
    override fun dispose() {
        bannerLayout = null
        channel.setMethodCallHandler(null)
        onDestroy()
    }

    /**
     * Checking which method was called and then calling the needed method
     */
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "setParams" -> settingParameters(call)
            "pauseAuction" -> onPause()
            "resumeAuction" -> onResume()
            "destroyAuction" -> onDestroy()
            else -> result.notImplemented()
        }
    }

    /**
     * Getting the parameters user wrote and then validating them
     */
    private fun settingParameters(call: MethodCall) {
        Log.d(Tag, "Setting ad parameters")
        val arguments = call.arguments as? Map<*, *>
        val adType = arguments?.get("adType") as? String ?: ""
        val adUnitId = arguments?.get("adUnitId") as? String ?: ""
        val configId = arguments?.get("configId") as? String ?: ""
        val width = arguments?.get("width") as? Int ?: 0
        val height = arguments?.get("height") as? Int ?: 0
        val refreshInterval = arguments?.get("refreshInterval") as? Int ?: 0

        bannerLayout?.removeAllViews()

        when {
            adType == "" -> {
                Log.e(Tag, applicationContext.getString(R.string.emptyAdType))
            }

            adType.lowercase() != "banner" && adType.lowercase() != "interstitial" -> {
                Log.e(Tag, applicationContext.getString(R.string.errorsInAdTypeName))
            }

            else -> {
                when {
                    adUnitId == "" && configId != "" -> { //adUnitID tuscias
                        Log.e(Tag, applicationContext.getString(R.string.emptyAdUnitID))
                    }

                    adUnitId != "" && configId == "" -> { //configID tuscias
                        Log.e(Tag, applicationContext.getString(R.string.emptyConfigID))
                    }

                    adUnitId == "" && configId == "" -> { //ad unit ir config ID tusti
                        Log.e(Tag, applicationContext.getString(R.string.emptyAdUnitConfigID))
                    }

                    refreshInterval < 30 && adType.lowercase()!="interstitial" -> {
                    Log.e(Tag, applicationContext.getString(R.string.tooSmallRefreshInterval))
                    }

                    refreshInterval > 120 && adType.lowercase()!="interstitial" -> {
                        Log.e(Tag, applicationContext.getString(R.string.tooBigRefreshInterval))
                    }

                    else -> {
                        Log.d(Tag, "Parameters set successfully!")
                        if (adType.lowercase() == "banner"){
                            createBanner(adUnitId, configId, width, height, refreshInterval)
                        }

                        else {
                            createInterstitial(adUnitId, configId, width, height)
                            bannerLayout?.visibility = View.GONE
                        }
                    }
                }
            }
        }
    }

    /**
     * Setting banner parameters and fetching demand
     */
    private fun createBanner(
        AD_UNIT_ID: String,
        CONFIG_ID: String,
        width: Int,
        height: Int,
        refreshInterval: Int
    ) {
        bannerAdUnit = BannerAdUnit(CONFIG_ID, width, height)
        bannerAdUnit?.setAutoRefreshInterval(refreshInterval)

        val bannerParameters = BannerParameters()
        bannerParameters.api = listOf(Signals.Api.MRAID_3, Signals.Api.OMID_1)
        bannerAdUnit!!.bannerParameters = bannerParameters

        val bannerAdView = AdManagerAdView(applicationContext)
        bannerAdView.adUnitId = AD_UNIT_ID
        bannerAdView.setAdSizes(AdSize(width, height))
        bannerAdView.adListener = bannerListener(bannerAdView)

        bannerLayout?.addView(bannerAdView)

        val request = AdManagerAdRequest.Builder().build()
        bannerAdUnit?.fetchDemand(request) { result ->
            Log.d(Tag, "Prebid demand fetch for GAM result: $result")
            bannerAdView.loadAd(request)
        }
    }

    /**
     * Setting interstitial ad parameters and fetching demand
     */
    private fun createInterstitial(AD_UNIT_ID: String, CONFIG_ID: String, width: Int, height: Int) {
        if (width!=0 && height!=0){
            interstitialAdUnit = InterstitialAdUnit(
                CONFIG_ID,
                width,
                height
            )
        }
        else{
            interstitialAdUnit = InterstitialAdUnit(CONFIG_ID)
        }


        val request = AdManagerAdRequest.Builder().build()
        interstitialAdUnit?.fetchDemand(request) { result ->
            Log.d(Tag, "Prebid demand fetch for GAM result: $result")
            AdManagerInterstitialAd.load(
                applicationContext,
                AD_UNIT_ID,
                request,
                interstitialListener()
            )
        }
    }

    /**
     * Banner listener which, if ad is loaded, resizes that banner
     * findPrebidCreativeSize() method is a fix for GAM bug, where the ad is sized incorrectly
     */
    private fun bannerListener(bannerAdView: AdManagerAdView): AdListener {
        return object : AdListener() {
            override fun onAdLoaded() {
                super.onAdLoaded()
                AdViewUtils.findPrebidCreativeSize(
                    bannerAdView,
                    object : AdViewUtils.PbFindSizeListener {
                        override fun success(width: Int, height: Int) {
                            Log.d(
                                Tag,
                                "Success in finding Prebid creative size"
                            )
                            bannerAdView.setAdSizes(AdSize(width, height))
                        }

                        override fun failure(error: PbFindSizeError) {
                            Log.e(Tag, "Failure in finding Prebid creative size: $error")
                        }
                    })
            }

            override fun onAdFailedToLoad(error: LoadAdError) {
                super.onAdFailedToLoad(error)
                Log.e(Tag, "Failure in loading banner ad: $error")
            }
        }
    }

    /**
     * Interstitial ad listener that, if ad is loaded, shows that ad
     */
    private fun interstitialListener(): AdManagerInterstitialAdLoadCallback {
        return object : AdManagerInterstitialAdLoadCallback() {
            override fun onAdLoaded(adManagerInterstitialAd: AdManagerInterstitialAd) {
                super.onAdLoaded(adManagerInterstitialAd)
                adManagerInterstitialAd.show(appActivity)
            }

            override fun onAdFailedToLoad(loadAdError: LoadAdError) {
                super.onAdFailedToLoad(loadAdError)
                Log.e(Tag, "Ad failed to load: $loadAdError")
            }
        }
    }

    /**
     * A method for stopping auction and removing reference to the bannerAdUnit, as well as hiding
     * banner from the layout
     */
    private fun onDestroy() {
        if (bannerAdUnit != null) {
            bannerAdUnit!!.stopAutoRefresh()
            Log.d(Tag, "Destroying Prebid auction")
            bannerAdUnit = null
        }
    }

    /**
     * A method for pausing auction
     */
    private fun onPause() {
        if (bannerAdUnit != null) {
            bannerAdUnit!!.stopAutoRefresh()
            Log.d(Tag, "Pausing Prebid auction")
        }
    }

    /**
     * A method for resuming auction
     */
    private fun onResume() {
        if (bannerAdUnit != null) {
            Log.d(Tag, "Resuming Prebid auction")
            bannerAdUnit!!.resumeAutoRefresh()
        }
    }
}