//
//  ViewController.swift
//  MusicColaboration
//
//  Created by Bao Pham on 10/22/15.
//  Copyright © 2015 BaoPham. All rights reserved.
//

import UIKit
import AudioToolbox
import AVFoundation
import MediaPlayer
import QuartzCore

let BUFFER_LENGTH = 2048
let BUFFER_COUNT = 3

class ViewController: UIViewController, MPMediaPickerControllerDelegate {

    //let kPlaybackFileLocation = "/Users/baopham/Desktop/test.mp3" as CFString
    
    var utility = Utilities()
    var playerData = PlayerData()
    
    //flag for audioQueue session
    var audioQueueStarted = false

    @IBOutlet weak var playPauseButton: UIButton!
    @IBOutlet weak var albumArt: UIImageView!
    @IBOutlet weak var timeSlider: UISlider!
    @IBOutlet weak var loadingIndicator: UIActivityIndicatorView!

    @IBOutlet weak var Cnote: UIButton!
    @IBOutlet weak var Gnote: UIButton!
    @IBOutlet weak var Dnote: UIButton!
    @IBOutlet weak var Anote: UIButton!
    @IBOutlet weak var Enote: UIButton!
    @IBOutlet weak var Bnote: UIButton!
    @IBOutlet weak var Fsnote: UIButton!
    @IBOutlet weak var Csnote: UIButton!
    @IBOutlet weak var Gsnote: UIButton!
    @IBOutlet weak var Dsnote: UIButton!
    @IBOutlet weak var Asnote: UIButton!
    @IBOutlet weak var Fnote: UIButton!
   
    
    var timer = NSTimer() //to update the timeSlider
    
    var audioSession = AVAudioSession.sharedInstance()
    
    var fileURL = NSURL()
    
    var updater = CADisplayLink()
    
    let musicPicker: MPMediaPickerController = MPMediaPickerController(mediaTypes: MPMediaType.Music)
    
    var backgroundColor = UIColor()
    var playAndPauseImages = [UIImage(named: "play.png"), UIImage(named: "pause.png")]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        //start the slider at 0
        timeSlider.value = 0
        timeSlider.enabled = false
        
        playPauseButton.enabled = false
        
        loadingIndicator.hidden = true
        loadingIndicator.hidesWhenStopped = true
    
        
        backgroundColor = self.view.backgroundColor!
        
        //set up audio session
        configureAudioSession()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    //hide the status bar
    override func prefersStatusBarHidden() -> Bool {
        return true
    }
    

    //-----------------------------------OPEN THE MUSIC LIBRARY---------------------------------------------//
    @IBAction func importYourMusic(sender: UIButton) {
        musicPicker.prompt = "Pick a song"
        musicPicker.allowsPickingMultipleItems = false
        musicPicker.delegate = self //make a copy
        
        //present it to the user
        presentViewController(musicPicker, animated: true, completion: nil)
    }
    
    //when user hits cancel
    func mediaPickerDidCancel(mediaPicker: MPMediaPickerController) {
        dismissViewControllerAnimated(true, completion: nil)
    }
    
    //after user picks a song
    func mediaPicker(mediaPicker: MPMediaPickerController, didPickMediaItems mediaItemCollection: MPMediaItemCollection) {
        
        playerData.stop()
        
        dismissViewControllerAnimated(true, completion: nil)
        
        //get the url from the song
        let currentSong: MPMediaItem = mediaItemCollection.items[0]
        
        if !playerData.isPlaying{
           playPauseButton.enabled = false
        }
        
        timeSlider.value = 0
        
        //get the album art work if any
        if let artwork: MPMediaItemArtwork = currentSong.valueForProperty(MPMediaItemPropertyArtwork) as? MPMediaItemArtwork{
            albumArt.image = artwork.imageWithSize(CGSize(width: albumArt.widthAnchor.accessibilityElementCount(), height: albumArt.heightAnchor.accessibilityElementCount()))
            albumArt.alpha = 1.0
        } else{
            albumArt.image = UIImage(named: "music-note.png")
            albumArt.alpha = 0.55
        }
        
        //set the url
        if let url: NSURL = currentSong.valueForProperty(MPMediaItemPropertyAssetURL) as? NSURL{
            fileURL = url
            //fileURL = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, kPlaybackFileLocation, CFURLPathStyle.CFURLPOSIXPathStyle, false)
            
            //loading and timeSlider after picking a song
            loadingIndicator.hidden = false
            loadingIndicator.startAnimating()
            timeSlider.enabled = false
            
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {
                self.playtheSong()
            })
        } else{
            //do something here when the song is nil
            timeSlider.enabled = false
        }
    }
    //------------------------------------------------------------------------------------------------------//
    
    
    
    //-------------------------------------AUDIO SESSION----------------------------------------------------//
    //set up the Audio Session to
    func configureAudioSession() {
        do {
            // setting session mode
            try audioSession.setMode(AVAudioSessionModeDefault)
            // setting session category
            try audioSession.setCategory(AVAudioSessionCategoryPlayback)
        } catch {
            print("Error: \(error)")
        }
    }
    //------------------------------------------------------------------------------------------------------//
    
    func updateUI(){
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        updateTimeSlider()
        changeBackgroundAlpha()
        changeNoteAlpha()
        CATransaction.commit()
    }
    
    //changing the background
    func changeBackgroundAlpha(){
        self.view.backgroundColor = UIColor.whiteColor().colorWithAlphaComponent(CGFloat(playerData.rmsValueAverage))
    }
    
    func changeNoteAlpha(){
        Anote.alpha = CGFloat(playerData.chromaArray[0])
        
        Asnote.alpha = CGFloat(playerData.chromaArray[1])
       
        Bnote.alpha = CGFloat(playerData.chromaArray[2])
        
        Cnote.alpha = CGFloat(playerData.chromaArray[3])
        
        Csnote.alpha = CGFloat(playerData.chromaArray[4])
        
        Dnote.alpha = CGFloat(playerData.chromaArray[5])
        
        Dsnote.alpha = CGFloat(playerData.chromaArray[6])
        
        Enote.alpha = CGFloat(playerData.chromaArray[7])
        
        Fnote.alpha = CGFloat(playerData.chromaArray[8])
        
        Fsnote.alpha = CGFloat(playerData.chromaArray[9])
        
        Gnote.alpha = CGFloat(playerData.chromaArray[10])
        
        Gsnote.alpha = CGFloat(playerData.chromaArray[11])
    }
    
    
    //-------------------------------------------SLIDER-----------------------------------------------------//
    //move the slider as the song plays by percentage
    func updateTimeSlider(){
        timeSlider.value = Float(Float(playerData.currentPos) / Float(playerData.numSamplesInFile) * 100)
    }
    
    //change the song time by moving the slider
    @IBAction func changeSongTime(sender: UISlider) {
        playerData.currentPos = Int((timeSlider.value / 100) * Float(playerData.numSamplesInFile))
        updateTimeSlider()
    }
    //------------------------------------------------------------------------------------------------------//

    //play and pause the song
    @IBAction func playPause(sender: UIButton) {
        UIView.transitionWithView(self.view, duration: 0.3, options: UIViewAnimationOptions.TransitionCrossDissolve, animations: {
                if self.playerData.isPlaying{
                    self.playerData.stop()
                    self.playPauseButton.setImage(UIImage(named: "play.png"), forState: UIControlState.Normal)
                }else{
                    self.playerData.play()
                    self.playPauseButton.setImage(UIImage(named: "pause.png"), forState: UIControlState.Normal)
                }
            }, completion: nil)
    }


    //play the Song
    func playtheSong(){
    
    //--------------------------------Get the data from the song--------------------------------------------//
        //creating audio file from the url
        var tempAudioFile = AVAudioFile()
        do{
            try tempAudioFile = AVAudioFile(forReading: fileURL)
        }catch{
            print("Error: error with AVAudioFile")
        }
        //format of the audio file
        let tempAudioFormat = tempAudioFile.processingFormat
        //the length of the audio file samples
        let tempAudioFrameCount = UInt32(tempAudioFile.length)
        
        //create buffer object from audio file
        let tempAudioBuffer = AVAudioPCMBuffer(PCMFormat: tempAudioFormat, frameCapacity: tempAudioFrameCount)
        
        //read the audio file and load it into the buffer
        do{
            try tempAudioFile.readIntoBuffer(tempAudioBuffer)
        } catch{
            print("Error: error with readIntoBuffer")
        }
        
        //get number of audio samples (size of bigArray)
        playerData.numSamplesInFile = tempAudioBuffer.frameCapacity
        print("number of samples in the file: \(playerData.numSamplesInFile)")
        
        //get data arrays
        playerData.setLeftAndRightData(tempAudioBuffer.floatChannelData[0], bufferDataR: tempAudioBuffer.floatChannelData[0], size: Int(playerData.numSamplesInFile))
        
        
        //set values from timeSlider
        timeSlider.minimumValue = 0
        timeSlider.maximumValue = 100
        
        dispatch_async(dispatch_get_main_queue(), {
            
            self.playPauseButton.enabled = true
            self.playPauseButton.setImage(UIImage(named: "pause.png"), forState: UIControlState.Normal)
            
            //timer to update the timeSlider
            self.timer.invalidate()
            self.timer = NSTimer.scheduledTimerWithTimeInterval(1/60, target: self, selector: Selector("updateUI"), userInfo: nil, repeats: true)
            
            self.loadingIndicator.stopAnimating()
            self.timeSlider.enabled = true
        })
    //------------------------------------------------------------------------------------------------------//

        
    //-------------------------------------GET THE AUDIO FORMAT---------------------------------------------//
        playerData.streamFormat = AudioStreamBasicDescription(mSampleRate: 44100,
                                                              mFormatID: kAudioFormatLinearPCM,
                                                              mFormatFlags: kAudioFormatFlagIsFloat |
                                                                            kAudioFormatFlagIsPacked,
                                                              mBytesPerPacket: 4,
                                                              mFramesPerPacket: 1,
                                                              mBytesPerFrame: 4,
                                                              mChannelsPerFrame: 1,
                                                              mBitsPerChannel: 32,
                                                              mReserved: 0)
    //------------------------------------------------------------------------------------------------------//
    
    
        
    //--------------------------------------AUDIO QUEUE-----------------------------------------------------//
        //create a new playback Audio Queue object. in this case, it is stored in player.queue
        utility.CheckError(AudioQueueNewOutput(&playerData.streamFormat!, utility.AQOutputCallback, &playerData, nil, kCFRunLoopCommonModes, 0, &playerData.audioQueue),
            operation: "Couldn't create the output AudioQueue")
        
        //create and enqueue buffers
        var buffers = [AudioQueueBufferRef](count: BUFFER_COUNT, repeatedValue: AudioQueueBufferRef())
        
        playerData.bufferSize = UInt32(BUFFER_LENGTH) * UInt32(playerData.streamFormat.mBytesPerFrame)
        
        print("bufferSize is \(playerData.bufferSize)")
        
        for i in 0..<BUFFER_COUNT {
            utility.CheckError(AudioQueueAllocateBuffer(playerData.audioQueue, playerData.bufferSize, &buffers[i]),
                operation: "Couldn't allocate the Audio Queue buffer")
            
            utility.CheckError(playerData.fillBuffer(buffers[i]),
                operation: "Couldn't fill buffer (priming)")
            
            utility.CheckError(AudioQueueEnqueueBuffer(playerData.audioQueue, buffers[i], 0, nil),
                operation: "Couldn't enqueue buffer (priming)")
        }
        
        
        if !audioQueueStarted{
            // Start the audio queue
            utility.CheckError(AudioQueueStart(playerData.audioQueue, nil),
                operation: "Couldn't start the Audio Queue")
            audioQueueStarted = true
        }
        
        playerData.play()
        
    //------------------------------------------------------------------------------------------------------//
        print(" ")
    }
}