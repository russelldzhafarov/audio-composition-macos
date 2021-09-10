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
        case fileId
        case trackId
        case url
        case name
        case startTime
        case duration
        case samples
        case format
        case buffer
    }
    
    var id: UUID
    var fileId: UUID
    var trackId: UUID
    var url: URL
    var name: String
    var startTime: TimeInterval
    var duration: TimeInterval
    
    var format: AVAudioFormat
    var buffer: AVAudioPCMBuffer
    var samples: [Float]
    
    var isSelected = false
    
    init(id: UUID, fileId: UUID, trackId: UUID, url: URL, startTime: TimeInterval, buffer: AVAudioPCMBuffer, samples: [Float]) {
        self.id = id
        self.fileId = fileId
        self.trackId = trackId
        self.url = url
        self.name = url.lastPathComponent
        self.startTime = startTime
        self.duration = Double(buffer.frameLength) / buffer.format.sampleRate
        self.format = buffer.format
        self.buffer = buffer
        self.samples = samples
    }
    
    required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        fileId = try values.decode(UUID.self, forKey: .fileId)
        trackId = try values.decode(UUID.self, forKey: .trackId)
        url = try values.decode(URL.self, forKey: .url)
        name = try values.decode(String.self, forKey: .name)
        startTime = try values.decode(Double.self, forKey: .startTime)
        duration = try values.decode(Double.self, forKey: .duration)
        samples = try values.decode([Float].self, forKey: .samples)
        
        let formatData = try values.decode(Data.self, forKey: .format)
        format = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(formatData) as! AVAudioFormat
        
        let bufferData = try values.decode(Data.self, forKey: .buffer)
        buffer = bufferData.toPCMBuffer(format: format)!
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(fileId, forKey: .fileId)
        try container.encode(trackId, forKey: .trackId)
        try container.encode(url, forKey: .url)
        try container.encode(name, forKey: .name)
        try container.encode(startTime, forKey: .startTime)
        try container.encode(duration, forKey: .duration)
        try container.encode(samples, forKey: .samples)
        
        let bufferData = Data(buffer: buffer)
        try container.encode(bufferData, forKey: .buffer)
        
        let formatData = try NSKeyedArchiver.archivedData(withRootObject: format, requiringSecureCoding: true)
        try container.encode(formatData, forKey: .format)
    }
    
    var timeRange: ClosedRange<TimeInterval> {
        startTime ... (startTime + duration)
    }
    
    func power(at time: TimeInterval) -> Float {
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
