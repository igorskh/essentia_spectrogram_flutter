//
//  EssentiaBridge.h
//  essentia-ios-demo
//
//  Created by Igor Kim 2 on 14.03.26.
//


#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN

@interface EssentiaBridge : NSObject

+ (NSString*)returnVersion;

//+ (void)computeMelSpectrogramFromFloatSamples:(const float*)samples
+ (NSArray<NSArray<NSNumber*>*>*)computeMelSpectrogramFromFloatSamples:(const float*)samples
                                                                length:(NSUInteger)length
                                                             sampleRate:(double)sampleRate
                                                             frameSize:(NSUInteger)frameSize
                                                               hopSize:(NSUInteger)hopSize
                                                               numBands:(NSUInteger)numBands;

@end

NS_ASSUME_NONNULL_END
