package com.example.evse_app

import android.bluetooth.*
import android.content.*
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.OutputStream
import java.util.*

class MainActivity : FlutterActivity() {

    private val CHANNEL = "classic_bt"
    private val adapter: BluetoothAdapter? = BluetoothAdapter.getDefaultAdapter()

    private var socket: BluetoothSocket? = null
    private var output: OutputStream? = null

    private val SPP_UUID: UUID =
        UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->

                when (call.method) {

                    "scan" -> startScan(result)

                    "connect" -> {
                        val address = call.argument<String>("address")!!
                        connect(address, result)
                    }

                    "disconnect" -> {
                        disconnect()
                        result.success(true)
                    }

                    "send" -> {
                        val bytes = call.argument<List<Int>>("data")!!
                        send(bytes)
                        result.success(true)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    // ---------- SCAN ----------
    private fun startScan(result: MethodChannel.Result) {
        if (adapter == null) {
            result.error("NO_BT", "Bluetooth not supported", null)
            return
        }

        val devices = mutableListOf<Map<String, String>>()

        adapter.bondedDevices.forEach {
            devices.add(mapOf(
                "name" to (it.name ?: "Unknown"),
                "address" to it.address
            ))
        }

        val receiver = object : BroadcastReceiver() {
            override fun onReceive(c: Context, i: Intent) {
                when (i.action) {
                    BluetoothDevice.ACTION_FOUND -> {
                        val d = i.getParcelableExtra<BluetoothDevice>(BluetoothDevice.EXTRA_DEVICE)
                        d?.let {
                            devices.add(mapOf(
                                "name" to (it.name ?: "Unknown"),
                                "address" to it.address
                            ))
                        }
                    }
                    BluetoothAdapter.ACTION_DISCOVERY_FINISHED -> {
                        unregisterReceiver(this)
                        result.success(devices)
                    }
                }
            }
        }

        val filter = IntentFilter().apply {
            addAction(BluetoothDevice.ACTION_FOUND)
            addAction(BluetoothAdapter.ACTION_DISCOVERY_FINISHED)
        }

        registerReceiver(receiver, filter)
        adapter.startDiscovery()
    }

    // ---------- CONNECT ----------
    private fun connect(address: String, result: MethodChannel.Result) {
        try {
            val device = adapter!!.getRemoteDevice(address)
            socket = device.createRfcommSocketToServiceRecord(SPP_UUID)
            adapter.cancelDiscovery()
            socket!!.connect()
            output = socket!!.outputStream
            Log.d("BT", "Connected")
            result.success(true)
        } catch (e: Exception) {
            result.error("CONNECT_FAIL", e.message, null)
        }
    }

    // ---------- SEND ----------
    private fun send(data: List<Int>) {
        val bytes = data.map { it.toByte() }.toByteArray()
        output?.write(bytes)
        output?.flush()
        Log.d("BT", "Sent: ${bytes.joinToString()}")
    }

    // ---------- DISCONNECT ----------
    private fun disconnect() {
        try {
            output?.close()
            socket?.close()
        } catch (_: Exception) {}
        output = null
        socket = null
        Log.d("BT", "Disconnected")
    }
}
