//
//  VolumePluginAudioUnit.m
//  VolumePlugin
//
//  Created by michal on 04/05/2019.
//  Copyright © 2019 borama. All rights reserved.
//

#import "VolumePluginAudioUnit.h"
#import "Buffer.hpp"
#import <AVFoundation/AVFoundation.h>

// Define parameter addresses.
const AudioUnitParameterID myParam1 = 0;

@interface VolumePluginAudioUnit ()

@property (nonatomic, readwrite) AUParameterTree *parameterTree;
@property AUAudioUnitBus *inputBus;
@property AUAudioUnitBus *outputBus;
@property AUAudioUnitBusArray *inputBusArray;
@property AUAudioUnitBusArray *outputBusArray;
@end

@implementation VolumePluginAudioUnit {
    Buffer _buffer;
}
@synthesize parameterTree = _parameterTree;

- (instancetype)initWithComponentDescription:(AudioComponentDescription)componentDescription options:(AudioComponentInstantiationOptions)options error:(NSError **)outError {
    self = [super initWithComponentDescription:componentDescription options:options error:outError];
    
    if (self == nil) { return nil; }
    
    // initialize Buffer
    _buffer = Buffer();
    _buffer.maxFrames = 0;
    _buffer.pcmBuffer = nullptr;
    _buffer.mutableAudioBufferList = nullptr;
    // Initialize a default format for the busses.
    AVAudioFormat *defaultFormat = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:44100.0 channels:2];
    
    // Create parameter objects.
    AUParameter *param1 = [AUParameterTree createParameterWithIdentifier:@"param1" name:@"Parameter 1" address:myParam1 min:0 max:100 unit:kAudioUnitParameterUnit_Percent unitName:nil flags:0 valueStrings:nil dependentParameters:nil];
    
    // Initialize the parameter values.
    param1.value = 1.0;
    
    // Create the parameter tree.
    _parameterTree = [AUParameterTree createTreeWithChildren:@[ param1 ]];
    
    // Create the input and output busses (AUAudioUnitBus).
    _inputBus = [[AUAudioUnitBus alloc] initWithFormat:defaultFormat error:nil];
    _outputBus = [[AUAudioUnitBus alloc] initWithFormat:defaultFormat error:nil];
    
    // Create the input and output bus arrays (AUAudioUnitBusArray).
    _inputBusArray = [[AUAudioUnitBusArray alloc] initWithAudioUnit:self busType:AUAudioUnitBusTypeInput busses:@[_inputBus]];
    _outputBusArray = [[AUAudioUnitBusArray alloc] initWithAudioUnit:self busType:AUAudioUnitBusTypeOutput busses:@[_outputBus]];
    
    // A function to provide string representations of parameter values.
    _parameterTree.implementorStringFromValueCallback = ^(AUParameter *param, const AUValue *__nullable valuePtr) {
        AUValue value = valuePtr == nil ? param.value : *valuePtr;
        
        switch (param.address) {
            case myParam1:
                return [NSString stringWithFormat:@"%.f", value];
            default:
                return @"?";
        }
    };
    
    __block Buffer *buffer = &_buffer;
    _parameterTree.implementorValueObserver = ^(AUParameter *param, AUValue value) {
        buffer->volume = value;
    };
    
    self.maximumFramesToRender = 512;
    
    return self;
}
#pragma mark - AUAudioUnit Overrides

// If an audio unit has input, an audio unit's audio input connection points.
// Subclassers must override this property getter and should return the same object every time.
// See sample code.
- (AUAudioUnitBusArray *)inputBusses {
    return _inputBusArray;
}
- (AUAudioUnitBusArray *)outputBusses {
    return _outputBusArray;
}

// Allocate resources required to render.
// Subclassers should call the superclass implementation.
- (BOOL)allocateRenderResourcesAndReturnError:(NSError **)outError {
    if (![super allocateRenderResourcesAndReturnError:outError]) {
        return NO;
    }
    
    // Validate that the bus formats are compatible.
    if (self.outputBus.format.channelCount != _inputBus.format.channelCount) {
        if (outError) {
            *outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:kAudioUnitErr_FailedInitialization userInfo:nil];
            NSLog(@"kAudioUnitErr_FailedInitialization at %d", __LINE__);
        }
        self.renderResourcesAllocated = NO;
        return NO;
    }
    // Allocate your resources.
    _buffer.maxFrames = self.maximumFramesToRender;
    _buffer.pcmBuffer = [[AVAudioPCMBuffer alloc] initWithPCMFormat:_inputBus.format frameCapacity: self.maximumFramesToRender];
    _buffer.originalAudioBufferList = _buffer.pcmBuffer.audioBufferList;
    _buffer.mutableAudioBufferList = _buffer.pcmBuffer.mutableAudioBufferList;
    return YES;
}

// Deallocate resources allocated in allocateRenderResourcesAndReturnError:
// Subclassers should call the superclass implementation.
- (void)deallocateRenderResources {
    // Deallocate your resources.
    [super deallocateRenderResources];
}

#pragma mark - AUAudioUnit (AUAudioUnitImplementation)

// Block which subclassers must provide to implement rendering.
- (AUInternalRenderBlock)internalRenderBlock {
    // Capture in locals to avoid ObjC member lookups. If "self" is captured in render, we're doing it wrong. See sample code.
    __block Buffer* buffer = &_buffer;
    
    return ^AUAudioUnitStatus(AudioUnitRenderActionFlags *actionFlags, const AudioTimeStamp *timestamp, AVAudioFrameCount frameCount, NSInteger outputBusNumber, AudioBufferList *outputData, const AURenderEvent *realtimeEventListHead, AURenderPullInputBlock pullInputBlock) {
        // Do event handling and signal processing here.
        AudioUnitRenderActionFlags pullFlags = 0;
        buffer->prepareInputBufferList();
        AUAudioUnitStatus err = pullInputBlock(&pullFlags, timestamp, frameCount, 0, buffer->mutableAudioBufferList);
        
        if (err != 0) {
            NSLog(@"AudioUnitRenderActionFlags");
            return err;
        }
        
        AudioBufferList *inAudioBufferList = buffer->mutableAudioBufferList;
        AudioBufferList *outAudioBufferList = outputData;
        
        // If passed null output buffer pointers, process in-place in the input buffer.
        if (outAudioBufferList->mBuffers[0].mData == nullptr) {
            for (UInt32 i = 0; i < outAudioBufferList->mNumberBuffers; ++i) {
                outAudioBufferList->mBuffers[i].mData = inAudioBufferList->mBuffers[i].mData;
            }
        }
        
        float* input = (float*)inAudioBufferList->mBuffers[0].mData;
        float* output = (float*)outAudioBufferList->mBuffers[0].mData;
        UInt32 dataSize = inAudioBufferList->mBuffers[0].mDataByteSize;
        for (int j = 0; j < inAudioBufferList->mNumberBuffers; j++) {
            for (int i = 0; i < dataSize; i++) {
                output[i] = buffer->volume * input[i];
            }
        }
        
        return noErr;
    };
}
@end

