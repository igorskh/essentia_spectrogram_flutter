#define MINIAUDIO_IMPLEMENTATION
#define MA_NO_ENCODING
#define MA_NO_DEVICE_IO
#define MA_NO_ENGINE
#define MA_NO_NODE_GRAPH
#include "miniaudio.h"

#include <jni.h>
#include <android/log.h>
#include <vector>
#include "essentia.h"
#include "algorithmfactory.h"
#include "pool.h"
#include "version.h"

#define LOG_TAG "EssentiaBridge"
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)

using namespace essentia;
using namespace essentia::standard;

extern "C" JNIEXPORT jstring JNICALL
Java_one_beagile_essentia_1spectrogram_1flutter_NativeBridge_returnVersion(JNIEnv *env, jobject thiz)
{
    return env->NewStringUTF(ESSENTIA_VERSION);
}

extern "C" JNIEXPORT jobjectArray JNICALL
Java_one_beagile_essentia_1spectrogram_1flutter_NativeBridge_computeMelSpectrogram(
    JNIEnv *env, jobject thiz,
    jfloatArray audioSamples,
    jint sampleRate,
    jint frameSize,
    jint hopSize,
    jint numBands,
    jint minFreq,
    jint maxFreq
) {

    // 1. Init Essentia
    essentia::init();

    // 2. Convert Java float[] → std::vector<Real>
    jsize length = env->GetArrayLength(audioSamples);
    jfloat *samples = env->GetFloatArrayElements(audioSamples, nullptr);
    std::vector<Real> audio(samples, samples + length);
    env->ReleaseFloatArrayElements(audioSamples, samples, JNI_ABORT);

    // 3. Create algorithms
    Algorithm *frameCutter = AlgorithmFactory::create("FrameCutter",
                                                      "frameSize", (int)frameSize,
                                                      "hopSize", (int)hopSize,
                                                      "startFromZero", true);

    Algorithm *windowing = AlgorithmFactory::create("Windowing",
                                                    "type", "hann");

    Algorithm *spectrum = AlgorithmFactory::create("Spectrum",
                                                   "size", (int)frameSize);

    Algorithm *melBands = AlgorithmFactory::create("MelBands",
                                                   "sampleRate", (int)sampleRate,
                                                   "numberBands", (int)numBands,
                                                   "lowFrequencyBound", (float)minFreq,
                                                   "highFrequencyBound", (float)maxFreq);

    // 4. Wire up FrameCutter input
    frameCutter->input("signal").set(audio);

    // 5. Process frames
    std::vector<Real> frame, windowedFrame, spectrumFrame, melBandsFrame;
    std::vector<std::vector<Real>> melSpectrogram;

    frameCutter->output("frame").set(frame);

    while (true)
    {
        frameCutter->compute();

        if (frame.empty())
            break;
        if ((int)frame.size() != frameSize)
            break; // skip last incomplete frame

        // Window
        windowing->input("frame").set(frame);
        windowing->output("frame").set(windowedFrame);
        windowing->compute();

        // Spectrum
        spectrum->input("frame").set(windowedFrame);
        spectrum->output("spectrum").set(spectrumFrame);
        spectrum->compute();

        // MEL Bands
        melBands->input("spectrum").set(spectrumFrame);
        melBands->output("bands").set(melBandsFrame);
        melBands->compute();

        melSpectrogram.push_back(melBandsFrame);
    }

    // 6. Cleanup
    delete frameCutter;
    delete windowing;
    delete spectrum;
    delete melBands;
    essentia::shutdown();

    // 7. Convert result → Java float[][]
    jclass floatArrayClass = env->FindClass("[F");
    jobjectArray result = env->NewObjectArray(
        (jsize)melSpectrogram.size(), floatArrayClass, nullptr);

    for (int i = 0; i < (int)melSpectrogram.size(); i++)
    {
        jfloatArray row = env->NewFloatArray((jsize)melSpectrogram[i].size());
        env->SetFloatArrayRegion(row, 0,
                                 (jsize)melSpectrogram[i].size(), melSpectrogram[i].data());
        env->SetObjectArrayElement(result, i, row);
        env->DeleteLocalRef(row);
    }

    return result;
}

extern "C"
JNIEXPORT jfloatArray JNICALL
Java_one_beagile_essentia_1spectrogram_1flutter_NativeBridge_decode(
    JNIEnv *env, jobject thiz,
    jstring jFilePath, jint targetSampleRate
) {
    const char *filePath = env->GetStringUTFChars(jFilePath, nullptr);

    // Configure decoder: output mono float32 at target sample rate
    ma_decoder_config config = ma_decoder_config_init(
        ma_format_f32,           // output format: 32-bit float
        1,                       // output channels: mono
        (ma_uint32)targetSampleRate
    );

    ma_decoder decoder;
    ma_result result = ma_decoder_init_file(filePath, &config, &decoder);
    if (result != MA_SUCCESS) {
        LOGE("Failed to open file: %s (error %d)", filePath, result);
        env->ReleaseStringUTFChars(jFilePath, filePath);
        return nullptr;
    }

    // Get total frame count for pre-allocation
    ma_uint64 totalFrames;
    ma_decoder_get_length_in_pcm_frames(&decoder, &totalFrames);

    float *pcmData = nullptr;
    ma_uint64 framesRead = 0;

    if (totalFrames > 0) {
        // Known length: single allocation, single read
        pcmData = (float *)malloc(totalFrames * sizeof(float));
        ma_decoder_read_pcm_frames(&decoder, pcmData, totalFrames, &framesRead);
    } else {
        // Unknown length (streaming format): read in chunks
        ma_uint64 capacity = 1024 * 1024;  // start with ~1M samples
        pcmData = (float *)malloc(capacity * sizeof(float));
        framesRead = 0;

        while (true) {
            ma_uint64 chunkSize = 65536;
            if (framesRead + chunkSize > capacity) {
                capacity *= 2;
                pcmData = (float *)realloc(pcmData, capacity * sizeof(float));
            }
            ma_uint64 read = 0;
            ma_decoder_read_pcm_frames(&decoder, pcmData + framesRead, chunkSize, &read);
            if (read == 0) break;
            framesRead += read;
        }
    }

    ma_decoder_uninit(&decoder);
    env->ReleaseStringUTFChars(jFilePath, filePath);

    // Copy to Java float array
    jfloatArray jResult = env->NewFloatArray((jsize)framesRead);
    env->SetFloatArrayRegion(jResult, 0, (jsize)framesRead, pcmData);
    free(pcmData);

    return jResult;
}