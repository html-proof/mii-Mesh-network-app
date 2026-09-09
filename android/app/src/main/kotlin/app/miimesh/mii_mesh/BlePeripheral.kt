package app.miimesh.mii_mesh

import android.Manifest
import android.bluetooth.*
import android.bluetooth.le.*
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.ParcelUuid
import io.flutter.plugin.common.EventChannel
import java.io.ByteArrayOutputStream
import java.util.UUID

/** One-peer foreground BLE link. Only encrypted application packets cross it. */
class BlePeripheral(private val context: Context) : EventChannel.StreamHandler {
    companion object {
        val SERVICE: UUID = UUID.fromString("c0a80101-7d2b-4e18-9bf0-3ae5f1000001")
        val RX: UUID = UUID.fromString("c0a80101-7d2b-4e18-9bf0-3ae5f1000002")
        val TX: UUID = UUID.fromString("c0a80101-7d2b-4e18-9bf0-3ae5f1000003")
        val CCC: UUID = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")
    }
    private val handler = Handler(Looper.getMainLooper())
    private val adapter get() = (context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager).adapter
    private var events: EventChannel.EventSink? = null
    private var server: BluetoothGattServer? = null
    private var peer: BluetoothDevice? = null
    private var subscribed = false
    private var running = false
    private val incoming = ByteArrayOutputStream()
    private var expectedIndex = 0
    private var expectedTotal = 0
    private var lastFrame = 0L
    private val outgoing = ArrayDeque<ByteArray>()
    private var notifying = false
    private var packetCount = 0
    private var windowStart = 0L
    private val tx = BluetoothGattCharacteristic(TX, BluetoothGattCharacteristic.PROPERTY_NOTIFY, BluetoothGattCharacteristic.PERMISSION_READ).apply {
        addDescriptor(BluetoothGattDescriptor(CCC, BluetoothGattDescriptor.PERMISSION_READ or BluetoothGattDescriptor.PERMISSION_WRITE))
    }
    private fun emit(type: String, value: Any? = null) { handler.post { events?.success(mapOf("type" to type, "value" to value)) } }
    override fun onListen(arguments: Any?, sink: EventChannel.EventSink) { events = sink }
    override fun onCancel(arguments: Any?) { events = null; stop() }
    fun start() {
        if (running) return
        val a = adapter ?: error("Bluetooth hardware is unavailable")
        check(a.isEnabled) { "Turn on Bluetooth in phone settings" }
        check(a.isMultipleAdvertisementSupported) { "BLE advertising is unsupported" }
        val manager = context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
        server = manager.openGattServer(context, callback) ?: error("Cannot open Bluetooth server")
        running = true
        val service = BluetoothGattService(SERVICE, BluetoothGattService.SERVICE_TYPE_PRIMARY)
        service.addCharacteristic(BluetoothGattCharacteristic(RX, BluetoothGattCharacteristic.PROPERTY_WRITE, BluetoothGattCharacteristic.PERMISSION_WRITE))
        service.addCharacteristic(tx)
        if (server?.addService(service) != true) { stop(); error("Cannot register Bluetooth service") }
    }
    private val advertiseCallback = object : AdvertiseCallback() {
        override fun onStartSuccess(settings: AdvertiseSettings) { emit("status", "Advertising · waiting for laptop") }
        override fun onStartFailure(code: Int) { emit("error", "Bluetooth advertising failed ($code)"); stop() }
    }
    private val callback = object : BluetoothGattServerCallback() {
        override fun onServiceAdded(status: Int, service: BluetoothGattService) {
            handler.post {
                if (!running) return@post
                if (status != BluetoothGatt.GATT_SUCCESS) { emit("error", "Service registration failed"); stop(); return@post }
                try {
                    val advertiser = adapter.bluetoothLeAdvertiser ?: error("BLE advertising unavailable")
                    advertiser.startAdvertising(
                        AdvertiseSettings.Builder().setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_BALANCED).setConnectable(true).setTimeout(0).build(),
                        AdvertiseData.Builder().addServiceUuid(ParcelUuid(SERVICE)).setIncludeDeviceName(false).build(), advertiseCallback)
                } catch (_: Exception) { emit("error", "Bluetooth permission or adapter unavailable"); stop() }
            }
        }
        override fun onConnectionStateChange(device: BluetoothDevice, status: Int, newState: Int) {
            handler.post {
                if (newState == BluetoothProfile.STATE_CONNECTED) {
                    if (peer != null && peer != device) { server?.cancelConnection(device); return@post }
                    peer = device; emit("status", "Laptop connected · awaiting subscription")
                } else if (peer == device) {
                    peer = null; subscribed = false; incoming.reset(); outgoing.clear(); notifying = false; expectedIndex = 0
                    emit("connected", false); emit("status", "Disconnected · waiting for laptop")
                }
            }
        }
        override fun onDescriptorWriteRequest(device: BluetoothDevice, requestId: Int, descriptor: BluetoothGattDescriptor, preparedWrite: Boolean, responseNeeded: Boolean, offset: Int, value: ByteArray) {
            handler.post {
                val valid = device == peer && descriptor.uuid == CCC && !preparedWrite && offset == 0 &&
                    (value.contentEquals(BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE) || value.contentEquals(BluetoothGattDescriptor.DISABLE_NOTIFICATION_VALUE))
                if (valid) { subscribed = value.contentEquals(BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE); emit("connected", subscribed); emit("status", if (subscribed) "Bluetooth connected" else "Notifications disabled") }
                if (responseNeeded) server?.sendResponse(device, requestId, if (valid) BluetoothGatt.GATT_SUCCESS else BluetoothGatt.GATT_FAILURE, 0, null)
            }
        }
        override fun onDescriptorReadRequest(device: BluetoothDevice, requestId: Int, offset: Int, descriptor: BluetoothGattDescriptor) {
            handler.post { server?.sendResponse(device, requestId, if (offset == 0) BluetoothGatt.GATT_SUCCESS else BluetoothGatt.GATT_INVALID_OFFSET, 0, if (subscribed) BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE else BluetoothGattDescriptor.DISABLE_NOTIFICATION_VALUE) }
        }
        override fun onCharacteristicWriteRequest(device: BluetoothDevice, requestId: Int, characteristic: BluetoothGattCharacteristic, preparedWrite: Boolean, responseNeeded: Boolean, offset: Int, value: ByteArray) {
            handler.post {
                val valid = running && peer == device && characteristic.uuid == RX && !preparedWrite && offset == 0 && value.size in 5..20
                if (responseNeeded) server?.sendResponse(device, requestId, if (valid) BluetoothGatt.GATT_SUCCESS else BluetoothGatt.GATT_FAILURE, 0, null)
                if (!valid) return@post
                val now = android.os.SystemClock.elapsedRealtime()
                if (now - windowStart > 60000) { windowStart = now; packetCount = 0 }
                if (packetCount >= 120) return@post
                val index = ((value[0].toInt() and 255) shl 8) or (value[1].toInt() and 255)
                val total = ((value[2].toInt() and 255) shl 8) or (value[3].toInt() and 255)
                if (index == 0) { incoming.reset(); expectedIndex = 0; expectedTotal = total }
                if (total !in 1..256 || index != expectedIndex || total != expectedTotal || (index > 0 && now - lastFrame > 10000)) { incoming.reset(); expectedIndex = 0; return@post }
                incoming.write(value, 4, value.size - 4); expectedIndex++; lastFrame = now
                if (incoming.size() > 4096) { incoming.reset(); expectedIndex = 0; return@post }
                if (expectedIndex == total) { packetCount++; emit("packet", incoming.toByteArray()); incoming.reset(); expectedIndex = 0 }
            }
        }
        override fun onNotificationSent(device: BluetoothDevice, status: Int) {
            handler.post {
                notifying = false
                if (status != BluetoothGatt.GATT_SUCCESS) { outgoing.clear(); emit("error", "Bluetooth send failed; retry the message") }
                sendNext()
            }
        }
    }
    fun send(bytes: ByteArray) {
        check(running && peer != null && subscribed) { "Laptop is not connected" }
        require(bytes.size in 1..4096) { "Packet too large" }
        val total = (bytes.size + 15) / 16
        check(outgoing.size + total <= 512) { "Bluetooth queue is full" }
        for (i in 0 until total) {
            outgoing.addLast(byteArrayOf((i shr 8).toByte(), i.toByte(), (total shr 8).toByte(), total.toByte()) + bytes.copyOfRange(i * 16, minOf(bytes.size, (i + 1) * 16)))
        }
        sendNext()
    }
    @Suppress("DEPRECATION")
    private fun sendNext() {
        if (notifying || outgoing.isEmpty() || !subscribed) return
        val device = peer ?: return
        val value = outgoing.removeFirst(); notifying = true
        val accepted = if (Build.VERSION.SDK_INT >= 33) server?.notifyCharacteristicChanged(device, tx, false, value) == BluetoothStatusCodes.SUCCESS
            else { tx.value = value; server?.notifyCharacteristicChanged(device, tx, false) == true }
        if (!accepted) { notifying = false; outgoing.clear(); emit("error", "Bluetooth send failed") }
    }
    fun stop() {
        running = false
        try { adapter?.bluetoothLeAdvertiser?.stopAdvertising(advertiseCallback); peer?.let { server?.cancelConnection(it) }; server?.close() } catch (_: Exception) { }
        server = null; peer = null; subscribed = false; incoming.reset(); outgoing.clear(); notifying = false; expectedIndex = 0
        emit("connected", false); emit("status", "Bluetooth stopped")
    }
}
