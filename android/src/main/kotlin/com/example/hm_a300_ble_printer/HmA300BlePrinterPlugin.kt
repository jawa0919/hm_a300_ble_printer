package com.example.hm_a300_ble_printer

import FlutterError
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
import android.os.Handler
import android.os.Looper
import android.util.Log
import cpcl.PrinterHelper
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
                Log.d(TAG, "getFlutterInfo.onFailure: $it")
                callback(Result.failure(FlutterError("getFlutterInfo.onFailure: $it")))
            }
            result.onSuccess { response ->
                Log.d(TAG, "getFlutterInfo: $response")
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

        val findFilter = IntentFilter()
        findFilter.addAction(BluetoothAdapter.ACTION_STATE_CHANGED)
        findFilter.addAction(BluetoothDevice.ACTION_FOUND)
        findFilter.addAction(BluetoothAdapter.ACTION_DISCOVERY_FINISHED)
        context?.registerReceiver(bleReceiver, findFilter)
    }

    private fun tearDown() {
        context?.unregisterReceiver(bleReceiver)
        bleAdapter = null
    }

    private var bleAdapter: BluetoothAdapter? = null
    private val bleReceiver: BroadcastReceiver = object : BroadcastReceiver() {
        @SuppressLint("MissingPermission")
        override fun onReceive(context: Context, intent: Intent) {
            when (intent.action) {
                BluetoothAdapter.ACTION_STATE_CHANGED -> {
                    //状态变化
                    val s = intent.getIntExtra(BluetoothAdapter.EXTRA_STATE, 0)
                    val m = mutableMapOf<Any, Any?>("state" to 0)
                    if (s == BluetoothAdapter.STATE_ON) m["state"] = 5
                    else if (s == BluetoothAdapter.STATE_OFF) m["state"] = 4
                    else if (s == BluetoothAdapter.STATE_TURNING_OFF) m["state"] = 1
                    else if (s == BluetoothAdapter.STATE_TURNING_ON) m["state"] = 1
                    fApi?.onBleStateChanged(m) {}
                    fApi?.onDiscoveryFinished(mapOf()) {}
                }

                BluetoothDevice.ACTION_FOUND -> {
                    //扫描-发现设备
                    val d = intent.getParcelableExtra<BluetoothDevice>(BluetoothDevice.EXTRA_DEVICE)
                    if (d == null || d.name == null || d.address == null) return
                    // FIXME: printer is classic bluetooth, not le bluetooth-打印机不是低功耗蓝牙
                    if (d.type == BluetoothDevice.DEVICE_TYPE_LE) return
                    if (ptPrinters.containsKey(d.address)) return
                    val rssi = intent.extras?.getShort(BluetoothDevice.EXTRA_RSSI)?.toInt()
                    val m = mapOf<Any, Any?>(
                        "name" to d.name,
                        "address" to d.address,
                        "rssi" to rssi,
                    )
                    ptPrinters[d.address] = m
                    fApi?.onFound(m) {}
                }

                BluetoothAdapter.ACTION_DISCOVERY_FINISHED -> {
                    //扫描结束
                    Log.d(TAG, "onReceive.ACTION_DISCOVERY_FINISHED: ")
                    val m = mapOf<Any, Any?>()
                    fApi?.onDiscoveryFinished(m) {}
                }

                else -> {}
            }
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int, permissions: Array<out String>, grantResults: IntArray
    ): Boolean {
        if (requestCode != pRequestCodeCode) return false
        if (grantResults.isEmpty()) return false
        grantResults.map {
            if (it != PackageManager.PERMISSION_GRANTED) {
                fApi?.onBleStateChanged(mapOf<Any, Any?>("state" to 3)) {}
                return true
            }
        }
        bleAdapter?.let {
            fApi?.onBleStateChanged(mapOf<Any, Any?>("state" to if (it.isEnabled) 5 else 4)) {}
        } ?: {
            fApi?.onBleStateChanged(mapOf<Any, Any?>("state" to 0)) {}
        }
        return true
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        return false
    }

    private fun neededPermission(): ArrayList<String> {
        val permissions = ArrayList<String>()
        if (Build.VERSION.SDK_INT <= 30) { // Android 11 (September 2020)
            permissions.add(Manifest.permission.BLUETOOTH)
            permissions.add(Manifest.permission.ACCESS_FINE_LOCATION)
        }
        if (Build.VERSION.SDK_INT >= 31) { // Android 12 (October 2021)
            permissions.add(Manifest.permission.BLUETOOTH_SCAN)
            permissions.add(Manifest.permission.BLUETOOTH_CONNECT)
        }
        val permissionsNeeded = arrayListOf<String>()
        for (p in permissions) {
            if (context?.checkSelfPermission(p) != PackageManager.PERMISSION_GRANTED) {
                permissionsNeeded.add(p)
            }
        }
        return permissionsNeeded
    }

    private val pRequestCodeCode = 30919
    override fun checkBleState(callback: (Result<Unit>) -> Unit) {
        bleAdapter?.let {
            val pList = neededPermission()
            if (pList.isEmpty()) {
                fApi?.onBleStateChanged(mapOf<Any, Any?>("state" to if (it.isEnabled) 5 else 4)) {}
                return
            }
            fApi?.onBleStateChanged(mapOf<Any, Any?>("state" to 3)) {}
            activityBinding?.activity?.requestPermissions(pList.toTypedArray(), pRequestCodeCode)
        } ?: {
            fApi?.onBleStateChanged(mapOf<Any, Any?>("state" to 0)) {}
        }
    }

    private var ptPrinters: MutableMap<String, Map<Any, Any?>> = mutableMapOf()

    @SuppressLint("MissingPermission")
    override fun startScan(callback: (Result<Boolean>) -> Unit) {
        Log.d(TAG, "startScan: ")
        bleAdapter?.let { ad ->
            ptPrinters.clear()
            Handler(Looper.getMainLooper()).postDelayed({
                ad.cancelDiscovery()
                fApi?.onDiscoveryFinished(mapOf()) {}
            }, 15000)
            val s = ad.startDiscovery()
            callback(Result.success(s))
        } ?: {
            callback(Result.failure(FlutterError("BluetoothAdapter is null")))
        }
    }

    @SuppressLint("MissingPermission")
    override fun stopScan(callback: (Result<Boolean>) -> Unit) {
        Log.d(TAG, "stopScan: ")
        bleAdapter?.let { ad ->
            val s = ad.cancelDiscovery()
            callback(Result.success(s))
        } ?: {
            callback(Result.failure(FlutterError("BluetoothAdapter is null")))
        }
    }

    var printerConnected: String = ""
    override fun connect(address: String, callback: (Result<Long>) -> Unit) {
        Log.d(TAG, "connect: $address---$printerConnected")
        if (address.isEmpty()) {
            callback(Result.failure(FlutterError("address is empty")))
            return
        }
        if (printerConnected == address) {
            callback(Result.success(200))
            return
        }
        // ptPrinters[address] 不需要校验附近，不在附近就连接超时
        context?.let { ct ->
            val s = PrinterHelper.portOpenBT(ct, address)
            if (s == 0) {
                printerConnected = address
                callback(Result.success(200))
            } else {
                callback(Result.success(s.toLong()))
            }
        } ?: {
            callback(Result.failure(FlutterError("context is null")))
        }
    }

    override fun disconnect(address: String, callback: (Result<Boolean>) -> Unit) {
        Log.d(TAG, "disconnect: $address---$printerConnected")
        if (printerConnected == address) {
            val s = PrinterHelper.portClose()
            if (s) printerConnected = ""
            callback(Result.success(s))
            return
        }
        callback(Result.success(false))
    }

    override fun sendCommand(address: String, cmd: String, callback: (Result<Boolean>) -> Unit) {
        Log.d(TAG, "sendCommand: $address---$printerConnected")
        if ("" == address) {
            callback(Result.failure(FlutterError("address is empty")))
            return
        }
        if (printerConnected != address) {
            callback(Result.failure(FlutterError("address is disconnect")))
            return
        }
        try {
            // ptPrinters[address] 不需要校验附近，内部有绑定address
            PrinterHelper.Encoding("gb2312")
            val cList = cmd.split("\t\n")
            for (c in cList) {
                PrinterHelper.WriteData("$c\t\n".toByteArray(charset(PrinterHelper.LanguageEncode)))
            }
            callback(Result.success(true))
            // 回调测试
//            Handler(Looper.getMainLooper()).postDelayed({
//                callback(Result.success(true))
//            }, 3000)
        } catch (ex: Exception) {
            Log.e(TAG, "sendCommand: ", ex)
            callback(Result.success(false))
        }
    }
}
