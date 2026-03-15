//
//  EssentiaBridge.mm
//  essentia-ios-demo
//
//  Created by Igor Kim 2 on 14.03.26.
//

#import "EssentiaBridge.h"

#import <vector>

#import "essentia/algorithmfactory.h"
#import "essentia/pool.h"
#import "essentia/version.h"
#import "essentia/essentia.h"


@implementation EssentiaBridge

+ (NSString*)returnVersion {
    return [NSString stringWithUTF8String:ESSENTIA_VERSION];
}

//+ (void)computeMelSpectrogramFromFloatSamples:(const float*)samples
+ (NSArray<NSArray<NSNumber*>*>*)computeMelSpectrogramFromFloatSamples:(const float*)samples
                                                                length:(NSUInteger)length
                                                             sampleRate:(double)sampleRate
                                                             frameSize:(NSUInteger)frameSize
                                                               hopSize:(NSUInteger)hopSize
                                                               numBands:(NSUInteger)numBands 
                                                               minFreq:(double)minFreq
                                                               maxFreq:(double)maxFreq {
    
    essentia::init();

    std::vector<essentia::Real> audio(samples, samples + length);

    // 3. Create algorithms
    essentia::standard::Algorithm* frameCutter = essentia::standard::AlgorithmFactory::create("FrameCutter",
        "frameSize", (int)frameSize,
        "hopSize",   (int)hopSize,
        "startFromZero", true);
    
    essentia::standard::Algorithm* windowing = essentia::standard::AlgorithmFactory::create("Windowing",
        "type", "hann");

    essentia::standard::Algorithm* spectrum = essentia::standard::AlgorithmFactory::create("Spectrum",
        "size", (int)frameSize);

    essentia::standard::Algorithm* melBands = essentia::standard::AlgorithmFactory::create("MelBands",
        "sampleRate",        (int)sampleRate,
        "numberBands",       (int)numBands,
        "lowFrequencyBound", (double)minFreq,
        "highFrequencyBound",(double)maxFreq);

    // 4. Wire up FrameCutter input
    frameCutter->input("signal").set(audio);

    // 5. Process frames
    std::vector<essentia::Real> frame, windowedFrame, spectrumFrame, melBandsFrame;
    std::vector<std::vector<essentia::Real>> melSpectrogram;

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

    // 6. Cleanup algorithms
    delete frameCutter;
    delete windowing;
    delete spectrum;
    delete melBands;
    essentia::shutdown();

    // 7. Convert result → NSArray<NSArray<NSNumber*>*>
    NSMutableArray* result = [NSMutableArray arrayWithCapacity:melSpectrogram.size()];
    
    for (const auto& bandFrame : melSpectrogram) {
        NSMutableArray* row = [NSMutableArray arrayWithCapacity:bandFrame.size()];
        for (essentia::Real val : bandFrame) {
            [row addObject:@(val)];
        }
        [result addObject:[NSArray arrayWithArray:row]];
    }
    
    return [NSArray arrayWithArray:result];
}


@end
