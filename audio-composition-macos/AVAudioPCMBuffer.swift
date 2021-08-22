//
//  AVAudioPCMBuffer.swift
//  audio-composition-macos
//
//  Created by russell.dzhafarov@gmail.com on 22.08.2021.
//

import AVFoundation
import Accelerate

extension AVAudioPCMBuffer {
    // Read the contents of the url into this buffer
    convenience init?(url: URL) throws {
        guard let file = try? AVAudioFile(forReading: url) else { return nil }
        try self.init(file: file)
    }
    
    // Read entire file and return a new AVAudioPCMBuffer with its contents
    convenience init?(file: AVAudioFile) throws {
        file.framePosition = 0
        
        self.init(pcmFormat: file.processingFormat,
                  frameCapacity: AVAudioFrameCount(file.length))
        
        try file.read(into: self)
    }
}

extension AVAudioPCMBuffer {
    func compressed(_ compression: Int = 1000) -> [Float] {
        let inputSignal = Array(UnsafeBufferPointer(start: self.floatChannelData?[0],
                                                    count: Int(self.frameLength)))
        
        var processingBuffer = [Float](repeating: 0.0,
                                       count: Int(inputSignal.count))
        
        vDSP_vabs(inputSignal,
                  1,
                  &processingBuffer,
                  1,
                  vDSP_Length(inputSignal.count))
        
        let filter = [Float](repeating: 1.0 / Float(compression),
                             count: Int(compression))
        
        let downSampledLength = inputSignal.count / compression
        
        var downSampledData = [Float](repeating: 0.0,
                                      count: downSampledLength)
        
        vDSP_desamp(processingBuffer,
                    vDSP_Stride(compression),
                    filter,
                    &downSampledData,
                    vDSP_Length(downSampledLength),
                    vDSP_Length(compression))
        
        return downSampledData
    }
}

extension AVAudioPCMBuffer {
    /// Copies data from another PCM buffer.  Will copy to the end of the buffer (frameLength), and
    /// increment frameLength. Will not exceed frameCapacity.
    ///
    /// - Parameter buffer: The source buffer that data will be copied from.
    /// - Parameter readOffset: The offset into the source buffer to read from.
    /// - Parameter frames: The number of frames to copy from the source buffer.
    /// - Returns: The number of frames copied.
    @discardableResult public func copy(from buffer: AVAudioPCMBuffer,
                                        readOffset: AVAudioFrameCount = 0,
                                        frames: AVAudioFrameCount = 0) -> AVAudioFrameCount {
        let remainingCapacity = frameCapacity - frameLength
        if remainingCapacity == 0 {
            print("AVAudioBuffer copy(from) - no capacity!")
            return 0
        }

        if format != buffer.format {
            print("AVAudioBuffer copy(from) - formats must match!")
            return 0
        }

        let totalFrames = Int(min(min(frames == 0 ? buffer.frameLength : frames, remainingCapacity),
                                  buffer.frameLength - readOffset))

        if totalFrames <= 0 {
            print("AVAudioBuffer copy(from) - No frames to copy!")
            return 0
        }
        
        let frameSize = Int(format.streamDescription.pointee.mBytesPerFrame)
        if let src = buffer.floatChannelData,
           let dst = floatChannelData {
            for channel in 0 ..< Int(format.channelCount) {
                memcpy(dst[channel] + Int(frameLength), src[channel] + Int(readOffset), totalFrames * frameSize)
            }
        } else if let src = buffer.int16ChannelData,
                  let dst = int16ChannelData {
            for channel in 0 ..< Int(format.channelCount) {
                memcpy(dst[channel] + Int(frameLength), src[channel] + Int(readOffset), totalFrames * frameSize)
            }
        } else if let src = buffer.int32ChannelData,
                  let dst = int32ChannelData {
            for channel in 0 ..< Int(format.channelCount) {
                memcpy(dst[channel] + Int(frameLength), src[channel] + Int(readOffset), totalFrames * frameSize)
            }
        } else {
            return 0
        }
        frameLength += AVAudioFrameCount(totalFrames)
        return AVAudioFrameCount(totalFrames)
    }

    /// Copy from a certain point tp the end of the buffer
    /// - Parameter startSample: Point to start copy from
    /// - Returns: an AVAudioPCMBuffer copied from a sample offset to the end of the buffer.
    public func copyFrom(startSample: AVAudioFrameCount) -> AVAudioPCMBuffer? {
        guard startSample < frameLength,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameLength - startSample) else {
            return nil
        }
        let framesCopied = buffer.copy(from: self, readOffset: startSample)
        return framesCopied > 0 ? buffer : nil
    }

    /// Copy from the beginner of a buffer to a certain number of frames
    /// - Parameter count: Length of frames to copy
    /// - Returns: an AVAudioPCMBuffer copied from the start of the buffer to the specified endSample.
    public func copyTo(count: AVAudioFrameCount) -> AVAudioPCMBuffer? {
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: count) else {
            return nil
        }
        let framesCopied = buffer.copy(from: self, readOffset: 0, frames: min(count, frameLength))
        return framesCopied > 0 ? buffer : nil
    }

    /// Extract a portion of the buffer
    ///
    /// - Parameter startTime: The time of the in point of the extraction
    /// - Parameter endTime: The time of the out point
    /// - Returns: A new edited AVAudioPCMBuffer
    public func extract(from startTime: TimeInterval,
                        to endTime: TimeInterval) -> AVAudioPCMBuffer? {
        let sampleRate = format.sampleRate
        let startSample = AVAudioFrameCount(startTime * sampleRate)
        var endSample = AVAudioFrameCount(endTime * sampleRate)

        if endSample == 0 {
            endSample = frameLength
        }

        let frameCapacity = endSample - startSample

        guard frameCapacity > 0 else {
            print("startSample must be before endSample")
            return nil
        }

        guard let editedBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCapacity) else {
            print("Failed to create edited buffer")
            return nil
        }

        guard editedBuffer.copy(from: self, readOffset: startSample, frames: frameCapacity) > 0 else {
            print("Failed to write to edited buffer")
            return nil
        }
        
        return editedBuffer
    }
}
