//
//  AudioPlayer.swift
//  AUHost
//
//  Created by michal on 04/05/2019.
//  Copyright © 2019 borama. All rights reserved.
//
import AVFoundation

class AudioPlayer: NSObject {
    
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private var file: AVAudioFile!
    private var isPlaying = false
    private let audioPlayerQueue = DispatchQueue(label: "AudioPlayerQueue")
    
    // audio unit properties:
    public var audioUnit: AUAudioUnit?
    private var audioUnitNode: AVAudioUnit?
    
    init(_ url: URL) {
        guard let file = try? AVAudioFile(forReading: url) else {
            fatalError("can't load file")
        }
        self.file = file
        super.init()
        engine.attach(playerNode)
    }
    
    func play() {
        audioPlayerQueue.sync {
            guard !self.isPlaying else { return }
            self.startPlaying()
        }
    }
    
    public func selectAudioUnitWithComponentDescription(_ componentDescription: AudioComponentDescription?, completionHandler: @escaping (() -> Void)) {
        // Internal function to resume playing and call the completion handler.
        func done() {
            if isPlaying {
                playerNode.play()
            }
            completionHandler()
        }
        
        let hardwareFormat = self.engine.outputNode.outputFormat(forBus: 0)
        
        self.engine.connect(self.engine.mainMixerNode, to: self.engine.outputNode, format: hardwareFormat)
        
        /*
         Pause the player before re-wiring it. (It is not simple to keep it
         playing across an insertion or deletion.)
         */
        if isPlaying {
            playerNode.pause()
        }
        
        // Destroy any pre-existing unit.
        
        if audioUnitNode != nil {
            // Break player -> effect connection.
            engine.disconnectNodeInput(audioUnitNode!)
            
            
            // Break audioUnitNode -> mixer connection
            engine.disconnectNodeInput(engine.mainMixerNode)
            
            // Connect player -> mixer.
            engine.connect(playerNode, to: engine.mainMixerNode, format: file!.processingFormat)
            
            // We're done with the unit; release all references.
            engine.detach(audioUnitNode!)
            
            audioUnitNode = nil
            audioUnit = nil
        }
        
        // Insert the audio unit, if any.
        if let componentDescription = componentDescription {
            AVAudioUnit.instantiate(with: componentDescription, options: []) { avAudioUnit, error in
                guard let avAudioUnit = avAudioUnit else {
                    fatalError("avAudioUnit nil \(String(describing: error))")
                }
                
                self.audioUnitNode = avAudioUnit
                self.engine.attach(avAudioUnit)
                
                // Disconnect player -> mixer.
                self.engine.disconnectNodeInput(self.engine.mainMixerNode)
                
                // Connect player -> effect -> mixer.
                self.engine.connect(self.playerNode, to: avAudioUnit, format: self.file!.processingFormat)
                self.engine.connect(avAudioUnit, to: self.engine.mainMixerNode, format: self.file!.processingFormat)
                
                self.audioUnit = avAudioUnit.auAudioUnit
                avAudioUnit.auAudioUnit.contextName = "running in AUv3Host"
                
                done()
            }
        } else {
            done()
        }
    }
    
    private func startPlaying() {
        // remove this first line: engine.connect(playerNode, to: engine.mainMixerNode, format: file.processingFormat)
        scheduleLoop(file)
        let hardwareFormat = engine.outputNode.outputFormat(forBus: 0)
        engine.connect(engine.mainMixerNode, to: engine.outputNode, format: hardwareFormat)
        do {
            try engine.start()
        } catch {
            fatalError("can't start engine \(error)")
        }
        playerNode.play()
        isPlaying = true
    }
    
    private func scheduleLoop(_ file: AVAudioFile) {
        playerNode.scheduleFile(file, at: nil) {
            self.audioPlayerQueue.async {
                if self.isPlaying {
                    self.scheduleLoop(file)
                }
            }
        }
    }
}
