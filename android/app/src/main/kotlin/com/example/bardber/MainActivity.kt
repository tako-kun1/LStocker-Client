package cloud.nazono.lstocker

import com.symbol.emdk.EMDKManager
import com.symbol.emdk.EMDKResults
import com.symbol.emdk.barcode.BarcodeManager
import com.symbol.emdk.barcode.ScanDataCollection
import com.symbol.emdk.barcode.Scanner
import com.symbol.emdk.barcode.StatusData
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity :
	FlutterActivity(),
	EMDKManager.EMDKListener,
	Scanner.DataListener,
	Scanner.StatusListener {

	private val methodChannelName = "cloud.nazono.lstocker/barcode_reader"
	private val eventChannelName = "cloud.nazono.lstocker/barcode_reader_events"

	private var emdkManager: EMDKManager? = null
	private var barcodeManager: BarcodeManager? = null
	private var scanner: Scanner? = null
	private var eventSink: EventChannel.EventSink? = null
	private var pendingStartScan = false
	private var scannerEnabled = false

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, methodChannelName)
			.setMethodCallHandler { call, result ->
				handleMethodCall(call, result)
			}

		EventChannel(flutterEngine.dartExecutor.binaryMessenger, eventChannelName)
			.setStreamHandler(
				object : EventChannel.StreamHandler {
					override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
						eventSink = events
					}

					override fun onCancel(arguments: Any?) {
						eventSink = null
					}
				},
			)
	}

	private fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
		when (call.method) {
			"initialize" -> initializeScanner(result)
			"startScan" -> startScan(result)
			"stopScan" -> stopScan(result)
			"dispose" -> {
				releaseScanner()
				result.success(null)
			}

			else -> result.notImplemented()
		}
	}

	private fun initializeScanner(result: MethodChannel.Result) {
		if (emdkManager != null && scanner != null) {
			result.success(true)
			return
		}

		val emdkResults = EMDKManager.getEMDKManager(applicationContext, this)
		val success = emdkResults.statusCode == EMDKResults.STATUS_CODE.SUCCESS
		if (!success) {
			result.error("emdk_init_failed", "EMDK の初期化に失敗しました。", null)
			return
		}

		result.success(true)
	}

	private fun startScan(result: MethodChannel.Result) {
		val activeScanner = scanner
		if (activeScanner == null) {
			pendingStartScan = true
			result.success(null)
			return
		}

		try {
			if (!scannerEnabled) {
				activeScanner.enable()
				scannerEnabled = true
			}
			pendingStartScan = true
			activeScanner.read()
			result.success(null)
		} catch (e: Exception) {
			result.error("scan_start_failed", e.message, null)
		}
	}

	private fun stopScan(result: MethodChannel.Result) {
		try {
			scanner?.cancelRead()
			pendingStartScan = false
			result.success(null)
		} catch (e: Exception) {
			result.error("scan_stop_failed", e.message, null)
		}
	}

	override fun onOpened(manager: EMDKManager?) {
		emdkManager = manager
		barcodeManager = manager?.getInstance(EMDKManager.FEATURE_TYPE.BARCODE) as? BarcodeManager
		createScanner()
	}

	override fun onClosed() {
		releaseScanner()
		barcodeManager = null
		emdkManager = null
	}

	private fun createScanner() {
		try {
			scanner = barcodeManager?.getDevice(BarcodeManager.DeviceIdentifier.DEFAULT)
			scanner?.addDataListener(this)
			scanner?.addStatusListener(this)
			scanner?.triggerType = Scanner.TriggerType.HARD
		} catch (e: Exception) {
			eventSink?.error("scanner_create_failed", e.message, null)
		}
	}

	override fun onData(scanDataCollection: ScanDataCollection?) {
		val scanData = scanDataCollection?.scanData?.firstOrNull()?.data ?: return
		pendingStartScan = false
		runOnUiThread {
			eventSink?.success(scanData)
		}
	}

	override fun onStatus(statusData: StatusData?) {
		val state = statusData?.getState() ?: return
		if (state == StatusData.ScannerStates.IDLE && pendingStartScan) {
			try {
				scanner?.read()
			} catch (e: Exception) {
				runOnUiThread {
					eventSink?.error("scanner_read_failed", e.message, null)
				}
			}
		}
	}

	private fun releaseScanner() {
		try {
			scanner?.cancelRead()
			scanner?.removeDataListener(this)
			scanner?.removeStatusListener(this)
			if (scannerEnabled) {
				scanner?.disable()
			}
			scanner?.release()
		} catch (_: Exception) {
		} finally {
			scannerEnabled = false
			pendingStartScan = false
			scanner = null
		}
	}

	override fun onDestroy() {
		releaseScanner()
		emdkManager?.release(EMDKManager.FEATURE_TYPE.BARCODE)
		emdkManager?.release()
		super.onDestroy()
	}
}
