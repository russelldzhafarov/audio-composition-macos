//
//  NSColor.swift
//  audio-composition-macos
//
//  Created by russell.dzhafarov@gmail.com on 07.09.2021.
//

import Cocoa

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
        NSColor.systemTeal.withAlphaComponent(0.5)
    }
    static var timelineWaveBorderColor: NSColor {
        NSColor.systemTeal.withAlphaComponent(0.8)
    }
    static var timelineCursorColor: NSColor {
        NSColor.systemRed
    }
    static var selectionStrokeColor: NSColor {
        NSColor.systemTeal.withAlphaComponent(0.8)
    }
    static var selectionFillColor: NSColor {
        NSColor.systemTeal.withAlphaComponent(0.7)
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
