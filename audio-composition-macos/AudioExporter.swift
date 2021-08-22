//
//  AudioExporter.swift
//  audio-composition-macos
//
//  Created by russell.dzhafarov@gmail.com on 22.08.2021.
//

import AVFoundation

class AudioExporter {
    func export(timeline: Timeline, engine: AVAudioEngine, format: AVAudioFormat, settings: [String: Any], fileLength: AVAudioFramePosition, outputURL: URL) {
        
        for track in timeline.tracks {
            engine.attach(track.player)
            engine.connect(track.player,
                           to: engine.mainMixerNode,
                           format: track.format)
            
            track.schedule(at: timeline.currentTime)
        }
        
        do {
            // The maximum number of frames the engine renders in any single render call.
            let maxFrames = AVAudioFrameCount(4096)
            try engine.enableManualRenderingMode(.offline,
                                                 format: format,
                                                 maximumFrameCount: maxFrames)
        } catch {
            fatalError("Enabling manual rendering mode failed: \(error).")
        }
        
        do {
            try engine.start()
            
            timeline.tracks.forEach{ $0.play() }
            
        } catch {
            fatalError("Unable to start audio engine: \(error).")
        }
        
        // The output buffer to which the engine renders the processed data.
        let buffer = AVAudioPCMBuffer(pcmFormat: engine.manualRenderingFormat,
                                      frameCapacity: engine.manualRenderingMaximumFrameCount)!
        
        let outputFile: AVAudioFile
        do {
            outputFile = try AVAudioFile(forWriting: outputURL,
                                         settings: settings)
        } catch {
            fatalError("Unable to open output audio file: \(error).")
        }
        
        while engine.manualRenderingSampleTime < fileLength {
            do {
                let frameCount = fileLength - engine.manualRenderingSampleTime
                let framesToRender = min(AVAudioFrameCount(frameCount), buffer.frameCapacity)
                
                let status = try engine.renderOffline(framesToRender, to: buffer)
                
                switch status {
                case .success:
                    // The data rendered successfully. Write it to the output file.
                    try outputFile.write(from: buffer)
                    
                case .insufficientDataFromInputNode:
                    // Applicable only when using the input node as one of the sources.
                    break
                    
                case .cannotDoInCurrentContext:
                    // The engine couldn't render in the current render call.
                    // Retry in the next iteration.
                    break
                    
                case .error:
                    // An error occurred while rendering the audio.
                    fatalError("The manual rendering failed.")
                }
                
            } catch {
                fatalError("The manual rendering failed: \(error).")
            }
        }
        
        engine.disableManualRenderingMode()
        
        // Stop the player node and engine.
        timeline.tracks.forEach{ $0.stop() }
        engine.stop()
    }
}
