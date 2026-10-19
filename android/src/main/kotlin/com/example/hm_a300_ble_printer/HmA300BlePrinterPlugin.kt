package com.example.hm_a300_ble_printer

import HmA300BlePrinterFlutterApi
import HmA300BlePrinterHostApi
import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/** HmA300BlePrinterPlugin */
class HmA300BlePrinterPlugin : FlutterPlugin, MethodCallHandler, ActivityAware,
    HmA300BlePrinterHostApi {
    private val TAG = "HmA300BlePrinterPlugin"
    private lateinit var channel: MethodChannel
    private var context: Context? = null
    private var fApi: HmA300BlePrinterFlutterApi? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "hm_a300_ble_printer")
        channel.setMethodCallHandler(this)

        context = flutterPluginBinding.applicationContext
        fApi = HmA300BlePrinterFlutterApi(flutterPluginBinding.binaryMessenger)
        HmA300BlePrinterHostApi.setUp(flutterPluginBinding.binaryMessenger, this)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        if (call.method == "getPlatformVersion") {
            result.success("Android ${android.os.Build.VERSION.RELEASE}")
        } else {
            result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        fApi = null
        context = null
    }

    override suspend fun getPlatformNameAsync(): String {
        return "Android ${android.os.Build.VERSION.RELEASE}"
    }

    override suspend fun getRunningInfoAsync(): String {
        var st = fApi?.getDartVersionAsync()
        st += "\n"
        st += "Android ${android.os.Build.VERSION.RELEASE}"
        return st
    }


    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        setup(binding)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        onDetachedFromActivity()
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivity() {
        tearDown()
    }

    private var activityBinding: ActivityPluginBinding? = null

    private fun setup(binding: ActivityPluginBinding) {
        activityBinding = binding
    }

    private fun tearDown() {
        activityBinding = null
    }
}
