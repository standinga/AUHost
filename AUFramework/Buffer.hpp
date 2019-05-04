//
//  Buffer.hpp
//  AUHost
//
//  Created by michal on 04/05/2019.
//  Copyright © 2019 borama. All rights reserved.
//

#ifndef Buffer_h
#define Buffer_h

#import <AVFoundation/AVFoundation.h>
struct Buffer {
    AVAudioPCMBuffer *pcmBuffer = nullptr;
    AudioBufferList* mutableAudioBufferList = nullptr;
    AudioBufferList const* originalAudioBufferList = nullptr;
    AUAudioFrameCount maxFrames = 0;
    float volume = 1.0;
    
    /*
     prepareInputBufferList populates the mutableAudioBufferList with the data
     pointers from the originalAudioBufferList.
     
     The upstream audio unit may overwrite these with its own pointers, so each
     render cycle this function needs to be called to reset them.
     */
    void prepareInputBufferList() {
        UInt32 byteSize = maxFrames * sizeof(float);
        
        mutableAudioBufferList->mNumberBuffers = originalAudioBufferList->mNumberBuffers;
        
        for (UInt32 i = 0; i < originalAudioBufferList->mNumberBuffers; ++i) {
            mutableAudioBufferList->mBuffers[i].mNumberChannels = originalAudioBufferList->mBuffers[i].mNumberChannels;
            mutableAudioBufferList->mBuffers[i].mData = originalAudioBufferList->mBuffers[i].mData;
            mutableAudioBufferList->mBuffers[i].mDataByteSize = byteSize;
        }
    }
};

#endif /* Buffer_h */
