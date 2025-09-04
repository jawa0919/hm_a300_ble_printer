package com.example.hm_a300_ble_printer

import HmA300BlePrinterFlutterApi
import HmA300BlePrinterHostApi
import android.Manifest
import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import android.widget.Toast
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry


/** HmA300BlePrinterPlugin */
class HmA300BlePrinterPlugin : FlutterPlugin, MethodChannel.MethodCallHandler,
    HmA300BlePrinterHostApi, ActivityAware, PluginRegistry.ActivityResultListener,
    PluginRegistry.RequestPermissionsResultListener {
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
        channel.setMethodCallHandler(null)

        fApi = null
        context = null
    }

    override fun getHostInfo(callback: (Result<String>) -> Unit) {
        fApi?.getFlutterInfo { result ->
            result.onFailure {
                Log.d(TAG, "getFlutterInfo: $it")
                Toast.makeText(context, it.toString(), Toast.LENGTH_SHORT).show()
            }
            result.onSuccess { response ->
                Log.d(TAG, "getFlutterInfo: $response")
                Toast.makeText(context, response, Toast.LENGTH_SHORT).show()
                callback(Result.success("$response-Android ${Build.VERSION.RELEASE}"))
            }
        }
    }

    private var activityBinding: ActivityPluginBinding? = null
    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
        activityBinding?.addActivityResultListener(this)
        activityBinding?.addRequestPermissionsResultListener(this)
        setup()

    }

    override fun onDetachedFromActivityForConfigChanges() {
        onDetachedFromActivity()
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivity() {
        tearDown()
        activityBinding?.removeRequestPermissionsResultListener(this)
        activityBinding?.removeActivityResultListener(this)
        activityBinding = null
    }

    private fun setup() {
        bleAdapter = BluetoothAdapter.getDefaultAdapter()

        val findFilter = IntentFilter();
        findFilter.addAction(BluetoothDevice.ACTION_FOUND)
        findFilter.addAction(BluetoothAdapter.ACTION_DISCOVERY_FINISHED)
        context?.registerReceiver(findReceiver, findFilter)
    }

    private fun tearDown() {
        context?.unregisterReceiver(findReceiver)
        bleAdapter = null
    }

    private var bleAdapter: BluetoothAdapter? = null
    private val findReceiver: BroadcastReceiver = object : BroadcastReceiver() {
        @SuppressLint("MissingPermission")
        override fun onReceive(context: Context, intent: Intent) {
            if (BluetoothDevice.ACTION_FOUND != intent.action) return
            val d = intent.getParcelableExtra<BluetoothDevice>(BluetoothDevice.EXTRA_DEVICE)
            if (d == null || d.name == null) return
            if (d.address == null) return
            // FIXME: printer is classic bluetooth, not le bluetooth
            if (d.type == BluetoothDevice.DEVICE_TYPE_LE) return
            val rssi = intent.extras?.getShort(BluetoothDevice.EXTRA_RSSI)?.toInt()
            val m = mapOf<Any, Any?>(
                "name" to d.name,
                "address" to d.address,
                "rssi" to rssi,
                "type" to d.type,
            )
            fApi?.onScanResult(m) {}
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int, permissions: Array<out String>, grantResults: IntArray
    ): Boolean {
        if (requestCode != pRequestCodeCode) return false;
        if (grantResults.isEmpty()) return false;
        grantResults.map {
            if (it != PackageManager.PERMISSION_GRANTED) {
                pCallback?.let { it(Result.success(false)) }
                return true
            }
        }
        pCallback?.let { it(Result.success(true)) }
        return true
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        return false
    }

    override fun bleEnabled(callback: (Result<Boolean>) -> Unit) {
        bleAdapter?.let {
            callback(Result.success(it.isEnabled))
        } ?: {
            callback(Result.failure(Throwable("BluetoothAdapter is null")))
        }
    }

    private var pCallback: ((Result<Boolean>) -> Unit)? = null
    private fun neededPermission(): ArrayList<String> {
        val permissions = ArrayList<String>()
        if (Build.VERSION.SDK_INT <= 30) { // Android 11 (September 2020)
            permissions.add(Manifest.permission.BLUETOOTH);
            permissions.add(Manifest.permission.ACCESS_FINE_LOCATION);
        }
        if (Build.VERSION.SDK_INT >= 31) { // Android 12 (October 2021)
            permissions.add(Manifest.permission.BLUETOOTH_SCAN);
            permissions.add(Manifest.permission.BLUETOOTH_CONNECT);
        }
        val permissionsNeeded = arrayListOf<String>()
        for (p in permissions) {
            if (context?.checkSelfPermission(p) != PackageManager.PERMISSION_GRANTED) {
                permissionsNeeded.add(p)
            }
        }
        return permissionsNeeded
    }

    private val pRequestCodeCode = 30919;
    override fun blePermission(callback: (Result<Boolean>) -> Unit) {
        val pList = neededPermission()
        if (pList.isEmpty()) {
            callback(Result.success(true))
            return
        }
        activityBinding?.activity?.let {
            pCallback = callback
            it.requestPermissions(pList.toTypedArray(), pRequestCodeCode)
        }
    }


    @SuppressLint("MissingPermission")
    override fun startScan(callback: (Result<Boolean>) -> Unit) {
        Log.d(TAG, "startScan: ")
        bleAdapter?.let { ad ->
            callback(Result.success(ad.startDiscovery()))
        } ?: {
            callback(Result.failure(Throwable("BluetoothAdapter is null")))
        }
    }

    @SuppressLint("MissingPermission")
    override fun stopScan(callback: (Result<Boolean>) -> Unit) {
        Log.d(TAG, "stopScan: ")
        bleAdapter?.let { ad ->
            callback(Result.success(ad.cancelDiscovery()))
        } ?: {
            callback(Result.failure(Throwable("BluetoothAdapter is null")))
        }
    }
}
