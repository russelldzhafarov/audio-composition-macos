//
//  TimelineView.swift
//  audio-composition-macos
//
//  Created by russell.dzhafarov@gmail.com on 21.08.2021.
//

import Cocoa

class TimelineView: NSView {
    
    var timeline: Timeline? {
        (window?.windowController?.document as? Document)?.timeline
    }
    
    override var isFlipped: Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let timeline = timeline,
              let ctx = NSGraphicsContext.current?.cgContext else { return }
        
        // Draw background color
        ctx.setFillColor(NSColor.timelineBackgroundColor.cgColor)
        ctx.fill(dirtyRect)
        
        // Draw top horizontal line
        ctx.move(to: CGPoint(x: dirtyRect.minX,
                             y: .zero))
        ctx.addLine(to: CGPoint(x: dirtyRect.maxX,
                                y: .zero))
        ctx.setStrokeColor(NSColor.rulerColor.cgColor)
        ctx.strokePath()
        
        // Draw tracks
        var y: CGFloat = .zero
        for track in timeline.tracks {
            // Draw waveform
            drawWaveform(asset: track.asset, timeline: timeline, origin: CGPoint(x: .zero, y: y), color: NSColor.timelineWaveColor.cgColor, to: ctx)
            
            // Draw horizontal separator
            ctx.move(to: CGPoint(x: dirtyRect.minX,
                                 y: y))
            ctx.addLine(to: CGPoint(x: dirtyRect.maxX,
                                    y: y))
            ctx.setStrokeColor(NSColor.windowBackgroundColor.cgColor)
            ctx.setLineWidth(CGFloat(2))
            ctx.strokePath()
            
            y += timeline.trackHeight
        }
        
        // Draw hint string
        drawString(s: NSString(string: "+ Drop audio files here"),
                   withFont: NSFont.systemFont(ofSize: 16),
                   color: NSColor.rulerColor,
                   alignment: .center,
                   inRect: CGRect(x: 0.0,
                                  y: timeline.trackHeight * CGFloat(timeline.tracks.count),
                                  width: dirtyRect.width,
                                  height: timeline.trackHeight))
    }
    
    func drawWaveform(asset: AudioAsset, timeline: Timeline, origin: CGPoint, color: CGColor, to ctx: CGContext) {
        
        // Draw track background
        ctx.setFillColor(NSColor.timelineTrackBackgroundColor.cgColor)
        ctx.fill(CGRect(x: origin.x, y: origin.y, width: bounds.width, height: timeline.trackHeight))
        
        let timeRange = (asset.startTime ..< (asset.startTime + asset.duration)).clamped(to: timeline.visibleTimeRange.lowerBound..<timeline.visibleTimeRange.upperBound)
        
        guard !timeRange.isEmpty else { return }
        
        let visibleDur = timeline.visibleDur
        let oneSecWidth = bounds.width / CGFloat(visibleDur)
        
        // Draw asset visible rect
        let frame = CGRect(x: CGFloat(timeRange.lowerBound - timeline.visibleTimeRange.lowerBound) * oneSecWidth,
                           y: origin.y,
                           width: CGFloat(timeRange.upperBound - timeRange.lowerBound) * oneSecWidth,
                           height: timeline.trackHeight)
        
        ctx.setFillColor(NSColor.timelineWaveBackgroundColor.cgColor)
        ctx.fill(frame)
        
        
        let stepInPx = CGFloat(1)
        
        let koeff = bounds.width / stepInPx
        let stepInSec = visibleDur / Double(koeff)
        
        let startTime = timeRange.lowerBound - asset.startTime
        let endTime = timeRange.upperBound - asset.startTime
        
        var x = frame.origin.x
        for time in stride(from: startTime, to: endTime, by: stepInSec) {
            let power = asset.power(at: time)
            
            let heigth = max(CGFloat(1),
                             CGFloat(power) * (frame.height/2))
            
            ctx.move(to: CGPoint(x: x,
                                 y: frame.midY + heigth))
            
            ctx.addLine(to: CGPoint(x: x,
                                    y: frame.midY - heigth))
            
            x += stepInPx
        }
        
        ctx.setLineWidth(CGFloat(1))
        ctx.setStrokeColor(color)
        ctx.strokePath()
    }
    
    func drawString(s: NSString, withFont font: NSFont, color: NSColor, alignment: NSTextAlignment, inRect contextRect: CGRect) {
        
        let fontHeight = font.pointSize
        let yOffset = (contextRect.size.height - fontHeight) / CGFloat(2)
        
        let textRect = CGRect(x: contextRect.origin.x,
                              y: contextRect.origin.y + yOffset,
                              width: contextRect.size.width,
                              height: fontHeight)
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = alignment
        
        let attributes: [NSAttributedString.Key : Any] = [
            .foregroundColor: color,
            .font: font,
            .paragraphStyle: paragraphStyle
        ]
        
        s.draw(in: textRect, withAttributes: attributes)
    }
}
