//
//  Timeline.swift
//  audio-composition-macos
//
//  Created by russell.dzhafarov@gmail.com on 21.08.2021.
//

import AVFoundation
import Combine

class Timeline: ObservableObject {
    
    let trackHeight = CGFloat(60)
    
    static let acceptableUTITypes = [
        "public.mp3",
        "com.apple.m4a-audio",
        "com.microsoft.waveform-audio"
    ]
    
    enum State: String {
        case processing = "Processing...", ready = "Ready"
    }
    enum AppError: Error {
        case read
    }
    enum PlayerState {
        case stopped, playing
    }
    
    private let audioEngine = AVAudioEngine()
    private let audioExporter = AudioExporter()
    
    @Published var tracks: [AudioTrack] = []
    @Published var visibleTimeRange: Range<TimeInterval> = 0.0 ..< 60.0
    @Published var selectedTimeRange: Range<TimeInterval>?
    @Published var currentTime: TimeInterval = 0.0
    @Published var highlighted = false
    @Published var state: State = .ready
    @Published var playerState: PlayerState = .stopped
    @Published var error: Error?
    @Published var needsDisplay = false
    
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
    
    func mute(track: AudioTrack) {
        let wasPlaying = playerState == .playing
        if wasPlaying {
            stop()
        }
        
        track.isMuted.toggle()
        track.soloEnabled = false
        needsDisplay = true
        
        if wasPlaying {
            play()
        }
    }
    func solo(track: AudioTrack) {
        let wasPlaying = playerState == .playing
        if wasPlaying {
            stop()
        }
        
        let isOn = !track.soloEnabled
        tracks.forEach{ $0.soloEnabled = false }
        tracks.forEach{ $0.isMuted = isOn }
        
        track.soloEnabled = isOn
        track.isMuted = false
        
        needsDisplay = true
        
        if wasPlaying {
            play()
        }
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
        seek(to: duration - TimeInterval(60))
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
        
        serviceQueue.addOperation { [weak self] in
            guard let strongSelf = self else { return }
            defer {
                strongSelf.state = .ready
            }
            do {
                guard let asset = try AudioAsset(url: url, startTime: .zero) else {
                    throw AppError.read
                }
                strongSelf.tracks.append(AudioTrack(name: "Channel # \(strongSelf.tracks.count + 1)",
                                                    asset: asset))
                
            } catch {
                strongSelf.error = error
            }
        }
    }
    
    func export(to url: URL) {
        let format = audioEngine.mainMixerNode.outputFormat(forBus: AVAudioNodeBus(0))
        var settings = format.settings
        settings[AVFormatIDKey] = kAudioFormatMPEG4AAC
        let fileLength = AVAudioFramePosition((duration - TimeInterval(60)) * format.sampleRate)
        
        state = .processing
        serviceQueue.addOperation { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.audioExporter.export(timeline: strongSelf,
                                            engine: strongSelf.audioEngine,
                                            format: format,
                                            settings: settings,
                                            fileLength: fileLength,
                                            outputURL: url)
            strongSelf.state = .ready
        }
    }
}
