//
//  AudioTrack.swift
//  audio-composition-macos
//
//  Created by russell.dzhafarov@gmail.com on 22.08.2021.
//

import AVFoundation
import Cocoa

class AudioTrack: Identifiable, Codable {
    
    enum CodingKeys: String, CodingKey {
        case name
        case asset
    }
    
    let id = UUID()
    var name: String
    var asset: AudioAsset?
    
    init(name: String, asset: AudioAsset?) {
        self.name = name
        self.asset = asset
    }
    
    required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        name = try values.decode(String.self, forKey: .name)
        asset = try values.decode(AudioAsset.self, forKey: .asset)
    }
    
    var format: AVAudioFormat {
        guard let asset = asset else { return AVAudioFormat() }
        return asset.format
    }
    
    var duration: TimeInterval {
        guard let asset = asset else { return 0 }
        return asset.startTime + asset.duration
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
    
    public func schedule(at currentTime: TimeInterval) {
        guard let asset = asset else { return }
        
        if currentTime > (asset.startTime + asset.duration) {
            return
        }
        
        let time = AVAudioTime(
            sampleTime: AVAudioFramePosition((asset.startTime - currentTime) * asset.buffer.format.sampleRate),
            atRate: asset.buffer.format.sampleRate)
        
        if currentTime <= asset.startTime {
            player.scheduleBuffer(asset.buffer, at: time)
        }
        
        if currentTime > asset.startTime && currentTime < (asset.startTime + asset.duration) {
            
            let from = currentTime - asset.startTime
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
