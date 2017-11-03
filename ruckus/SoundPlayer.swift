//
//  SoundPlayer.swift
//  ruckus
//
//  Created by Gareth on 03.06.17.
//  Copyright © 2017 Gareth. All rights reserved.
//

import Foundation
import AVFoundation

enum PlayerError: Error {
    case FileNotFound
    case CouldNotCreateAPlayer
}

protocol PlaysSounds {
    func play(_ sound: String, withExtension ext: String) throws
}

class SoundPlayer: PlaysSounds {
    
    var player: AVAudioPlayer!
    
    // public function to play sound
    public func play(_ sound: String, withExtension ext: String) throws {
        guard let url = Bundle.main.url(forResource: sound, withExtension: ext) else {
            throw PlayerError.FileNotFound
        }
        
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback, with: .mixWithOthers)
            try AVAudioSession.sharedInstance().setActive(true)
            
            player = try AVAudioPlayer(contentsOf: url)
            guard let player = player else {
                throw PlayerError.CouldNotCreateAPlayer
            }
            
            player.play()
        } catch let error {
            fatalError(error.localizedDescription)
        }
    }
}
