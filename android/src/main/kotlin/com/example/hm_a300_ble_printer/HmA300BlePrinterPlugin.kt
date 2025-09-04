package com.example.hm_a300_ble_printer

import HmA300BlePrinterFlutterApi
import HmA300BlePrinterHostApi
import android.content.Context
import android.util.Log
import android.widget.Toast

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** HmA300BlePrinterPlugin */
class HmA300BlePrinterPlugin : FlutterPlugin, MethodChannel.MethodCallHandler,
    HmA300BlePrinterHostApi {
    private lateinit var channel: MethodChannel
    private val TAG = "HmA300BlePrinterPlugin"
    private var context: Context? = null
    private var fApi: HmA300BlePrinterFlutterApi? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "hm_a300_ble_printer")
        channel.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext
        fApi = HmA300BlePrinterFlutterApi(flutterPluginBinding.binaryMessenger)
        HmA300BlePrinterHostApi.setUp(flutterPluginBinding.binaryMessenger, this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method == "getPlatformVersion") {
            result.success("Android ${android.os.Build.VERSION.RELEASE}")
        } else {
            result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        HmA300BlePrinterHostApi.setUp(binding.binaryMessenger, null)
        fApi = null
        context = null
        channel.setMethodCallHandler(null)
    }

    override fun getHostInfo(callback: (Result<String>) -> Unit) {
        fApi?.getFlutterInfo { result ->
            result.onSuccess { response ->
                Log.d(TAG, "getHostInfo: $response")
                Toast.makeText(context, response, Toast.LENGTH_SHORT).show()
                callback(Result.success("$response-Android ${android.os.Build.VERSION.RELEASE}"))
            }
        }
    }
}
