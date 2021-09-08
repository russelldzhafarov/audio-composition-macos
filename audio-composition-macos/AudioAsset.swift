//
//  AudioAsset.swift
//  audio-composition-macos
//
//  Created by russell.dzhafarov@gmail.com on 22.08.2021.
//

import AVFoundation

class AudioAsset: Identifiable, Codable {
    
    enum CodingKeys: String, CodingKey {
        case id
        case trackId
        case url
        case name
        case startTime
    }
    
    var id: UUID
    var trackId: UUID
    var url: URL
    var name: String
    var startTime: TimeInterval
    
    var buffer: AVAudioPCMBuffer?
    var samples: [Float]?
    
    var isSelected = false
    
    init(id: UUID, trackId: UUID, url: URL, startTime: TimeInterval, buffer: AVAudioPCMBuffer? = nil, samples: [Float]? = nil) {
        self.id = id
        self.trackId = trackId
        self.url = url
        self.name = url.lastPathComponent
        self.startTime = startTime
        self.buffer = buffer
        self.samples = samples
    }
    
    required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        trackId = try values.decode(UUID.self, forKey: .trackId)
        url = try values.decode(URL.self, forKey: .url)
        name = try values.decode(String.self, forKey: .name)
        startTime = try values.decode(Double.self, forKey: .startTime)
    }
    
    var timeRange: ClosedRange<TimeInterval> {
        startTime ... (startTime + duration)
    }
    
    var format: AVAudioFormat? {
        buffer?.format
    }
    
    var duration: TimeInterval {
        guard let buffer = buffer else { return .zero }
        return Double(buffer.frameLength) / buffer.format.sampleRate
    }
    
    func power(at time: TimeInterval) -> Float {
        guard let samples = samples else { return .zero }
        
        let sampleRate = Double(samples.count) / duration
        
        let index = Int(time * sampleRate)
        
        guard samples.indices.contains(index) else { return .zero }
        
        let power = samples[index]
        
        let avgPower = 20 * log10(power)
        
        return scaledPower(power: avgPower)
    }
    
    private func scaledPower(power: Float) -> Float {
        guard power.isFinite else {
            return .zero
        }
        
        let minDb: Float = -80
        
        if power < minDb {
            return .zero
        } else if power >= 1.0 {
            return 1.0
        } else {
            return (abs(minDb) - abs(power)) / abs(minDb)
        }
    }
}
