//
//  AudioUnitViewController.swift
//  VolumePlugin
//
//  Created by michal on 04/05/2019.
//  Copyright © 2019 borama. All rights reserved.
//

import CoreAudioKit

public class AudioUnitViewController: AUViewController, AUAudioUnitFactory {
    public var audioUnit: VolumePluginAudioUnit? {
        didSet {
            DispatchQueue.main.async {
                if self.isViewLoaded {
                    self.connectWithAU()
                }
            }
        }
    }
    
    private var volumeParam: AUParameter?
    
    // this initializer is called by NSExtensionContextVendor beginRequestWithExtensionItems,
    // without it Garage Band will not show the UI!
    init() {
        super.init(nibName: "AudioUnitViewController", bundle: Bundle(for: AudioUnitViewController.self))
    }
    
    override public init(nibName nibNameOrNil: NSNib.Name?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: "AudioUnitViewController", bundle: Bundle(for: AudioUnitViewController.self))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        if audioUnit == nil {
            return
        }
        self.connectWithAU()
    }
    
    func connectWithAU() {
        guard let paramTree = audioUnit?.parameterTree else {
            fatalError("paramTree nil!")
        }
        volumeParam = paramTree.value(forKey: "param1") as? AUParameter
    }
    
    public func createAudioUnit(with componentDescription: AudioComponentDescription) throws -> AUAudioUnit {
        audioUnit = try VolumePluginAudioUnit(componentDescription: componentDescription, options: [])
        
        return audioUnit!
    }
    
    
    @IBAction func volumeSlider(_ sender: NSSliderCell) {
        volumeParam?.value = AUValue(sender.doubleValue)
    }
}
