//
//  Player.swift
//  MusicColaboration
//
//  Created by Bao Pham on 10/27/15.
//  Copyright © 2015 BaoPham. All rights reserved.
//

import Foundation
import AudioToolbox
import AVFoundation
import Accelerate


//create a player structure
class PlayerData {
    
    var audioQueue: AudioQueueRef = nil //audio queu
    
    var streamFormat: AudioStreamBasicDescription! //format of the song
    
    var bufferSize = UInt32() //size of the buffer
    
    //var startingFrameCount = Double()
    
    var numSamplesInFile = UInt32() //number of audio samples
    
    var dataL:[Float]!
    var dataR:[Float]!
    
    var currentPos = 0 //current position in the audio queue
    
    var rmsValue = 0.0 //calculate the power output
    var rmsValueAverage = 0.0
    var count = 0
    var sum = 0.0 //sum for rms calculation
    var sum2 = 0.0 //sum for rms average
    var rmsArray: [Double] = [] //array that store rms values

    var beginning = true
    
    var fftValues = [Float](count: BUFFER_LENGTH, repeatedValue: 0.0)
    var frequency = Float()
    var fftSumInEachFrame = Float()
    
    //bin number for every note
    var binPositionArray = Array<Array<Int>>()
    
    //weight for every note
    var chromaArray = [Float](count: 12, repeatedValue: 0.0)
    
    //frequency values for each note
    var freqArray = Array<Array<Float>>()
    
    //all these values will be stored in freqArray
    var freqC:  [Float] =   [32.703,  65.406, 130.813, 261.626, 523.251, 1046.502, 2093.005]
    var freqCs: [Float] =   [34.648,  69.296, 138.591, 277.183, 554.365, 1108.731, 2217.461]
    var freqD:  [Float] =   [36.708,  73.416, 146.832, 293.665, 587.330, 1174.659, 2349.318]
    var freqDs: [Float] =   [38.891,  77.782, 155.563, 311.127, 622.254, 1244.508, 2489.016]
    var freqE:  [Float] =   [41.203,  82.407, 164.814, 329.628, 659.255, 1318.510, 2637.020]
    var freqF:  [Float] =   [43.654,  87.307, 174.614, 349.228, 698.456, 1396.913, 2793.826]
    var freqFs: [Float] =   [46.249,  92.499, 184.997, 369.994, 739.989, 1479.978, 2959.955]
    var freqG:  [Float] =   [48.999,  97.999, 195.998, 391.995, 783.991, 1567.982, 3135.963]
    var freqGs: [Float] =   [51.913, 103.826, 207.652, 415.305, 830.609, 1661.219, 3322.438]
    var freqA:  [Float] =   [55.000, 110.000, 220.000, 440.000, 880.000, 1760.000, 3520.000]
    var freqAs: [Float] =   [58.270, 116.541, 233.082, 466.164, 932.328, 1864.655, 3729.310]
    var freqB:  [Float] =   [61.735, 123.471, 246.942, 493.883, 987.767, 1975.533, 3951.066]
    
    
    //for play and stop the audio
    var isPlaying = true

    func play(){
        isPlaying = true
    }
    
    func stop(){
        isPlaying = false
    }
    
    //fill the buffer, callback functions
    func fillBuffer(buffer: AudioQueueBufferRef) -> OSStatus{
        
        let data = UnsafeMutablePointer<Float>(buffer.memory.mAudioData)
        var dataAverage = [Float](count: BUFFER_LENGTH, repeatedValue: 0.0)
        
        for frame in 0..<BUFFER_LENGTH{
            
            if isPlaying
            {
                if (currentPos < Int(numSamplesInFile)){
                    data[frame] = (dataL[currentPos] + dataR[currentPos])/2
                    
                    dataAverage[frame] = data[frame] //getting the song's data
                    
                    sum += pow(Double(data[frame]), 2.0)
                    
                    currentPos+=1
                }else {
                    data[frame] = 0
                }
            }
            else{
                data[frame] = 0
            }
        }
        
        if isPlaying{
            
            //-------------------------chroma-------------------------//
            
            //find the bin position for each note
            if beginning{
                freqArray.append(freqA)
                freqArray.append(freqAs)
                freqArray.append(freqB)
                freqArray.append(freqC)
                freqArray.append(freqCs)
                freqArray.append(freqD)
                freqArray.append(freqDs)
                freqArray.append(freqE)
                freqArray.append(freqF)
                freqArray.append(freqFs)
                freqArray.append(freqG)
                freqArray.append(freqGs)
                
                for i in 0..<freqArray.count{
                    binPositionArray.append(getBinsNumber(freqArray[i]))
                }
                
                beginning = false
            }
            
            //get the fft values
            fftValues = getFFTvalues(dataAverage)
            
            //find the sum of fft values for each frame
            fftSumInEachFrame = findSumOfEachFrame(fftValues)
            
            //calculate the weight for each note
            for i in 0..<chromaArray.count{
                chromaArray[i] = calculateTheWeightforEachNote(binPositionArray[i])
                //print(" \(i): \(chromaArray[i])", terminator: "")
            }
            //print("")
            //0 = A; 1 = As; 2 = B; 3 = C; 4 = Cs; 5 = D; 6 = Ds; 7 = E; 8 = F; 9 = Fs; 10= G; 11= Gs
            
            //normalize the weight
            normalizeWeight()
            //------------------------------------------------------------//
            
            
            //-------------------------rms values--------------------------//
            //normalize the rmsArray
            if count > 10{
                sum2 = 0
                for index in 0..<rmsArray.count{
                    sum2 += rmsArray[index]
                }
                rmsValueAverage = pow(sum2/Double(rmsArray.count), 0.33) //to increase the power
                rmsArray.removeFirst()
                //print("rms average: \(rmsValueAverage)")
            }
            
            rmsValue = sqrt(sum/Double(BUFFER_LENGTH)) //calculate the rms value
            rmsArray.append(rmsValue)
            sum = 0
            count++
            rmsValue = 0
            //-------------------------------------------------------------//
        }

        buffer.memory.mAudioDataByteSize = bufferSize
        
        return noErr
    }
    
    //normalize the weight for eac not
    func normalizeWeight(){
        
        let chromaMax = chromaArray.maxElement()
        
        for i in 0..<chromaArray.count{
            chromaArray[i] = powf(chromaArray[i] / chromaMax!, 10)
        }
    }
    
    //calculate the weight for each note in a frame
    func calculateTheWeightforEachNote(binsPositionForNote: [Int]) -> Float{
        var weight:Float = 0.0
        for i in 0..<binsPositionForNote.count{
            weight += fftValues[binsPositionForNote[i]]
        }
        weight = weight / fftSumInEachFrame
        return weight
    }
    
    //calculate the bin position for each note
    func getBinsNumber(freqArray: [Float]) -> [Int]{
        var binsPositionForNote = [Int](count: 7, repeatedValue: 0)
        var binsPosition = 0
        var index = 0
        for i in 0..<freqArray.count{
            binsPosition = Int(round(Float(freqArray[i])*Float(BUFFER_LENGTH)/Float(44100)))
            binsPositionForNote[index] = binsPosition
            index++
        }
        index = 0
        return binsPositionForNote
    }
    
    //calculate the sum of each frame
    func findSumOfEachFrame(fftArray: [Float]) -> Float{
        var sum: Float = 0.0
        for i in 0..<fftArray.count{
            sum += fftArray[i]
        }
        return sum
    }

    
    
    //------------------------FFT Calculation-----------------------//
    //for calculating FFT
    func sqrt2(x: [Float]) -> [Float] {
        var results = [Float](count:x.count, repeatedValue:0.0)
        vvsqrtf(&results, x, [Int32(x.count)])
        return results
    }
    
    func getFFTvalues(input: [Float]) -> [Float]{
       
        var real = [Float](input)
        //imaginary will be fined with 0s
        var imaginary:[Float]? = [Float](count: input.count, repeatedValue: 0.0)
        var splitComplex = DSPSplitComplex(realp: &real, imagp: &imaginary!)
        
        let length = vDSP_Length(log2(Float(input.count)))
        let radix = FFTRadix(kFFTRadix2)
        let fftweight = vDSP_create_fftsetup(length, radix)
        
        //perform fft
        vDSP_fft_zip(fftweight, &splitComplex, 1, length, FFTDirection(FFT_FORWARD))
    
        //this contains squared values (all positive)
        var magnitudes:[Float] = [Float](count: input.count, repeatedValue: 0.0)
        vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(input.count))
        
        //take the square root of every value
        var normalizedMagnitudes = [Float](count: input.count, repeatedValue: 0.0)
        vDSP_vsmul(sqrt2(magnitudes), 1, [2.0 / Float(input.count)], &normalizedMagnitudes, 1, vDSP_Length(input.count))
        
        vDSP_destroy_fftsetup(fftweight)
        
        let returnArray:[Float] = Array(normalizedMagnitudes[0..<Int(normalizedMagnitudes.count/2)])
        return returnArray
        
    }
    
    //--------------------------------------------------------------//

    
    //set data to left and right from the file
    func setLeftAndRightData(bufferDataL:UnsafeMutablePointer<Float>,bufferDataR:UnsafeMutablePointer<Float>,size:Int){
        
        dataL = [Float](count: size, repeatedValue: 0.0)
        dataR = [Float](count: size, repeatedValue: 0.0)
        
        
        for i:Int in 0..<size{
            dataL[i] = bufferDataL[i]
            dataR[i] = bufferDataR[i]
        }
        
        currentPos = 0
    }
}