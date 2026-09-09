package app.miimesh.mii_mesh

import android.bluetooth.*
import android.bluetooth.le.*
import android.content.*
import android.os.*
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.security.SecureRandom
import java.util.UUID

/** Bounded multi-peer central/peripheral transport; private payloads stay in Dart. */
class MeshRadio(private val context: Context) : EventChannel.StreamHandler {
    companion object {
        val SERVICE = UUID.fromString("c0a80101-7d2b-4e18-9bf0-3ae5f1002001")
        val RX = UUID.fromString("c0a80101-7d2b-4e18-9bf0-3ae5f1002002")
        val TX = UUID.fromString("c0a80101-7d2b-4e18-9bf0-3ae5f1002003")
        val CCC = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")
    }
    private val handler = Handler(Looper.getMainLooper())
    private val adapter get() = (context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager).adapter
    private var sink: EventChannel.EventSink? = null
    private var server: BluetoothGattServer? = null
    private var active = false
    private var registered = false
    private var scanning = false
    private val token = ByteArray(4).also { SecureRandom().nextBytes(it) }
    private val links = mutableMapOf<String, Link>()
    private val failures = mutableMapOf<String, Pair<Int, Long>>()
    private val tx = BluetoothGattCharacteristic(TX, BluetoothGattCharacteristic.PROPERTY_NOTIFY, BluetoothGattCharacteristic.PERMISSION_READ).apply {
        addDescriptor(BluetoothGattDescriptor(CCC, BluetoothGattDescriptor.PERMISSION_READ or BluetoothGattDescriptor.PERMISSION_WRITE))
    }
    private class Link(val device: BluetoothDevice, var gatt: BluetoothGatt? = null) {
        var ready = false
        var rx: BluetoothGattCharacteristic? = null
        val incoming = ByteArrayOutputStream()
        var index = 0; var total = 0; var last = 0L; var packets = 0; var window = 0L
        val frames = ArrayDeque<ByteArray>()
        var result: MethodChannel.Result? = null
        var timeout: Runnable? = null
    }
    private fun emit(type: String, value: Any? = null, link: String = "") {
        handler.post { sink?.success(mapOf("type" to type, "value" to value, "link" to link)) }
    }
    override fun onListen(arguments: Any?, events: EventChannel.EventSink) { sink = events }
    override fun onCancel(arguments: Any?) { sink = null; stop() }
    private val stateReceiver = object : BroadcastReceiver() {
        override fun onReceive(c: Context?, intent: Intent?) {
            when (intent?.getIntExtra(BluetoothAdapter.EXTRA_STATE, -1)) {
                BluetoothAdapter.STATE_OFF -> { clearRadio(); emit("status", "Bluetooth is off") }
                BluetoothAdapter.STATE_ON -> if (active) openRadio()
            }
        }
    }
    fun start() {
        if (active) return
        active = true
        if (!registered) {
            val filter = IntentFilter(BluetoothAdapter.ACTION_STATE_CHANGED)
            if (Build.VERSION.SDK_INT >= 33) context.registerReceiver(stateReceiver, filter, Context.RECEIVER_EXPORTED)
            else context.registerReceiver(stateReceiver, filter)
            registered = true
        }
        if (adapter?.isEnabled != true) { emit("status", "Bluetooth is off"); return }
        openRadio()
    }
    private fun openRadio() {
        try {
            if (server != null) return
            check(adapter?.isMultipleAdvertisementSupported == true)
            val manager = context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
            server = manager.openGattServer(context, callback) ?: error("Server unavailable")
            val service = BluetoothGattService(SERVICE, BluetoothGattService.SERVICE_TYPE_PRIMARY)
            service.addCharacteristic(BluetoothGattCharacteristic(RX, BluetoothGattCharacteristic.PROPERTY_WRITE, BluetoothGattCharacteristic.PERMISSION_WRITE))
            service.addCharacteristic(tx)
            check(server?.addService(service) == true)
        } catch (_: Exception) { clearRadio(); emit("status", "Bluetooth unavailable. Check Nearby devices access.") }
    }
    private val advertiser = object : AdvertiseCallback() {
        override fun onStartSuccess(settings: AdvertiseSettings) { emit("status", "Searching for nearby people…") }
        override fun onStartFailure(errorCode: Int) { clearRadio(); emit("status", "Could not start Bluetooth. Try again.") }
    }
    private val scan = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult) { handler.post {
            if (!active || links.size >= 4 || links.containsKey(result.device.address)) return@post
            val remote = result.scanRecord?.getServiceData(ParcelUuid(SERVICE)) ?: return@post
            if (remote.size != 4 || token.contentEquals(remote)) return@post
            // Session-random tie break avoids two simultaneous links per phone pair.
            val ours = token.joinToString("") { "%02x".format(it.toInt() and 255) }
            val theirs = remote.joinToString("") { "%02x".format(it.toInt() and 255) }
            if (ours >= theirs || result.rssi < -90) return@post
            val address = result.device.address
            if (SystemClock.elapsedRealtime() < (failures[address]?.second ?: 0L) || links.values.any { !it.ready }) return@post
            val link = Link(result.device); links[address] = link
            try {
                link.gatt = result.device.connectGatt(context, false, client, BluetoothDevice.TRANSPORT_LE)
                handler.postDelayed({ if (links[address] === link && !link.ready) drop(address) }, 15000)
            } catch (_: Exception) { drop(address) }
        } }
        override fun onScanFailed(errorCode: Int) { scanning = false; emit("status", "Discovery interrupted. Reconnecting…") }
    }
    private fun ready(address: String) {
        links[address]?.ready = true; failures.remove(address)
        emit("connected", true, address)
    }
    private fun drop(address: String) {
        val link = links.remove(address) ?: return
        link.timeout?.let { handler.removeCallbacks(it) }
        link.result?.error("connection", "Connection interrupted — retrying", null)
        try { if (link.gatt != null) { link.gatt?.disconnect(); link.gatt?.close() } else server?.cancelConnection(link.device) } catch (_: Exception) {}
        val count = ((failures[address]?.first ?: 0) + 1).coerceAtMost(6)
        if (failures.size >= 256) failures.remove(failures.keys.first())
        failures[address] = count to (SystemClock.elapsedRealtime() + (1000L shl count))
        emit("connected", false, address)
    }
    private fun incoming(address: String, value: ByteArray) {
        val link = links[address] ?: return
        val now = SystemClock.elapsedRealtime()
        if (now - link.window > 60000) { link.window = now; link.packets = 0 }
        if (value.size !in 5..20 || link.packets >= 120) return
        val index = ((value[0].toInt() and 255) shl 8) or (value[1].toInt() and 255)
        val total = ((value[2].toInt() and 255) shl 8) or (value[3].toInt() and 255)
        if (index == 0) { link.incoming.reset(); link.index = 0; link.total = total }
        if (total !in 1..512 || index != link.index || total != link.total || (index > 0 && now - link.last > 10000)) {
            link.incoming.reset(); link.index = 0; return
        }
        link.incoming.write(value, 4, value.size - 4); link.index++; link.last = now
        if (link.incoming.size() > 8192) { link.incoming.reset(); link.index = 0; return }
        if (link.index == total) { link.packets++; emit("packet", link.incoming.toByteArray(), address); link.incoming.reset(); link.index = 0 }
    }
    private val callback = object : BluetoothGattServerCallback() {
        override fun onServiceAdded(status: Int, service: BluetoothGattService) { handler.post {
            if (!active || server == null) return@post
            if (status != BluetoothGatt.GATT_SUCCESS) { clearRadio(); emit("status", "Bluetooth unavailable"); return@post }
            try {
                val bleAdvertiser = adapter.bluetoothLeAdvertiser ?: error("Advertising unavailable")
                val bleScanner = adapter.bluetoothLeScanner ?: error("Scanning unavailable")
                bleAdvertiser.startAdvertising(
                    AdvertiseSettings.Builder().setConnectable(true).setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_BALANCED).build(),
                    AdvertiseData.Builder().addServiceUuid(ParcelUuid(SERVICE)).build(),
                    AdvertiseData.Builder().addServiceData(ParcelUuid(SERVICE), token).build(), advertiser)
                bleScanner.startScan(listOf(ScanFilter.Builder().setServiceUuid(ParcelUuid(SERVICE)).build()),
                    ScanSettings.Builder().setScanMode(ScanSettings.SCAN_MODE_LOW_POWER).build(), scan)
                scanning = true
            } catch (_: Exception) { clearRadio(); emit("status", "Bluetooth permission or adapter unavailable") }
        } }
        override fun onConnectionStateChange(device: BluetoothDevice, status: Int, newState: Int) { handler.post {
            if (newState == BluetoothProfile.STATE_CONNECTED) {
                if (!active || links.size >= 4 || links.containsKey(device.address)) { server?.cancelConnection(device); return@post }
                val link = Link(device); links[device.address] = link
                handler.postDelayed({ if (links[device.address] === link && !link.ready) drop(device.address) }, 15000)
            } else if (links[device.address]?.gatt == null) drop(device.address)
        } }
        override fun onDescriptorWriteRequest(device: BluetoothDevice, requestId: Int, descriptor: BluetoothGattDescriptor, preparedWrite: Boolean, responseNeeded: Boolean, offset: Int, value: ByteArray) { handler.post {
            val valid = links.containsKey(device.address) && descriptor.uuid == CCC && !preparedWrite && offset == 0 && value.contentEquals(BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE)
            if (responseNeeded) server?.sendResponse(device, requestId, if (valid) 0 else 257, 0, null)
            if (valid) ready(device.address)
        } }
        override fun onCharacteristicWriteRequest(device: BluetoothDevice, requestId: Int, characteristic: BluetoothGattCharacteristic, preparedWrite: Boolean, responseNeeded: Boolean, offset: Int, value: ByteArray) { handler.post {
            val valid = links[device.address]?.ready == true && characteristic.uuid == RX && !preparedWrite && offset == 0 && value.size in 5..20
            if (responseNeeded) server?.sendResponse(device, requestId, if (valid) 0 else 257, 0, null)
            if (valid) incoming(device.address, value)
        } }
        override fun onNotificationSent(device: BluetoothDevice, status: Int) { handler.post {
            if (status == BluetoothGatt.GATT_SUCCESS) next(device.address) else drop(device.address)
        } }
    }
    private val client = object : BluetoothGattCallback() {
        override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) { handler.post {
            if (links[gatt.device.address]?.gatt !== gatt) { gatt.close(); return@post }
            if (status == 0 && newState == BluetoothProfile.STATE_CONNECTED) gatt.discoverServices() else drop(gatt.device.address)
        } }
        @Suppress("DEPRECATION")
        override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) { handler.post {
            val link = links[gatt.device.address] ?: return@post
            val service = gatt.getService(SERVICE)
            val notify = service?.getCharacteristic(TX)
            val descriptor = notify?.getDescriptor(CCC)
            link.rx = service?.getCharacteristic(RX)
            if (status != 0 || descriptor == null || link.rx == null || !gatt.setCharacteristicNotification(notify, true)) { drop(gatt.device.address); return@post }
            descriptor.value = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
            if (!gatt.writeDescriptor(descriptor)) drop(gatt.device.address)
        } }
        override fun onDescriptorWrite(gatt: BluetoothGatt, descriptor: BluetoothGattDescriptor, status: Int) { handler.post {
            if (status == 0) ready(gatt.device.address) else drop(gatt.device.address)
        } }
        @Deprecated("Compatibility callback")
        override fun onCharacteristicChanged(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic) {
            @Suppress("DEPRECATION") val bytes = characteristic.value.clone()
            if (Build.VERSION.SDK_INT < 33) handler.post { incoming(gatt.device.address, bytes) }
        }
        override fun onCharacteristicChanged(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, value: ByteArray) { handler.post { incoming(gatt.device.address, value) } }
        override fun onCharacteristicWrite(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, status: Int) { handler.post {
            if (status == 0) next(gatt.device.address) else drop(gatt.device.address)
        } }
    }
    fun send(address: String, bytes: ByteArray, result: MethodChannel.Result) {
        val link = links[address]
        if (link?.ready != true || link.result != null || bytes.size !in 1..8192) { result.error("busy", "Connection busy or interrupted", null); return }
        link.result = result
        val count = (bytes.size + 15) / 16
        for (i in 0 until count) link.frames.addLast(byteArrayOf((i shr 8).toByte(), i.toByte(), (count shr 8).toByte(), count.toByte()) + bytes.copyOfRange(i * 16, minOf(bytes.size, (i + 1) * 16)))
        val timeout = Runnable { if (links[address] === link && link.result != null) drop(address) }
        link.timeout = timeout; handler.postDelayed(timeout, 30000)
        next(address)
    }
    @Suppress("DEPRECATION")
    private fun next(address: String) {
        val link = links[address] ?: return
        if (link.frames.isEmpty()) { link.timeout?.let { handler.removeCallbacks(it) }; val done = link.result; link.result = null; done?.success(null); return }
        val bytes = link.frames.removeFirst()
        try {
            val accepted = if (link.gatt != null) {
                val rx = link.rx ?: error("Missing characteristic")
                rx.writeType = BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT; rx.value = bytes
                link.gatt!!.writeCharacteristic(rx)
            } else if (Build.VERSION.SDK_INT >= 33) server?.notifyCharacteristicChanged(link.device, tx, false, bytes) == BluetoothStatusCodes.SUCCESS
            else { tx.value = bytes; server?.notifyCharacteristicChanged(link.device, tx, false) == true }
            if (!accepted) drop(address)
        } catch (_: Exception) { drop(address) }
    }
    private fun clearRadio() {
        try { if (scanning) adapter?.bluetoothLeScanner?.stopScan(scan); adapter?.bluetoothLeAdvertiser?.stopAdvertising(advertiser) } catch (_: Exception) {}
        scanning = false
        for (address in links.keys.toList()) drop(address)
        try { server?.close() } catch (_: Exception) {}
        server = null
    }
    fun stop() {
        active = false; clearRadio()
        if (registered) { context.unregisterReceiver(stateReceiver); registered = false }
        emit("status", "Bluetooth paused")
    }
}
