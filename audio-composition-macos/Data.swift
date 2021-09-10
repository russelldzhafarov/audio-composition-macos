//
//  Data.swift
//  audio-composition-macos
//
//  Created by russell.dzhafarov@gmail.com on 10.09.2021.
//

import AVFoundation

extension Data {
    init(buffer: AVAudioPCMBuffer) {
        let audioBuffer = buffer.audioBufferList.pointee.mBuffers
        self.init(bytes: audioBuffer.mData!, count: Int(audioBuffer.mDataByteSize))
    }
    
    func toPCMBuffer(format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let streamDesc = format.streamDescription.pointee
        let frameCapacity = UInt32(count) / streamDesc.mBytesPerFrame
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCapacity) else { return nil }
        
        buffer.frameLength = buffer.frameCapacity
        let audioBuffer = buffer.audioBufferList.pointee.mBuffers
        
        withUnsafeBytes { (bufferPointer) in
            guard let addr = bufferPointer.baseAddress else { return }
            audioBuffer.mData?.copyMemory(from: addr, byteCount: Int(audioBuffer.mDataByteSize))
        }
        
        return buffer
    }
}
