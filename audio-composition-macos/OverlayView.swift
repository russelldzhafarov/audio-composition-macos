//
//  OverlayView.swift
//  audio-composition-macos
//
//  Created by russell.dzhafarov@gmail.com on 21.08.2021.
//

import Cocoa

class OverlayView: NSView {

    var timeline: Timeline? {
        (window?.windowController?.document as? Document)?.timeline
    }
    
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }
    
    // MARK: - Events
    override func magnify(with event: NSEvent) {
        guard let timeline = timeline else { return }
        
        let scale = CGFloat(1) + event.magnification
        
        let duration = timeline.visibleDur
        let newDuration = duration / Double(scale)
        
        let loc = convert(event.locationInWindow, from: nil)
        let time = timeline.visibleTimeRange.lowerBound + (duration * Double(loc.x) / Double(bounds.width))
        
        let startTime = time - ((time - timeline.visibleTimeRange.lowerBound) / Double(scale))
        let endTime = startTime + newDuration
        
        guard startTime < endTime else { return }
        
        timeline.visibleTimeRange = (startTime ... endTime).clamped(to: .zero ... timeline.duration)
    }
    
    // MARK: - Drawing
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Drawing code here.
        guard let timeline = timeline,
              let ctx = NSGraphicsContext.current?.cgContext else { return }
        
        // Draw highlighting
        if timeline.highlighted {
            ctx.setFillColor(NSColor.highlightColor.cgColor)
            ctx.fill(NSRect(x: dirtyRect.origin.x,
                            y: dirtyRect.origin.y + CGFloat(30),
                            width: dirtyRect.width,
                            height: dirtyRect.height - CGFloat(30)))
        }
        
        let startTime = timeline.visibleTimeRange.lowerBound
        let endTime = timeline.visibleTimeRange.upperBound
        
        let oneSecWidth = bounds.width / CGFloat(timeline.visibleDur)
        
        if let selectedTimeRange = timeline.selectedTimeRange {
            // Draw selection
            let timeRange = selectedTimeRange.clamped(to: timeline.visibleTimeRange)
            
            guard !timeRange.isEmpty else { return }
            
            let duration = timeRange.upperBound - timeRange.lowerBound
            
            let startPos = CGFloat(timeRange.lowerBound - timeline.visibleTimeRange.lowerBound) * oneSecWidth
            
            // Draw selection borders
            ctx.move(to: CGPoint(x: startPos,
                                 y: CGFloat(30)))
            ctx.addLine(to: CGPoint(x: startPos,
                                    y: bounds.height))
            
            let endPos = startPos + CGFloat(duration) * oneSecWidth
            ctx.move(to: CGPoint(x: endPos,
                                 y: CGFloat(30)))
            ctx.addLine(to: CGPoint(x: endPos,
                                    y: bounds.height))
            
            ctx.setLineWidth(CGFloat(1))
            ctx.setStrokeColor(NSColor.keyboardFocusIndicatorColor.cgColor)
            ctx.strokePath()
            
            // Draw selection background
            ctx.setFillColor(NSColor.selectionFillColor.cgColor)
            ctx.fill(CGRect(x: startPos,
                            y: CGFloat(30),
                            width: CGFloat(duration) * oneSecWidth,
                            height: bounds.height))
        }
        
        if (startTime ..< endTime).contains(timeline.currentTime) {
            // Draw cursor
            let cursorPos = CGFloat(timeline.currentTime - timeline.visibleTimeRange.lowerBound) * oneSecWidth
            
            ctx.move(to: CGPoint(x: cursorPos,
                                 y: CGFloat(22)))
            ctx.addLine(to: CGPoint(x: cursorPos,
                                    y: bounds.height))
            
            ctx.setStrokeColor(NSColor.timelineCursorColor.cgColor)
            ctx.setLineWidth(CGFloat(1))
            ctx.strokePath()
            
            // Draw cursor handle
            ctx.move(to: CGPoint(x: cursorPos - CGFloat(5), y: CGFloat(10)))
            ctx.addLine(to: CGPoint(x: cursorPos + CGFloat(5), y: CGFloat(10)))
            ctx.addLine(to: CGPoint(x: cursorPos + CGFloat(5), y: CGFloat(17)))
            ctx.addLine(to: CGPoint(x: cursorPos, y: CGFloat(23)))
            ctx.addLine(to: CGPoint(x: cursorPos - CGFloat(5), y: CGFloat(17)))
            ctx.addLine(to: CGPoint(x: cursorPos - CGFloat(5), y: CGFloat(10)))
            ctx.closePath()
            ctx.setFillColor(NSColor.timelineCursorColor.cgColor)
            ctx.fillPath()
        }
    }
}
