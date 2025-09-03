package com.example.hm_a300_ble_printer

import HmA300BlePrinterFlutterApi
import HmA300BlePrinterHostApi
import android.content.Context
import android.util.Log
import android.widget.Toast

import io.flutter.embedding.engine.plugins.FlutterPlugin

/** HmA300BlePrinterPlugin */
class HmA300BlePrinterPlugin : FlutterPlugin, HmA300BlePrinterHostApi {
    private val TAG = "HmA300BlePrinterPlugin"
    private var context: Context? = null
    private var fApi: HmA300BlePrinterFlutterApi? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        fApi = HmA300BlePrinterFlutterApi(flutterPluginBinding.binaryMessenger)
        HmA300BlePrinterHostApi.setUp(flutterPluginBinding.binaryMessenger, this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        HmA300BlePrinterHostApi.setUp(binding.binaryMessenger, null)
        fApi = null
        context = null
    }

    override fun getPlatformVersion(): String {
        return "Android ${android.os.Build.VERSION.RELEASE}"
    }

    override fun getAllVersions(callback: (kotlin.Result<String>) -> Unit) {
        fApi?.getDartVersion { result ->
            result.onSuccess { response ->
                Log.d(TAG, "getAllVersions: $response")
                Toast.makeText(context, response, Toast.LENGTH_SHORT).show()
                callback(kotlin.Result.success("$response-${getPlatformVersion()}"))
            }
        }
    }
}
