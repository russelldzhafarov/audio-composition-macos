//
//  AudioTrack.swift
//  audio-composition-macos
//
//  Created by russell.dzhafarov@gmail.com on 22.08.2021.
//

import AVFoundation
import Cocoa

class AudioTrack: Identifiable {
    let id = UUID()
    var name: String
    var asset: AudioAsset
    
    init(name: String, asset: AudioAsset) {
        self.name = name
        self.asset = asset
    }
    
    var format: AVAudioFormat {
        asset.format
    }
    
    var duration: TimeInterval {
        asset.duration
    }
    
    @objc dynamic var volume: Float = 1.0 {
        didSet {
            player.volume = volume
        }
    }
    @objc dynamic var pan: Float = 0.0 {
        didSet {
            player.pan = pan
        }
    }
    var isMuted: Bool = false {
        didSet {
            player.volume = isMuted ? 0.0 : volume
        }
    }
    
    let player = AVAudioPlayerNode()
    
    var currentFrame: AVAudioFramePosition {
        guard let lastRenderTime = player.lastRenderTime,
              let playerTime = player.playerTime(forNodeTime: lastRenderTime)
        else {
            return 0
        }
        return playerTime.sampleTime
    }
    
    public func schedule(at currentTime: TimeInterval) {
        if currentTime > (asset.startTime.seconds + asset.duration) {
            return
        }
        
        let time = AVAudioTime(
            sampleTime: AVAudioFramePosition((asset.startTime.seconds - currentTime) * asset.buffer.format.sampleRate),
            atRate: asset.buffer.format.sampleRate)
        
        if currentTime <= asset.startTime.seconds {
            player.scheduleBuffer(asset.buffer, at: time)
        }
        
        if currentTime > asset.startTime.seconds && currentTime < (asset.startTime.seconds + asset.duration) {
            
            let from = currentTime - asset.startTime.seconds
            let to = Double(asset.buffer.frameCapacity) / asset.buffer.format.sampleRate
            
            if let segment = asset.buffer.extract(from: from, to: to) {
                player.scheduleBuffer(segment, at: nil)
            }
        }
    }
    public func stop() {
        player.stop()
    }
    public func pause() {
        player.pause()
    }
    public func play() {
        player.play()
    }
}
