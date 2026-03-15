package one.beagile.essentia_spectrogram_flutter

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

import java.util.concurrent.Executors
import android.content.Context

/** EssentiaSpectrogramFlutterPlugin */
class EssentiaSpectrogramFlutterPlugin :
    FlutterPlugin,
    MethodCallHandler {
    // The MethodChannel that will the communication between Flutter and native Android
    //
    // This local reference serves to register the plugin with the Flutter Engine and unregister it
    // when the Flutter Engine is detached from the Activity
    private lateinit var channel: MethodChannel
    private lateinit var context: Context

    private val executor = Executors.newSingleThreadExecutor()

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "essentia_spectrogram_flutter")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(
        call: MethodCall,
        result: Result
    ) {
        if (call.method == "getPlatformVersion") {
            result.success("Android ${android.os.Build.VERSION.RELEASE}")
        } else if (call.method == "returnVersion") {
            result.success(NativeBridge.returnVersion())
        } else if (call.method == "computeMelSpectrogram") {
            val audioSamples = call.argument<FloatArray>("audioSamples")!!
            val sampleRate = call.argument<Int>("sampleRate")!!
            val frameSize = call.argument<Int>("frameSize")!!
            val hopSize = call.argument<Int>("hopSize")!!
            val numBands = call.argument<Int>("numBands")!!
            val maxChunkSize = call.argument<Int>("maxChunkSize") ?: (sampleRate * 30) // Default: 30 seconds
            
            executor.execute {
                try {
                    val melSpec = MelSpectrogramCompute.processChunked(
                        audioSamples,
                        sampleRate,
                        frameSize,
                        hopSize,
                        numBands,
                        maxChunkSize
                    )
                    result.success(melSpec)
                } catch (e: Exception) {
                    result.error(
                        "COMPUTE_ERROR",
                        e.message ?: "Unknown computation error",
                        null
                    )
                }
            }
        } else if (call.method == "readAudioFile") {
            val filePath = call.argument<String>("filePath")

            if (filePath.isNullOrBlank()) {
                result.error("INVALID_ARGUMENT", "filePath is required", null)
                return
            }

            executor.execute {
                try {
                    val waveform = AudioDecoder.decodeAudioFile(
                        context,
                        filePath
                    )
                    // Flutter's Result must be called on the platform (main) thread
                    // MethodChannel handles marshalling automatically here
                    result.success(waveform.toList())
                } catch (e: Exception) {
                    result.error(
                        "DECODE_ERROR",
                        e.message ?: "Unknown decoding error",
                        null
                    )
                }
            }
        } else if (call.method == "readAndComputeMelSpectrogram") {
            val filePath = call.argument<String>("filePath")
            val sampleRate = call.argument<Int>("sampleRate")!!
            val frameSize = call.argument<Int>("frameSize")!!
            val hopSize = call.argument<Int>("hopSize")!!
            val numBands = call.argument<Int>("numBands")!!
            val maxChunkSize = call.argument<Int>("maxChunkSize") ?: (sampleRate * 30) // Default: 30 seconds

            if (filePath.isNullOrBlank()) {
                result.error("INVALID_ARGUMENT", "filePath is required", null)
                return
            }

            executor.execute {
                try {
                    val waveform = AudioDecoder.decodeAudioFile(
                        context,
                        filePath
                    )
                    val melSpec = MelSpectrogramCompute.processChunked(
                        waveform,
                        sampleRate,
                        frameSize,
                        hopSize,
                        numBands,
                        maxChunkSize
                    )
                    result.success(melSpec)
                } catch (e: Exception) {
                    result.error(
                        "DECODE_ERROR",
                        e.message ?: "Unknown decoding error",
                        null
                    )
                }
            }
        } else {
            result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        executor.shutdown()
    }
}
