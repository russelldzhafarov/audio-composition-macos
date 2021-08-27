//
//  AudioTrack.swift
//  audio-composition-macos
//
//  Created by russell.dzhafarov@gmail.com on 22.08.2021.
//

import AVFoundation
import Cocoa

class AudioTrack: NSObject, Identifiable, Codable {
    
    enum CodingKeys: String, CodingKey {
        case name
        case assets
    }
    
    let id = UUID()
    @objc var name: String
    var assets: [AudioAsset]
    
    init(name: String, assets: [AudioAsset]) {
        self.name = name
        self.assets = assets
        super.init()
    }
    
    required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        name = try values.decode(String.self, forKey: .name)
        assets = try values.decode([AudioAsset].self, forKey: .assets)
        super.init()
    }
    
    var format: AVAudioFormat? {
        return nil
    }
    
    var duration: TimeInterval {
        assets.map{ $0.startTime + $0.duration }.max() ?? .zero
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
    @objc dynamic var soloEnabled: Bool = false
    @objc dynamic var isMuted: Bool = false {
        didSet {
            player.volume = isMuted ? 0.0 : volume
        }
    }
    
    let player = AVAudioPlayerNode()
    
    public func schedule(at currentTime: TimeInterval) {
        guard !isMuted else { return }
        for asset in assets {
            guard currentTime < (asset.startTime + asset.duration) else {continue}
            
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
