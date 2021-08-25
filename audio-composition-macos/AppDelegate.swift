//
//  AppDelegate.swift
//  audio-composition-macos
//
//  Created by russell.dzhafarov@gmail.com on 21.08.2021.
//

import Cocoa
import Accelerate

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        NSApp.appearance = NSAppearance(named: .darkAqua)
    }
}

class GridClipTableView: NSTableView {
    override func drawGrid(inClipRect clipRect: NSRect) {}
}

extension NSImage.Name {
    static let play = NSImage.Name("play.fill")
    static let pause = NSImage.Name("pause.fill")
}

extension NSColor {
    class func random() -> NSColor {
        NSColor(calibratedRed: CGFloat.random(in: 0.6...0.9), green: CGFloat.random(in: 0.6...0.9), blue: CGFloat.random(in: 0.6...0.9), alpha: CGFloat(1))
    }
}

extension Array where Element == Float {
    /// Takes an array of floating point values and down samples it to have a lesser number of samples
    /// Returns an array of downsampled floating point values
    ///
    /// Parameters:
    ///   - sampleCount: the number of samples we will downsample the array to
    func downSample(to sampleCount: Int = 128) -> [Element] {
        let inputSampleCount = self.count
        let inputLength = vDSP_Length(inputSampleCount)

        let filterLength: vDSP_Length = 2
        let filter = [Float](repeating: 1 / Float(filterLength), count: Int(filterLength))

        let decimationFactor = inputSampleCount / sampleCount
        let outputLength = vDSP_Length((inputLength - filterLength) / vDSP_Length(decimationFactor))

        var outputFloats = [Float](repeating: 0, count: Int(outputLength))
        vDSP_desamp(self,
                    decimationFactor,
                    filter,
                    &outputFloats,
                    outputLength,
                    filterLength)
        
        return outputFloats
    }
}

extension NSColor {
    static var windowBackgroundColor: NSColor {
        NSColor(red: 39.0/255.0, green: 42.0/255.0, blue: 54.0/255.0, alpha: 1.0)
    }
    static var channelsBackgroundColor: NSColor {
        NSColor(red: 30.0/255.0, green: 31.0/255.0, blue: 40.0/255.0, alpha: 1.0)
    }
    static var channelBackgroundColor: NSColor {
        NSColor(red: 39.0/255.0, green: 42.0/255.0, blue: 54.0/255.0, alpha: 1.0)
    }
    static var timelineBackgroundColor: NSColor {
        NSColor(red: 30.0/255.0, green: 31.0/255.0, blue: 40.0/255.0, alpha: 1.0)
    }
    static var timelineTrackBackgroundColor: NSColor {
        NSColor(red: 39.0/255.0, green: 42.0/255.0, blue: 54.0/255.0, alpha: 1.0).withAlphaComponent(0.5)
    }
    static var timelineWaveColor: NSColor {
        NSColor(red: 178.0/255.0, green: 199.0/255.0, blue: 233.0/255.0, alpha: 1.0)
    }
    static var timelineWaveBackgroundColor: NSColor {
        NSColor(red: 65.0/255.0, green: 115.0/255.0, blue: 167.0/255.0, alpha: 1.0)
    }
    static var timelineCursorColor: NSColor {
        NSColor.systemRed
    }
    static var selectionColor: NSColor {
        NSColor.keyboardFocusIndicatorColor.withAlphaComponent(0.3)
    }
    static var highlightColor: NSColor {
        NSColor.keyboardFocusIndicatorColor.withAlphaComponent(0.2)
    }
    static var rulerColor: NSColor {
        NSColor(red: 83.0/255.0, green: 89.0/255.0, blue: 105.0/255.0, alpha: 1.0)
    }
    static var rulerLabelColor: NSColor {
        NSColor(red: 142.0/255.0, green: 150.0/255.0, blue: 171.0/255.0, alpha: 1.0)
    }
}

extension Double {
    func floor(nearest: Double) -> Double {
        let intDiv = Double(Int(self / nearest))
        return intDiv * nearest
    }
    func round(nearest: Double) -> Double {
        let n = 1/nearest
        let numberToRound = self * n
        return numberToRound.rounded() / n
    }
}

extension TimeInterval {
    func mmss() -> String {
        let m: Int = Int(self) / 60
        let s: Int = Int(self) % 60
        return String(format: "%0d:%02d", m, s)
    }
    func mmssms() -> String {
        let m: Int = Int(self) / 60
        let s: Int = Int(self) % 60
        let ms: Int = Int((truncatingRemainder(dividingBy: 1)) * 1000)
        return String(format: "%0d:%02d,%02d", m, s, ms/10)
    }
    func hhmmssms() -> String {
        let h: Int = Int(self / 3600)
        let m: Int = Int(self) / 60
        let s: Int = Int(self) % 60
        let ms: Int = Int((truncatingRemainder(dividingBy: 1)) * 1000)
        return String(format: "%02d:%02d:%02d.%02d", h, m, s, ms)
    }
}

extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        return min(max(self, limits.lowerBound), limits.upperBound)
    }
}
