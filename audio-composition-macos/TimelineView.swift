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
        
        ctx.setFillColor(NSColor.timelineBackgroundColor.cgColor)
        ctx.fill(dirtyRect)
        
        ctx.move(to: CGPoint(x: dirtyRect.minX,
                             y: .zero))
        ctx.addLine(to: CGPoint(x: dirtyRect.maxX,
                                y: .zero))
        
        ctx.setStrokeColor(NSColor.rulerColor.cgColor)
        ctx.strokePath()
        
        let visibleDur = timeline.visibleDur
        let oneSecWidth = dirtyRect.width / CGFloat(visibleDur)
        
        var y: CGFloat = timeline.trackHeight
        for track in timeline.tracks {
            
            ctx.setFillColor(NSColor.timelineTrackBackgroundColor.cgColor)
            ctx.fill(CGRect(x: .zero, y: y - timeline.trackHeight, width: bounds.width, height: timeline.trackHeight))
            
            // Fill asset rect in timeline
            let frame = CGRect(x: CGFloat(track.asset.startTime.seconds - timeline.visibleTimeRange.lowerBound) * oneSecWidth,
                               y: y - timeline.trackHeight,
                               width: CGFloat(track.asset.duration) * oneSecWidth,
                               height: timeline.trackHeight)
            
            ctx.setFillColor(NSColor.timelineWaveBackgroundColor.cgColor)
            ctx.fill(frame)
            
            drawWaveform(asset: track.asset, timeline: timeline, in: frame, color: NSColor.timelineWaveColor.cgColor, to: ctx)
            
            // Draw separator
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
                   withFont: NSFont.systemFont(ofSize: 15),
                   color: NSColor.rulerColor,
                   alignment: .center,
                   inRect: CGRect(x: 0.0,
                                  y: timeline.trackHeight * CGFloat(timeline.tracks.count),
                                  width: dirtyRect.width,
                                  height: timeline.trackHeight))
    }
    
    func drawWaveform(asset: AudioAsset, timeline: Timeline, in frame: CGRect, color: CGColor, to ctx: CGContext) {
        let startTime = timeline.visibleTimeRange.lowerBound
        let endTime = timeline.visibleTimeRange.upperBound
        
        let duration = timeline.visibleDur
        
        let lineWidth = CGFloat(1)
        let stepInPx = CGFloat(1)
        
        let koeff = frame.width / stepInPx
        let stepInSec = duration / Double(koeff)
        
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
        
        ctx.setLineWidth(lineWidth)
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
