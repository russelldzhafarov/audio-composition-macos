//
//  AudioAsset.swift
//  audio-composition-macos
//
//  Created by russell.dzhafarov@gmail.com on 22.08.2021.
//

import AVFoundation

class TimelineItem: Identifiable {
    let id = UUID()
    var timeRange: CMTimeRange
    var startTime: CMTime
    
    init() {
        self.timeRange = .invalid
        self.startTime = .zero
    }
}

class AudioAsset: TimelineItem {
    let buffer: AVAudioPCMBuffer
    let amps: [Float]
    
    init(buffer: AVAudioPCMBuffer, amps: [Float]) {
        self.buffer = buffer
        self.amps = amps
        super.init()
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
