//
//  Timeline.swift
//  audio-composition-macos
//
//  Created by russell.dzhafarov@gmail.com on 21.08.2021.
//

import AVFoundation
import Cocoa
import Combine

class Timeline: ObservableObject {
    
    let trackHeight = CGFloat(60)
    
    static let acceptableUTITypes = [
        AVFileType.mp3.rawValue,
        AVFileType.m4a.rawValue,
        AVFileType.wav.rawValue
    ]
    
    enum State: String {
        case processing = "Processing...", ready = "Ready"
    }
    enum PlayerState {
        case stopped, playing
    }
    
    private let audioEngine = AVAudioEngine()
    private let audioExporter = AudioExporter()
    
    @Published var tracks: [AudioTrack] = []
    @Published var visibleTimeRange: ClosedRange<TimeInterval> = .zero ... 60.0
    @Published var selectedTimeRange: ClosedRange<TimeInterval>?
    @Published var currentTime: TimeInterval = .zero
    @Published var highlighted = false
    @Published var state: State = .ready
    @Published var playerState: PlayerState = .stopped
    @Published var error: Error?
    @Published var needsDisplay = false
    
    var undoManager: UndoManager?
    
    init(tracks: [AudioTrack], undoManager: UndoManager?) {
        self.tracks = tracks
        self.undoManager = undoManager
    }
    
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
    
    func time(at loc: NSPoint, width: CGFloat) -> TimeInterval {
        visibleTimeRange.lowerBound + (visibleDur * Double(loc.x) / Double(width))
    }
    
    func loc(at time: TimeInterval, width: CGFloat) -> CGFloat {
        let oneSecWidth = width / CGFloat(visibleDur)
        return CGFloat((time - visibleTimeRange.lowerBound)) * oneSecWidth
    }
    
    func cut() {
        copy()
        delete()
    }
    func copy() {
        var assets: [AudioAsset] = []
        for track in tracks {
            for asset in track.assets {
                if asset.isSelected { assets.append(asset) }
            }
        }
        guard !assets.isEmpty else { return }
        
        do {
            let codedData = try JSONEncoder().encode(assets)
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.declareTypes([.audioAsset], owner: nil)
            pasteboard.setData(codedData, forType: .audioAsset)
            
        } catch {
            self.error = error
        }
    }
    func paste() {
        let pasteboard = NSPasteboard.general
        guard let type = pasteboard.availableType(from: [.audioAsset]),
              type == .audioAsset,
              let data = pasteboard.data(forType: .audioAsset) else { return }
        
        do {
            let assets = try JSONDecoder().decode([AudioAsset].self, from: data)
            
            insertAssets(assets)
            
            needsDisplay = true
            
            if playerState == .playing {
                stop()
                play()
            }
            
        } catch {
            self.error = error
        }
    }
    func delete() {
        var assets: [AudioAsset] = []
        for track in tracks {
            for asset in track.assets {
                if asset.isSelected { assets.append(asset) }
            }
        }
        guard !assets.isEmpty else { return }
        
        removeAssets(assets)
        
        needsDisplay = true
        
        if playerState == .playing {
            stop()
            play()
        }
    }
    
    func addTrack(_ track: AudioTrack) {
        undoManager?.registerUndo(withTarget: self) { target in
            target.removeTrack(track)
        }
        
        // Mute track if solo enabled in another channel
        track.isMuted = !tracks.filter{ $0.soloEnabled }.isEmpty
        
        tracks.append(track)
    }
    
    func addNewTrack() {
        addTrack(AudioTrack(id: UUID(), name: "Channel # \(tracks.count + 1)", assets: []))
    }
    func removeTrack(_ track: AudioTrack) {
        undoManager?.registerUndo(withTarget: self) { target in
            target.addTrack(track)
        }
        
        tracks.removeAll(where: { $0.id == track.id })
        
        if playerState == .playing {
            stop()
            play()
        }
    }
    func insertAssets(_ assets: [AudioAsset]) {
        let updated = assets.compactMap{ AudioAsset(id: UUID(), fileId: $0.fileId, trackId: $0.trackId, url: $0.url, startTime: $0.startTime, buffer: $0.buffer, samples: $0.samples) }
        undoManager?.registerUndo(withTarget: self) { target in
            target.removeAssets(updated)
        }
        
        for asset in updated {
            if let track = tracks.first(where: { $0.id == asset.trackId }) {
                track.assets.append(asset)
                
                for trackAsset in track.assets {
                    if trackAsset.id == asset.id { continue }
                }
            }
        }
        
        needsDisplay = true
    }
    
    func removeAssets(_ assets: [AudioAsset]) {
        undoManager?.registerUndo(withTarget: self) { target in
            target.insertAssets(assets)
        }
        
        for asset in assets {
            if let track = tracks.first(where: { $0.id == asset.trackId }) {
                track.assets.removeAll(where: { $0.id == asset.id })
            }
        }
        
        needsDisplay = true
    }
    
    func removeAsset(_ asset: AudioAsset) {
        guard let track = tracks.first(where: { $0.id == asset.trackId }) else { return }
        track.assets.removeAll(where: { $0.id == asset.id })
        
        needsDisplay = true
        
        if playerState == .playing {
            stop()
            play()
        }
    }
    
    func move(asset: AudioAsset, to track: AudioTrack) {
        let wasPlaying = playerState == .playing
        if wasPlaying {
            stop()
        }
        
        // Remove asset from prev track
        removeAsset(asset)
        
        // Assign asset to new track
        asset.trackId = track.id
        track.assets.append(asset)
        
        if wasPlaying {
            play()
        }
    }
    
    func track(at point: NSPoint) -> AudioTrack? {
        var idx = Int(floor(point.y / trackHeight))
        guard tracks.indices.contains(idx) else { return nil }
        return tracks[idx]
    }
    
    func mute(track: AudioTrack) {
        let wasPlaying = playerState == .playing
        if wasPlaying {
            stop()
        }
        
        tracks.forEach{ $0.soloEnabled = false }
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
    
    func importFile(at url: URL, startTime: TimeInterval, to track: AudioTrack?) {
        state = .processing
        
        serviceQueue.addOperation { [weak self] in
            guard let strongSelf = self else { return }
            defer {
                strongSelf.state = .ready
            }
            
            guard let buffer = try? AVAudioPCMBuffer(url: url) else {
                self?.error = AVError(.unknown)
                return
            }
            
            let samples = buffer.compressed()
            
            let fileId = UUID()
            
            if let track = track {
                let asset = AudioAsset(id: UUID(), fileId: fileId, trackId: track.id, url: url, startTime: startTime, buffer: buffer, samples: samples)
                
                strongSelf.insertAssets([asset])
                
            } else {
                let asset = AudioAsset(id: UUID(), fileId: fileId, trackId: UUID(), url: url, startTime: startTime, buffer: buffer, samples: samples)
                
                let aTrack = AudioTrack(id: UUID(),
                                        name: "Channel # \(strongSelf.tracks.count + 1)",
                                        assets: [asset])
                // Mute track if solo enabled in another channel
                aTrack.isMuted = !strongSelf.tracks.filter{ $0.soloEnabled }.isEmpty
                
                strongSelf.addTrack(aTrack)
                
                strongSelf.insertAssets([asset])
            }
        }
    }
    
    func export(to url: URL) {
        let format = audioEngine.mainMixerNode.outputFormat(forBus: AVAudioNodeBus(0))
        var settings = format.settings
        settings[AVFormatIDKey] = kAudioFormatMPEG4AAC
        let fileLength = AVAudioFramePosition((duration - 60.0) * format.sampleRate)
        
        state = .processing
        serviceQueue.addOperation { [weak self] in
            guard let strongSelf = self else { return }
            do {
                try strongSelf.audioExporter.export(timeline: strongSelf,
                                                engine: strongSelf.audioEngine,
                                                format: format,
                                                settings: settings,
                                                fileLength: fileLength,
                                                outputURL: url)
            } catch {
                strongSelf.error = error
            }
            
            strongSelf.state = .ready
        }
    }
}
