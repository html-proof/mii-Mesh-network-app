package app.miimesh.mii_mesh

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import android.Manifest
import android.os.Build
import android.content.pm.PackageManager

class MainActivity : FlutterActivity() {
    private var ble: BlePeripheral? = null
    private var mesh: MeshRadio? = null
    private var permissionResult: MethodChannel.Result? = null
    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        ble = BlePeripheral(this)
        mesh = MeshRadio(this)
        EventChannel(engine.dartExecutor.binaryMessenger, "mii/mesh/events").setStreamHandler(mesh)
        MethodChannel(engine.dartExecutor.binaryMessenger, "mii/mesh").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "permissions" -> {
                        val permissions = if (Build.VERSION.SDK_INT >= 31) arrayOf(Manifest.permission.BLUETOOTH_SCAN, Manifest.permission.BLUETOOTH_CONNECT, Manifest.permission.BLUETOOTH_ADVERTISE) else arrayOf(Manifest.permission.ACCESS_FINE_LOCATION)
                        val missing = permissions.filter { checkSelfPermission(it) != PackageManager.PERMISSION_GRANTED }
                        if (missing.isEmpty()) result.success(true)
                        else if (permissionResult != null) result.error("busy", "Permission request already active", null)
                        else { permissionResult = result; requestPermissions(missing.toTypedArray(), 422) }
                    }
                    "start" -> {
                        startForegroundService(android.content.Intent(this, MeshForegroundService::class.java))
                        mesh?.start(); result.success(null)
                    }
                    "stop" -> { mesh?.stop(); stopService(android.content.Intent(this, MeshForegroundService::class.java)); result.success(null) }
                    "enable" -> { startActivity(android.content.Intent(android.bluetooth.BluetoothAdapter.ACTION_REQUEST_ENABLE)); result.success(null) }
                    "send" -> { mesh?.send(call.argument<String>("link")!!, call.argument<ByteArray>("bytes")!!, result) }
                    else -> result.notImplemented()
                }
            } catch (_: Exception) { result.error("bluetooth", "Bluetooth unavailable. Check Nearby devices access.", null) }
        }
        EventChannel(engine.dartExecutor.binaryMessenger, "mii/ble/events").setStreamHandler(ble)
        MethodChannel(engine.dartExecutor.binaryMessenger, "mii/ble").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "permissions" -> {
                        val permissions = if (Build.VERSION.SDK_INT >= 31) arrayOf(Manifest.permission.BLUETOOTH_CONNECT, Manifest.permission.BLUETOOTH_ADVERTISE) else emptyArray()
                        val missing = permissions.filter { checkSelfPermission(it) != PackageManager.PERMISSION_GRANTED }
                        if (missing.isEmpty()) result.success(true)
                        else if (permissionResult != null) result.error("busy", "Permission request already active", null)
                        else { permissionResult = result; requestPermissions(missing.toTypedArray(), 421) }
                    }
                    "start" -> { ble?.start(); result.success(null) }
                    "stop" -> { ble?.stop(); result.success(null) }
                    "send" -> { ble?.send(call.arguments as ByteArray); result.success(null) }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) { result.error("bluetooth", e.message ?: "Bluetooth unavailable", null) }
        }
    }
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 421 || requestCode == 422) { permissionResult?.success(grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED }); permissionResult = null }
    }
    override fun onStop() { ble?.stop(); super.onStop() }
    override fun onDestroy() { ble?.stop(); mesh?.stop(); stopService(android.content.Intent(this, MeshForegroundService::class.java)); permissionResult?.success(false); permissionResult = null; super.onDestroy() }
}
