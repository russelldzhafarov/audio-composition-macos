//
//  RulerView.swift
//  audio-composition-macos
//
//  Created by russell.dzhafarov@gmail.com on 21.08.2021.
//

import Cocoa

class RulerView: NSView {

    var timeline: Timeline? {
        (window?.windowController?.document as? Document)?.timeline
    }
    
    let attributes: [NSAttributedString.Key: Any] = [
        .foregroundColor: NSColor.rulerLabelColor,
        .font: NSFont.systemFont(ofSize: CGFloat(11))
    ]
    
    override var isFlipped: Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }
    
    override func mouseDown(with event: NSEvent) {
        guard let timeline = timeline,
              !timeline.isEmpty else { return }
        
        while true {
            guard let nextEvent = window?.nextEvent(matching: [.leftMouseUp, .leftMouseDragged]) else { continue }
            
            let end = convert(nextEvent.locationInWindow, from: nil)
            let endTime = timeline.visibleTimeRange.lowerBound + (timeline.visibleDur * Double(end.x) / Double(bounds.width))
            
            timeline.selectedTimeRange = nil
            timeline.currentTime = endTime
            
            if nextEvent.type == .leftMouseUp {
                timeline.seek(to: timeline.currentTime)
                break
            }
        }
    }
    
    // MARK: - Drawing
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // Drawing code here.
        guard let timeline = timeline,
              let ctx = NSGraphicsContext.current?.cgContext else { return }
        
        let startTime = timeline.visibleTimeRange.lowerBound
        
        let visibleDur = timeline.visibleDur
        let oneSecWidth = bounds.width / CGFloat(visibleDur)
        
        let step: TimeInterval
        switch oneSecWidth {
        case 0 ..< 5:
            let koeff = Double(bounds.width) / Double(85)
            step = max(10, (visibleDur / koeff).round(nearest: 10))
            
        case 5 ..< 10: step = 15
        case 10 ..< 15: step = 10
        case 15 ..< 50: step = 5
        case 50 ..< 100: step = 3
        case 100 ..< 200: step = 1
        case 200 ..< 300: step = 0.5
        default: step = 0.25
        }
        
        let fixedStartTime = startTime.floor(nearest: step)
        let x = CGFloat(fixedStartTime - startTime) * oneSecWidth
        
        drawTicks(to: ctx,
                  startPos: x,
                  startTime: fixedStartTime,
                  endTime: timeline.visibleTimeRange.upperBound,
                  stepInSec: step / Double(10),
                  stepInPx: oneSecWidth * CGFloat(step) / CGFloat(10),
                  height: CGFloat(8),
                  drawLabel: false,
                  lineWidth: CGFloat(1))
        
        drawTicks(to: ctx,
                  startPos: x,
                  startTime: fixedStartTime,
                  endTime: timeline.visibleTimeRange.upperBound,
                  stepInSec: step,
                  stepInPx: oneSecWidth * CGFloat(step),
                  height: CGFloat(12),
                  drawLabel: true,
                  lineWidth: CGFloat(2))
    }
    
    private func drawTicks(to ctx: CGContext, startPos: CGFloat, startTime: TimeInterval, endTime: TimeInterval, stepInSec: TimeInterval, stepInPx: CGFloat, height: CGFloat, drawLabel: Bool, lineWidth: CGFloat) {
        
        var x = startPos
        for time in stride(from: startTime, to: endTime, by: stepInSec) {
            
            if drawLabel {
                NSString(string: stepInSec < 1 ? time.mmssms() : time.mmss())
                    .draw(at: NSPoint(x: x + CGFloat(2), y: .zero),
                          withAttributes: attributes)
            }
            
            ctx.move(to: CGPoint(x: x,
                                 y: bounds.height - height))
            
            ctx.addLine(to: CGPoint(x: x,
                                    y: bounds.height))
            
            x += stepInPx
        }
        
        ctx.setLineWidth(lineWidth)
        ctx.setStrokeColor(NSColor.rulerColor.cgColor)
        ctx.strokePath()
    }
}
