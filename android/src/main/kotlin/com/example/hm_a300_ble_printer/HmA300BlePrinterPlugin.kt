package com.example.hm_a300_ble_printer

import HmA300BlePrinterFlutterApi
import HmA300BlePrinterHostApi
import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
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
class HmA300BlePrinterPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware,
    PluginRegistry.RequestPermissionsResultListener, PluginRegistry.ActivityResultListener,
    HmA300BlePrinterHostApi {
    private lateinit var channel: MethodChannel
    private val TAG = "HmA300BlePrinterPlugin"
    private var context: Context? = null
    private var activityBinding: ActivityPluginBinding? = null


    private var fApi: HmA300BlePrinterFlutterApi? = null
    private var bleAdapter: BluetoothAdapter? = null

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


    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
        activityBinding?.addRequestPermissionsResultListener(this)
        activityBinding?.addActivityResultListener(this)
        bleAdapter = BluetoothAdapter.getDefaultAdapter()

        iniBroadcast(true)
    }


    override fun onDetachedFromActivityForConfigChanges() {
        onDetachedFromActivity()
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivity() {
        iniBroadcast(false)

        bleAdapter = null
        activityBinding?.removeRequestPermissionsResultListener(this)
        activityBinding?.removeActivityResultListener(this)
        activityBinding = null
    }

    private fun iniBroadcast(b: Boolean) {
        if (b) {
            val stateFilter = IntentFilter(BluetoothAdapter.ACTION_STATE_CHANGED)
            context?.registerReceiver(stateReceiver, stateFilter)

            val findFilter = IntentFilter();
            findFilter.addAction(BluetoothDevice.ACTION_FOUND)
            findFilter.addAction(BluetoothAdapter.ACTION_DISCOVERY_FINISHED)
            context?.registerReceiver(findReceiver, findFilter)
        } else {
            context?.unregisterReceiver(stateReceiver)
            context?.unregisterReceiver(findReceiver)
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int, permissions: Array<out String>, grantResults: IntArray
    ): Boolean {
        if (requestCode == 30919 && grantResults.isNotEmpty()) {
            grantResults.map {
                if (it != PackageManager.PERMISSION_GRANTED) {
                    pCallback?.let { it(Result.success(false)) }
                    return true
                }
            }
            pCallback?.let { it(Result.success(true)) }
            return true
        } else {
            return false
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        return false
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

    override fun bluetoothEnabled(callback: (Result<Boolean>) -> Unit) {
        bleAdapter?.let {
            callback(Result.success(it.isEnabled))
        } ?: {
            callback(Result.failure(Throwable("BluetoothAdapter is null")))
        }
    }

    private var pCallback: ((Result<Boolean>) -> Unit)? = null
    private fun selfPermission(): ArrayList<String> {
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
            if (context!!.checkSelfPermission(p) != PackageManager.PERMISSION_GRANTED) {
                permissionsNeeded.add(p)
            }
        }
        return permissionsNeeded
    }

    override fun checkPermission(callback: (Result<Boolean>) -> Unit) {
        val permissionsNeeded = selfPermission()
        if (permissionsNeeded.isEmpty()) {
            callback(Result.success(true))
            return
        }
        activityBinding?.activity?.let {
            pCallback = callback
            it.requestPermissions(permissionsNeeded.toTypedArray(), 30919)
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

    private val stateReceiver: BroadcastReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (BluetoothAdapter.ACTION_STATE_CHANGED != intent.action) return
            val s = intent.getIntExtra(BluetoothAdapter.EXTRA_STATE, BluetoothAdapter.ERROR)
            Log.d(TAG, "BluetoothAdapter.stateReceiver-$s")
        }
    }

    private val findReceiver: BroadcastReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (BluetoothDevice.ACTION_FOUND != intent.action) return
            val d = intent.getParcelableExtra<BluetoothDevice>(BluetoothDevice.EXTRA_DEVICE)
            checkPermission { }
            if (d == null || d.name == null) return
            if (d.address == null) return
            // FIXME: printer is not le bluetooth
            if (d.type == BluetoothDevice.DEVICE_TYPE_LE) return
            val rssi = intent.extras?.getShort(BluetoothDevice.EXTRA_RSSI)?.toInt()
            val m = mapOf<Any, Any?>("name" to d.name, "address" to d.address, "rssi" to rssi)
            fApi?.scanResult(m) {}
        }
    }
}
