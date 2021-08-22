//
//  Timeline.swift
//  audio-composition-macos
//
//  Created by russell.dzhafarov@gmail.com on 21.08.2021.
//

import AVFoundation
import Combine

class Timeline: ObservableObject {
    
    let trackHeight = CGFloat(50)
    
    var acceptableUTITypes: [String] {
        ["public.mp3", "com.apple.m4a-audio", "com.microsoft.waveform-audio"]
    }
    enum State {
        case processing, ready
    }
    enum AppError: Error {
        case read
    }
    enum PlayerState {
        case stopped, playing
    }
    
    private let audioEngine = AVAudioEngine()
    
    @Published var tracks: [AudioTrack] = []
    @Published var visibleTimeRange: Range<TimeInterval> = 0.0 ..< 60.0
    @Published var selectedTimeRange: Range<TimeInterval>?
    @Published var currentTime: TimeInterval = 0.0
    @Published var highlighted = false
    @Published var state: State = .ready
    @Published var playerState: PlayerState = .stopped
    @Published var error: Error?
    
    var visibleDur: TimeInterval {
        visibleTimeRange.upperBound - visibleTimeRange.lowerBound
    }
    
    var duration: TimeInterval {
        (tracks.map{ $0.duration }.max() ?? TimeInterval(0)) + TimeInterval(60)
    }
    
    var isEmpty: Bool {
        tracks.isEmpty
    }
    
    private let serviceQueue: OperationQueue = {
        let q = OperationQueue()
        q.maxConcurrentOperationCount = 1
        return q
    }()
    
    private var timer: Timer?
    
    deinit {
        timer?.invalidate()
        timer = nil
    }
    
    func seek(to time: TimeInterval) {
        let wasPlaying = playerState == .playing
        if wasPlaying {
            stop()
        }
        currentTime = time.clamped(to: 0.0...duration)
        if wasPlaying {
            play()
        }
    }
    func play() {
        switch playerState {
        case .playing:
            stop()
            
        case .stopped:
            do {
                for track in tracks {
                    audioEngine.attach(track.player)
                    audioEngine.connect(track.player,
                                        to: audioEngine.mainMixerNode,
                                        format: track.format)
                    
                    track.schedule(at: currentTime)
                }
                
                if !audioEngine.isRunning {
                    _=audioEngine.outputNode
                    try audioEngine.start()
                }
                
                tracks.forEach{ $0.play() }
                
                playerState = .playing
                
                let seekTime = currentTime
                // Installs an audio tap on the bus to record, monitor, and observe the output of the node.
                audioEngine.mainMixerNode.installTap(onBus: 0, bufferSize: 4096, format: nil) { [weak self] _, time in
                    let currentPosition = Double(time.sampleTime) / time.sampleRate
                    self?.currentTime = seekTime + currentPosition
                }
                
            } catch {
                self.error = error
            }
        }
    }
    func stop() {
        tracks.forEach{ $0.stop() }
        audioEngine.mainMixerNode.removeTap(onBus: 0)
        audioEngine.stop()
        playerState = .stopped
    }
    func forward() {
        selectedTimeRange = nil
        seek(to: currentTime + TimeInterval(15))
    }
    func forwardEnd() {
        selectedTimeRange = nil
        seek(to: duration)
    }
    func backward() {
        selectedTimeRange = nil
        seek(to: currentTime - TimeInterval(15))
    }
    func backwardEnd() {
        selectedTimeRange = nil
        seek(to: TimeInterval(0))
    }
    
    func importFile(at url: URL) {
        state = .processing
        
        serviceQueue.addOperation {
            defer {
                self.state = .ready
            }
            do {
                guard let buffer = try AVAudioPCMBuffer(url: url) else {
                    throw AppError.read
                }
                
                let amps = buffer.compressed()
                
                self.tracks.append(AudioTrack(name: "Track",
                                              asset: AudioAsset(buffer: buffer, amps: amps)))
                
            } catch {
                self.error = error
            }
        }
    }
    
    func export() {
        
    }
}
