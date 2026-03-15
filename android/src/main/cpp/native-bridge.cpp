#include <jni.h>
#include <android/log.h>
#include <vector>
#include "essentia.h"
#include "algorithmfactory.h"
#include "pool.h"
#include "version.h"

#define LOG_TAG "EssentiaBridge"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)

using namespace essentia;
using namespace essentia::standard;


extern "C"
JNIEXPORT jstring JNICALL
Java_one_beagile_essentia_1spectrogram_1flutter_NativeBridge_returnVersion(JNIEnv *env, jobject thiz) {
    return env->NewStringUTF(ESSENTIA_VERSION);
}

extern "C"
JNIEXPORT jobjectArray JNICALL
Java_one_beagile_essentia_1spectrogram_1flutter_NativeBridge_computeMelSpectrogram(
        JNIEnv *env, jobject thiz,
        jfloatArray audioSamples,
        jint sampleRate,
        jint frameSize,
        jint hopSize,
        jint numBands) {

    // 1. Init Essentia
    essentia::init();

    // 2. Convert Java float[] → std::vector<Real>
    jsize length = env->GetArrayLength(audioSamples);
    jfloat* samples = env->GetFloatArrayElements(audioSamples, nullptr);
    std::vector<Real> audio(samples, samples + length);
    env->ReleaseFloatArrayElements(audioSamples, samples, JNI_ABORT);

    // 3. Create algorithms
    Algorithm* frameCutter = AlgorithmFactory::create("FrameCutter",
                                            "frameSize", (int)frameSize,
                                            "hopSize",   (int)hopSize,
                                            "startFromZero", true);

    Algorithm* windowing = AlgorithmFactory::create("Windowing",
                                          "type", "hann");

    Algorithm* spectrum = AlgorithmFactory::create("Spectrum",
                                         "size", (int)frameSize);

    Algorithm* melBands = AlgorithmFactory::create("MelBands",
                                         "sampleRate",        (int)sampleRate,
                                         "numberBands",       (int)numBands,
                                         "lowFrequencyBound", 0.0f,
                                         "highFrequencyBound",(float)(sampleRate / 2));

    // 4. Wire up FrameCutter input
    frameCutter->input("signal").set(audio);

    // 5. Process frames
    std::vector<Real> frame, windowedFrame, spectrumFrame, melBandsFrame;
    std::vector<std::vector<Real>> melSpectrogram;

    frameCutter->output("frame").set(frame);

    while (true) {
        frameCutter->compute();

        if (frame.empty()) break;
        if ((int)frame.size() != frameSize) break; // skip last incomplete frame

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

    for (int i = 0; i < (int)melSpectrogram.size(); i++) {
        jfloatArray row = env->NewFloatArray((jsize)melSpectrogram[i].size());
        env->SetFloatArrayRegion(row, 0,
                                 (jsize)melSpectrogram[i].size(), melSpectrogram[i].data());
        env->SetObjectArrayElement(result, i, row);
        env->DeleteLocalRef(row);
    }

    return result;
}