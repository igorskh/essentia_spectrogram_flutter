import Flutter
import UIKit

internal class AudioLoader {
    static func readAudioFile(filePath: String) throws -> [Float] {
        let fileURL = URL(fileURLWithPath: filePath)
        
        // 2. Open the file
        let audioFile = try AVAudioFile(forReading: fileURL)
        
        // 3. Create a buffer to hold the audio data
        // The processingFormat is typically 32-bit float, non-interleaved
        let format = audioFile.processingFormat
        let frameCount = AVAudioFrameCount(audioFile.length)
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw NSError(domain: "AudioLoader", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not create audio buffer."])
        }
        
        // 4. Read the file into the buffer
        try audioFile.read(into: buffer)
        
        // 5. Extract the float data pointer
        // floatChannelData is an array of pointers (one for each channel). We take channel 0 (Left/Mono).
        guard let floatChannelData = buffer.floatChannelData else {
            throw NSError(domain: "AudioLoader", code: -1, userInfo: [NSLocalizedDescriptionKey: "Buffer does not contain float data."])
        }
        
        // return audio samples
        let samplesPointer = floatChannelData[0] // Maps to `const float*` in C++
        let length = Int(buffer.frameLength)
        return Array(UnsafeBufferPointer(start: samplesPointer, count: length))
    }
}

internal class MelSpectrogramCompute {
    static func processChunked(
        audioSamples: [Float],
        sampleRate: Int,
        frameSize: Int,
        hopSize: Int,
        numBands: Int,
        maxChunkSize: Int
    ) -> [[Float]] {
        if audioSamples.count <= maxChunkSize {
            // If audio is small enough, process normally
            let melSpec = EssentiaBridge.computeMelSpectrogram(
                fromFloatSamples: audioSamples,
                length: UInt(audioSamples.count),
                sampleRate: Double(sampleRate),
                frameSize: UInt(frameSize),
                hopSize: UInt(hopSize),
                numBands: UInt(numBands)
            )
            return melSpec.map { $0.map { $0.floatValue } }
        }
        
        // Calculate overlap needed to avoid discontinuities
        // We need at least (frameSize - hopSize) samples overlap
        let minOverlap = max(frameSize - hopSize, hopSize)
        let overlap = minOverlap + (hopSize - (minOverlap % hopSize)) // Align to hop size
        
        var allResults: [[Float]] = []
        var currentIndex = 0
        
        while currentIndex < audioSamples.count {
            // Calculate chunk boundaries
            let chunkStart = max(0, currentIndex - overlap)
            let chunkEnd = min(audioSamples.count, currentIndex + maxChunkSize)
            
            // Extract chunk using Swift array slicing
            let chunk = Array(audioSamples[chunkStart..<chunkEnd])
            
            // Process chunk
            let chunkResult = EssentiaBridge.computeMelSpectrogram(
                fromFloatSamples: chunk,
                length: UInt(chunk.count),
                sampleRate: Double(sampleRate),
                frameSize: UInt(frameSize),
                hopSize: UInt(hopSize),
                numBands: UInt(numBands)
            )
            
            // Calculate how much of this chunk's result to keep
            let floatChunkResult = chunkResult.map { $0.map { $0.floatValue } }
            
            if currentIndex == 0 {
                allResults.append(contentsOf: floatChunkResult)
            } else {
                let overlapFrames = (overlap + hopSize - 1) / hopSize
                let validResults = floatChunkResult.dropFirst(overlapFrames)
                allResults.append(contentsOf: validResults)
            }
            
            currentIndex += maxChunkSize
        }
        
        return allResults
    }
}

public class EssentiaSpectrogramFlutterPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "essentia_spectrogram_flutter", binaryMessenger: registrar.messenger())
    let instance = EssentiaSpectrogramFlutterPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getPlatformVersion":
            result("iOS " + UIDevice.current.systemVersion)
        case "returnVersion":
            result(EssentiaBridge.returnVersion())
        case "readAudioFile":
            guard let args = call.arguments as? [String: Any],
                  let path = args["filePath"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "Path is required", details: nil))
                return
            }
            
            do {
                result(try AudioLoader.readAudioFile(filePath: path))
            } catch {
                result(FlutterError(code: "AUDIO_READ_ERROR", message: error.localizedDescription, details: nil))
            }
            
        case "readAndComputeMelSpectrogram":
            guard let args = call.arguments as? [String: Any],
                  let path = args["filePath"] as? String,
                  let sampleRate = args["sampleRate"] as? Int,
                  let frameSize = args["frameSize"] as? Int,
                  let hopSize = args["hopSize"] as? Int,
                  let numBands = args["numBands"] as? Int else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "Missing required parameters", details: nil))
                return
            }
            // read optional arguments
            let maxChunkSize = args["maxChunkSize"] as? Int ?? sampleRate * 30
            
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let audioSamples = try AudioLoader.readAudioFile(filePath: path)
                    let melSpec = MelSpectrogramCompute.processChunked(
                        audioSamples: audioSamples,
                        sampleRate: sampleRate,
                        frameSize: frameSize,
                        hopSize: hopSize,
                        numBands: numBands,
                        maxChunkSize: maxChunkSize
                    )
                    result(melSpec)
                } catch {
                    result(FlutterError(code: "PROCESSING_ERROR", message: error.localizedDescription, details: nil))
                }
            }
        case "computeMelSpectrogram":
            guard let args = call.arguments as? [String: Any],
                  let audioSamples = args["audioSamples"] as? [Float],
                  let sampleRate = args["sampleRate"] as? Int,
                  let frameSize = args["frameSize"] as? Int,
                  let hopSize = args["hopSize"] as? Int,
                  let numBands = args["numBands"] as? Int else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "Missing required parameters", details: nil))
                return
            }
            let maxChunkSize = args["maxChunkSize"] as? Int ?? sampleRate * 30
            
            DispatchQueue.global(qos: .userInitiated).async {
                let melSpec = MelSpectrogramCompute.processChunked(
                    audioSamples: audioSamples,
                    sampleRate: sampleRate,
                    frameSize: frameSize,
                    hopSize: hopSize,
                    numBands: numBands,
                    maxChunkSize: maxChunkSize
                )
                result(melSpec)
            }
        default:
            result(FlutterMethodNotImplemented)
        }
  }
}
