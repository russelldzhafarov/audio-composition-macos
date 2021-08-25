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
    
    // MARK: - Events
    override func rightMouseDown(with event: NSEvent) {
        guard let timeline = timeline,
              !timeline.isEmpty else { return }
        
        // Clear selection
        timeline.tracks.forEach{ $0.asset?.isSelected = false }
        timeline.needsDisplay = true
        
        let loc = convert(event.locationInWindow, from: nil)
        let oneSecWidth = bounds.width / CGFloat(timeline.visibleDur)
        
        var selectedId: UUID?
        var trackId: UUID?
        var y = CGFloat.zero
        for track in timeline.tracks {
            let trackRect = CGRect(x: .zero, y: y, width: bounds.width, height: timeline.trackHeight)
            
            if NSPointInRect(loc, trackRect) {
                trackId = track.id
                
                if let asset = track.asset {
                    let assetRect = CGRect(x: CGFloat(asset.startTime - timeline.visibleTimeRange.lowerBound) * oneSecWidth,
                                           y: y,
                                           width: CGFloat(asset.duration) * oneSecWidth - CGFloat(4),
                                           height: timeline.trackHeight)
                    
                    if NSPointInRect(loc, assetRect) {
                        asset.isSelected = true
                        selectedId = asset.id
                        timeline.needsDisplay = true
                    }
                }
                
                break
            }
            
            y += timeline.trackHeight
        }
        
        if let selectedId = selectedId {
            // show asset menu
            let menu = NSMenu()
            let menuItem = menu.insertItem(withTitle: "Remove track",
                                           action: #selector(removeSelectedAsset(_:)),
                                           keyEquivalent: "",
                                           at: 0)
            menuItem.representedObject = selectedId
            NSMenu.popUpContextMenu(menu, with: event, for: self)
            
        } else {
            if let trackId = trackId {
                // show track menu
                let menu = NSMenu()
                let menuItem = menu.insertItem(withTitle: "Remove channel",
                                               action: #selector(removeSelectedTrack(_:)),
                                               keyEquivalent: "",
                                               at: 0)
                menuItem.representedObject = trackId
                NSMenu.popUpContextMenu(menu, with: event, for: self)
            }
        }
    }
    @objc func removeSelectedAsset(_ sender: NSMenuItem) {
        guard let timeline = timeline,
              let assetId = sender.representedObject as? UUID else { return }
        
        for track in timeline.tracks {
            if let asset = track.asset, asset.id == assetId {
                track.asset = nil
                needsDisplay = true
                break
            }
        }
    }
    @objc func removeSelectedTrack(_ sender: NSMenuItem) {
        guard let timeline = timeline,
              let trackId = sender.representedObject as? UUID,
              let idx = timeline.tracks.firstIndex(where: { $0.id == trackId }) else { return }
        
        timeline.tracks.remove(at: idx)
    }
    override func scrollWheel(with event: NSEvent) {
        super.scrollWheel(with: event)
        
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
    override func mouseDown(with event: NSEvent) {
        guard let timeline = timeline,
              !timeline.isEmpty else { return }
        
        // Clear selection
        timeline.tracks.forEach{ $0.asset?.isSelected = false }
        timeline.needsDisplay = true
        
        let start = convert(event.locationInWindow, from: nil)
        let oneSecWidth = bounds.width / CGFloat(timeline.visibleDur)
        
        var selected: AudioAsset?
        var y: CGFloat = .zero
        for track in timeline.tracks {
            if let asset = track.asset {
                let assetRect = CGRect(x: CGFloat(asset.startTime - timeline.visibleTimeRange.lowerBound) * oneSecWidth,
                                       y: y,
                                       width: CGFloat(asset.duration) * oneSecWidth - CGFloat(4),
                                       height: timeline.trackHeight)
                
                if NSPointInRect(start, assetRect) {
                    asset.isSelected = true
                    selected = asset
                    timeline.needsDisplay = true
                    break
                }
            }
            
            y += timeline.trackHeight
        }
        
        if let selected = selected {
            move(asset: selected, with: event)
        }
    }
    
    func move(asset: AudioAsset, with event: NSEvent) {
        guard let timeline = timeline,
              !timeline.isEmpty else { return }
        
        let start = convert(event.locationInWindow, from: nil)
        
        let assetStartTime = asset.startTime
        while true {
            guard let nextEvent = window?.nextEvent(matching: [.leftMouseUp, .leftMouseDragged]) else { continue }
            
            let end = convert(nextEvent.locationInWindow, from: nil)
            
            if Int(start.x) != Int(end.x) {
                let oneSecWidth = bounds.width / CGFloat(timeline.visibleDur)
                let change = TimeInterval((end.x - start.x) / oneSecWidth)
                
                asset.startTime = max(0, (assetStartTime + change))
                timeline.needsDisplay = true
            }
            
            if nextEvent.type == .leftMouseUp {
                break
            }
        }
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let timeline = timeline,
              let ctx = NSGraphicsContext.current?.cgContext else { return }
        
        // Asset label attributed
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byTruncatingTail
        
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.white,
            .font: NSFont.systemFont(ofSize: CGFloat(10)),
            .paragraphStyle: paragraphStyle
        ]
        
        let oneSecWidth = bounds.width / CGFloat(timeline.visibleDur)
        
        // Draw tracks
        var y: CGFloat = .zero
        for track in timeline.tracks {
            // Draw track background
            ctx.setFillColor(NSColor.timelineTrackBackgroundColor.cgColor)
            ctx.fill(CGRect(x: .zero, y:y, width: bounds.width, height: timeline.trackHeight))
            
            if let asset = track.asset {
                // Draw waveform
                drawWaveform(asset: asset, track: track, timeline: timeline, origin: CGPoint(x: .zero, y: y), color: NSColor.timelineWaveColor.cgColor, to: ctx)
                
                // Draw asset name
                let frame = CGRect(x: CGFloat(2) + CGFloat(asset.startTime - timeline.visibleTimeRange.lowerBound) * oneSecWidth,
                                   y: CGFloat(2) + y,
                                   width: CGFloat(asset.duration) * oneSecWidth - CGFloat(4),
                                   height: timeline.trackHeight)
                NSString(string: asset.name).draw(in: frame, withAttributes: attributes)
                
                // Draw asset selection
                if asset.isSelected {
                    let frame = CGRect(x: CGFloat(asset.startTime - timeline.visibleTimeRange.lowerBound) * oneSecWidth,
                                       y: y + CGFloat(1),
                                       width: CGFloat(asset.duration) * oneSecWidth,
                                       height: timeline.trackHeight - CGFloat(2))
                    ctx.setStrokeColor(NSColor.selectionColor.cgColor)
                    ctx.setLineWidth(CGFloat(2))
                    ctx.stroke(frame)
                }
            }
            
            // Draw horizontal separator
            ctx.move(to: CGPoint(x: dirtyRect.minX,
                                 y: y))
            ctx.addLine(to: CGPoint(x: dirtyRect.maxX,
                                    y: y))
            ctx.setStrokeColor(NSColor.timelineBackgroundColor.cgColor)
            ctx.setLineWidth(CGFloat(1))
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
    
    func drawWaveform(asset: AudioAsset, track: AudioTrack, timeline: Timeline, origin: CGPoint, color: CGColor, to ctx: CGContext) {
        
        let timeRange = (asset.startTime ..< (asset.startTime + asset.duration)).clamped(to: timeline.visibleTimeRange.lowerBound..<timeline.visibleTimeRange.upperBound)
        
        guard !timeRange.isEmpty else { return }
        
        let visibleDur = timeline.visibleDur
        let oneSecWidth = bounds.width / CGFloat(visibleDur)
        
        // Draw asset visible rect
        let frame = CGRect(x: CGFloat(timeRange.lowerBound - timeline.visibleTimeRange.lowerBound) * oneSecWidth,
                           y: origin.y + CGFloat(1),
                           width: CGFloat(timeRange.upperBound - timeRange.lowerBound) * oneSecWidth,
                           height: timeline.trackHeight - CGFloat(2))
        
        let fillColor: NSColor
        if track.isMuted {
            fillColor = .gray
        } else {
            if asset.isSelected {
                fillColor = NSColor.timelineWaveBackgroundColor
            } else {
                fillColor = NSColor.timelineWaveBackgroundColor
            }
        }
        
        ctx.setFillColor(fillColor.cgColor)
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
                             CGFloat(power) * (frame.height/2 - 10))
            
            ctx.move(to: CGPoint(x: x,
                                 y: frame.midY + 5 + heigth))
            
            ctx.addLine(to: CGPoint(x: x,
                                    y: frame.midY + 5 - heigth))
            
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
