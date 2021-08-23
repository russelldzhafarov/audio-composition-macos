//
//  AudioAsset.swift
//  audio-composition-macos
//
//  Created by russell.dzhafarov@gmail.com on 22.08.2021.
//

import AVFoundation

class AudioAsset: Identifiable, Codable {
    
    enum CodingKeys: String, CodingKey {
        case url
        case startTime
    }
    
    let id = UUID()
    
    var url: URL
    var startTime: TimeInterval
    let buffer: AVAudioPCMBuffer
    let amps: [Float]
    
    var isSelected = false
    
    var name: String {
        url.lastPathComponent
    }
    
    init?(url: URL, startTime: TimeInterval) throws {
        self.url = url
        self.startTime = startTime
        guard let buffer = try AVAudioPCMBuffer(url: url) else { return nil }
        self.buffer = buffer
        self.amps = buffer.compressed()
    }
    
    required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        url = try values.decode(URL.self, forKey: .url)
        startTime = try values.decode(Double.self, forKey: .startTime)
        
        self.buffer = try AVAudioPCMBuffer(url: url)!
        self.amps = buffer.compressed()
    }
    
    var format: AVAudioFormat {
        buffer.format
    }
    
    var duration: TimeInterval {
        Double(buffer.frameLength) / buffer.format.sampleRate
    }
    
    func power(at time: TimeInterval) -> Float {
        let sampleRate = Double(amps.count) / duration
        
        let index = Int(time * sampleRate)
        
        guard amps.indices.contains(index) else { return .zero }
        
        let power = amps[index]
        
        let avgPower = 20 * log10(power)
        
        return scaledPower(power: avgPower)
    }
    
    private func scaledPower(power: Float) -> Float {
        guard power.isFinite else {
            return 0.0
        }
        
        let minDb: Float = -80
        
        if power < minDb {
            return 0.0
        } else if power >= 1.0 {
            return 1.0
        } else {
            return (abs(minDb) - abs(power)) / abs(minDb)
        }
    }
}
