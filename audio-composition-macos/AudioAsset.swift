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
        case name
        case startTime
        case data
    }
    
    var id: UUID
    var trackId: UUID
    
    var data: Data
    var startTime: TimeInterval
    
    let buffer: AVAudioPCMBuffer
    let amps: [Float]
    
    var isSelected = false
    
    var name: String
    
    init(id: UUID, trackId: UUID, url: URL, startTime: TimeInterval) throws {
        self.id = id
        self.trackId = trackId
        self.name = url.lastPathComponent
        self.startTime = startTime
        self.data = try Data(contentsOf: url)
        guard let aBuffer = try AVAudioPCMBuffer(url: url) else {
            throw Timeline.AppError.read
        }
        self.buffer = aBuffer
        self.amps = aBuffer.compressed()
    }
    
    init(id: UUID, trackId: UUID, name: String, data: Data, startTime: TimeInterval, buffer: AVAudioPCMBuffer, amps: [Float]) {
        self.id = id
        self.trackId = trackId
        self.name = name
        self.data = data
        self.startTime = startTime
        self.buffer = buffer
        self.amps = amps
    }
    
    required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        trackId = try values.decode(UUID.self, forKey: .trackId)
        name = try values.decode(String.self, forKey: .name)
        data = try values.decode(Data.self, forKey: .data)
        startTime = try values.decode(Double.self, forKey: .startTime)
        
        let tempUrl = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try data.write(to: tempUrl)
        guard let aBuffer = try AVAudioPCMBuffer(url: tempUrl) else {
            try FileManager.default.removeItem(at: tempUrl)
            throw Timeline.AppError.read
        }
        
        try FileManager.default.removeItem(at: tempUrl)
        
        self.buffer = aBuffer
        self.amps = aBuffer.compressed()
    }
    
    var timeRange: Range<TimeInterval> {
        (startTime ..< (startTime + duration))
    }
    
    var format: AVAudioFormat {
        buffer.format
    }
    
    var duration: TimeInterval {
        return Double(buffer.frameLength) / buffer.format.sampleRate
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
