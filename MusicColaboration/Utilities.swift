//
//  Utilities.swift
//  MusicColaboration
//
//  Created by Bao Pham on 10/22/15.
//  Copyright © 2015 BaoPham. All rights reserved.
//

import Foundation
import AudioToolbox

//utilities functions
class Utilities {
    
    let player = PlayerData()
    
    //check for function error
    func CheckError(error: OSStatus, operation: String) {
        guard error != noErr else {
            return
        }
        
        var result: String = ""
        var char = Int(error.bigEndian)
        
        for _ in 0..<4 {
            guard isprint(Int32(char&255)) == 1 else {
                result = "\(error)"
                break
            }
            result.append(UnicodeScalar(char&255))
            char = char/256
        }
        
        print("Error: \(operation) (\(result))")
        
        exit(1)
    }
    
    //get the magic cookie from the song
    //some audio formats uses magic cookie.
    //magic cookie is an opaque block of data that contains values that are unique to given codec.
    func CopyEncoderCookieToQueue(theFile: AudioFileID, queue: AudioQueueRef) {
        var propertySize = UInt32()
        let result = AudioFileGetPropertyInfo(theFile, kAudioFilePropertyMagicCookieData, &propertySize, nil)
        
        if result == noErr && propertySize > 0 {
            let magicCookie = UnsafeMutablePointer<UInt8>(malloc(sizeof(UInt8) * Int(propertySize)))
            
            CheckError(AudioFileGetProperty(theFile, kAudioFilePropertyMagicCookieData, &propertySize, magicCookie), operation: "Get cookie from file failed")
            
            CheckError(AudioQueueSetProperty(queue, kAudioQueueProperty_MagicCookie, magicCookie, propertySize), operation: "Set cookie on queue failed")
            
            free(magicCookie)
        }
    }
    
    func CalculateBytesForTime(inAudioFile: AudioFileID, inDesc: AudioStreamBasicDescription, inSeconds: Double, inout outBufferSize: UInt32, inout outNumPackets: UInt32) {
        var maxPacketSize = UInt32()
        var propSize = UInt32(sizeof(maxPacketSize.dynamicType))
        
        CheckError(AudioFileGetProperty(inAudioFile, kAudioFilePropertyPacketSizeUpperBound, &propSize, &maxPacketSize), operation: "Couldn't get file's max packet size")
        
        let maxBufferSize: UInt32 = 0x10000
        let minBufferSize: UInt32 = 0x4000
        
        if inDesc.mFramesPerPacket > 0 {
            let numPacketsForTime = inDesc.mSampleRate / Double(inDesc.mFramesPerPacket) * inSeconds
            
            outBufferSize = UInt32(numPacketsForTime) * maxPacketSize
        } else {
            outBufferSize = maxBufferSize > maxPacketSize ? maxBufferSize : maxPacketSize
        }
        
        if outBufferSize > maxBufferSize && outBufferSize > maxPacketSize {
            outBufferSize = maxBufferSize
        } else {
            if outBufferSize < minBufferSize {
                outBufferSize = minBufferSize
            }
        }
        
        outNumPackets = outBufferSize / maxPacketSize
    }

    //Playback callback function
    let AQOutputCallback: AudioQueueOutputCallback = {(inPlayerData, inAQ, inBuffer) -> () in
        
        var playerData = UnsafeMutablePointer<PlayerData>(inPlayerData)
        
        var utility = Utilities()
        
        utility.CheckError(playerData.memory.fillBuffer(inBuffer),
            operation: "Can't refill buffer")
        
        utility.CheckError(AudioQueueEnqueueBuffer(inAQ, inBuffer, 0, nil), operation: "Couldn't enqueue the buffer (refill)")
        
    }
}
