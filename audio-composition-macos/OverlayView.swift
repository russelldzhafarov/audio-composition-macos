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
        
        let pxPerSec = bounds.width / CGFloat(endTime - startTime)
        
        if let selectedTimeRange = timeline.selectedTimeRange {
            // Draw selection
            let timeRange = selectedTimeRange.clamped(to: timeline.visibleTimeRange)
            
            guard !timeRange.isEmpty else { return }
            
            let duration = timeRange.upperBound - timeRange.lowerBound
            
            let startPos = CGFloat(timeRange.lowerBound - timeline.visibleTimeRange.lowerBound) * pxPerSec
            
            // Draw selection borders
            ctx.move(to: CGPoint(x: startPos,
                                 y: CGFloat(30)))
            ctx.addLine(to: CGPoint(x: startPos,
                                    y: bounds.height))
            
            let endPos = startPos + CGFloat(duration) * pxPerSec
            ctx.move(to: CGPoint(x: endPos,
                                 y: CGFloat(30)))
            ctx.addLine(to: CGPoint(x: endPos,
                                    y: bounds.height))
            
            ctx.setLineWidth(CGFloat(1))
            ctx.setStrokeColor(NSColor.keyboardFocusIndicatorColor.cgColor)
            ctx.strokePath()
            
            // Draw selection background
            ctx.setFillColor(NSColor.selectionColor.cgColor)
            ctx.fill(CGRect(x: startPos,
                            y: CGFloat(30),
                            width: CGFloat(duration) * pxPerSec,
                            height: bounds.height))
        }
        
        if (startTime ..< endTime).contains(timeline.currentTime) {
            // Draw cursor
            let cursorPos = CGFloat(timeline.currentTime - timeline.visibleTimeRange.lowerBound) * pxPerSec
            
            ctx.move(to: CGPoint(x: cursorPos,
                                 y: CGFloat(22)))
            ctx.addLine(to: CGPoint(x: cursorPos,
                                    y: bounds.height))
            
            ctx.setStrokeColor(NSColor.timelineCursorColor.cgColor)
            ctx.setLineWidth(CGFloat(1))
            ctx.strokePath()
            
            // Draw cursor handle
            ctx.move(to: CGPoint(x: cursorPos - CGFloat(4),
                                 y: CGFloat(22)))
            ctx.addLine(to: CGPoint(x: cursorPos + CGFloat(4),
                                    y: CGFloat(22)))
            ctx.addLine(to: CGPoint(x: cursorPos,
                                    y: CGFloat(30)))
            ctx.addLine(to: CGPoint(x: cursorPos - CGFloat(4),
                                    y: CGFloat(22)))
            ctx.closePath()
            ctx.setFillColor(NSColor.timelineCursorColor.cgColor)
            ctx.fillPath()
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        guard let timeline = timeline,
              !timeline.isEmpty else { return }
        
        let start = convert(event.locationInWindow, from: nil)
        
        let duration = timeline.visibleDur
        let startTime = timeline.visibleTimeRange.lowerBound + (duration * Double(start.x) / Double(bounds.width))
        
        while true {
            guard let nextEvent = window?.nextEvent(matching: [.leftMouseUp, .leftMouseDragged]) else { continue }
            
            let end = convert(nextEvent.locationInWindow, from: nil)
            
            if Int(start.x) == Int(end.x) && Int(start.y) == Int(end.y) {
                timeline.selectedTimeRange = nil
                timeline.currentTime = startTime.clamped(to: 0.0...timeline.duration)
                
            } else {
                
                let endTime = timeline.visibleTimeRange.lowerBound + (duration * Double(end.x) / Double(bounds.width))
                
                if startTime < endTime {
                    timeline.selectedTimeRange = (startTime ..< endTime).clamped(to: 0 ..< timeline.duration)
                    timeline.currentTime = startTime.clamped(to: 0.0...timeline.duration)
                    
                } else if startTime > endTime {
                    timeline.selectedTimeRange = (endTime ..< startTime).clamped(to: 0 ..< timeline.duration)
                    timeline.currentTime = endTime.clamped(to: 0.0...timeline.duration)
                    
                } else {
                    timeline.selectedTimeRange = nil
                    timeline.currentTime = startTime.clamped(to: 0.0...timeline.duration)
                }
            }
            
            if nextEvent.type == .leftMouseUp {
                timeline.seek(to: timeline.currentTime)
                break
            }
        }
    }
    
    // MARK: - Drag & Drop
    override func awakeFromNib() {
        super.awakeFromNib()
        registerForDraggedTypes([.fileURL])
    }
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard sender.draggingPasteboard.canReadObject(forClasses: [NSURL.self],
                                                      options: [.urlReadingContentsConformToTypes: timeline?.acceptableUTITypes ?? []]) else { return NSDragOperation() }
        
        timeline?.highlighted = true
        
        return .copy
    }
    override func draggingExited(_ sender: NSDraggingInfo?) {
        timeline?.highlighted = false
    }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pboard = sender.draggingPasteboard
        guard pboard.types?.contains(.fileURL) == true,
              let fileURL = NSURL(from: pboard) else { return false }
        
        timeline?.highlighted = false
        timeline?.importFile(at: fileURL as URL)
        
        return true
    }
    
    // MARK: - Events
    override func scrollWheel(with event: NSEvent) {
        guard let timeline = timeline else { return }
        
        let duration = timeline.visibleDur
        let secPerPx = CGFloat(duration) / bounds.width
        
        let deltaPixels = event.deltaX < 0
            ? min(-event.deltaX * secPerPx,
                  CGFloat(timeline.duration - timeline.visibleTimeRange.upperBound))
            : min(event.deltaX * secPerPx,
                  CGFloat(timeline.visibleTimeRange.lowerBound)) * -1
        
        if deltaPixels != 0 {
            timeline.visibleTimeRange = timeline.visibleTimeRange.lowerBound + Double(deltaPixels) ..< timeline.visibleTimeRange.upperBound + Double(deltaPixels)
        }
    }
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
        
        timeline.visibleTimeRange = (startTime ..< endTime).clamped(to: 0 ..< timeline.duration)
    }
}
