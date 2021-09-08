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
    
    var dragId: UUID?
    var dragLoc: NSPoint?
    
    // MARK: - Events
    override func rightMouseDown(with event: NSEvent) {
        guard let timeline = timeline,
              !timeline.isEmpty else { return }
        
        // Clear selection
        for track in timeline.tracks {
            track.assets.forEach{ $0.isSelected = false }
        }
        timeline.needsDisplay = true
        
        let loc = convert(event.locationInWindow, from: nil)
        let oneSecWidth = bounds.width / CGFloat(timeline.visibleDur)
        
        var selectedAsset: AudioAsset?
        var selectedTrack: AudioTrack?
        var y = CGFloat.zero
        for track in timeline.tracks {
            let trackRect = CGRect(x: .zero, y: y, width: bounds.width, height: timeline.trackHeight)
            
            if NSPointInRect(loc, trackRect) {
                selectedTrack = track
                
                for asset in track.assets {
                    let assetRect = CGRect(x: CGFloat(asset.startTime - timeline.visibleTimeRange.lowerBound) * oneSecWidth,
                                           y: y,
                                           width: CGFloat(asset.duration) * oneSecWidth - CGFloat(4),
                                           height: timeline.trackHeight)
                    
                    if NSPointInRect(loc, assetRect) {
                        asset.isSelected = true
                        selectedAsset = asset
                        timeline.needsDisplay = true
                    }
                }
                
                break
            }
            
            y += timeline.trackHeight
        }
        
        if let selectedAsset = selectedAsset {
            // show asset menu
            let menu = NSMenu()
            let menuItem = menu.insertItem(withTitle: "Remove track",
                                           action: #selector(removeSelectedAsset(_:)),
                                           keyEquivalent: "",
                                           at: 0)
            menuItem.representedObject = selectedAsset
            NSMenu.popUpContextMenu(menu, with: event, for: self)
            
        } else {
            if let selectedTrack = selectedTrack {
                // show track menu
                let menu = NSMenu()
                let menuItem = menu.insertItem(withTitle: "Remove channel",
                                               action: #selector(removeSelectedTrack(_:)),
                                               keyEquivalent: "",
                                               at: 0)
                menuItem.representedObject = selectedTrack
                NSMenu.popUpContextMenu(menu, with: event, for: self)
            }
        }
    }
    @objc func removeSelectedAsset(_ sender: NSMenuItem) {
        guard let asset = sender.representedObject as? AudioAsset else { return }
        timeline?.removeAsset(asset)
    }
    @objc func removeSelectedTrack(_ sender: NSMenuItem) {
        guard let track = sender.representedObject as? AudioTrack else { return }
        timeline?.removeTrack(track)
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
            timeline.visibleTimeRange = timeline.visibleTimeRange.lowerBound + Double(deltaPixels) ... timeline.visibleTimeRange.upperBound + Double(deltaPixels)
        }
    }
    override func mouseDown(with event: NSEvent) {
        guard let timeline = timeline,
              !timeline.isEmpty else { return }
        
        // Clear selection
        for track in timeline.tracks {
            track.assets.forEach{ $0.isSelected = false }
        }
        timeline.needsDisplay = true
        
        let start = convert(event.locationInWindow, from: nil)
        let oneSecWidth = bounds.width / CGFloat(timeline.visibleDur)
        
        var selected: AudioAsset?
        var y: CGFloat = .zero
        for track in timeline.tracks {
            for asset in track.assets {
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
            
            if selected != nil {
                break
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
        
        dragId = asset.id
        dragLoc = start
        
        while true {
            guard let nextEvent = window?.nextEvent(matching: [.leftMouseUp, .leftMouseDragged]) else { continue }
            
            let end = convert(nextEvent.locationInWindow, from: nil)
            dragLoc = end
            
            if Int(start.x) != Int(end.x) {
                let oneSecWidth = bounds.width / CGFloat(timeline.visibleDur)
                let change = TimeInterval((end.x - start.x) / oneSecWidth)
                
                asset.startTime = TimeInterval(max(TimeInterval.zero,
                                                   (assetStartTime + change)))
                
                timeline.needsDisplay = true
            }
            
            if nextEvent.type == .leftMouseUp {
                dragId = nil
                dragLoc = nil
                if let track = timeline.track(at: end) {
                    
                    for trackAsset in track.assets {
                        if trackAsset.id == asset.id { continue }
                        
                        if trackAsset.timeRange.overlaps(asset.timeRange) {
                            asset.startTime = (trackAsset.startTime + trackAsset.duration)
                        }
                    }
                    
                    timeline.move(asset: asset, to: track)
                }
                timeline.needsDisplay = true
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
        
        // Draw tracks background
        ctx.setFillColor(NSColor.timelineTrackBackgroundColor.cgColor)
        ctx.fill(CGRect(x: .zero, y: .zero,
                        width: bounds.width,
                        height: CGFloat(timeline.tracks.count) * timeline.trackHeight))
        
        // Draw separators between tracks
        do {
            var y = timeline.trackHeight
            for _ in timeline.tracks {
                // Draw horizontal separator
                ctx.move(to: CGPoint(x: .zero,
                                     y: y))
                ctx.addLine(to: CGPoint(x: bounds.width,
                                        y: y))
                ctx.setStrokeColor(NSColor.timelineBackgroundColor.cgColor)
                ctx.setLineWidth(CGFloat(1))
                ctx.strokePath()
                
                y += timeline.trackHeight
            }
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
        
        // Draw tracks
        var y: CGFloat = .zero
        for track in timeline.tracks {
            for asset in track.assets {
                
                let origin: NSPoint
                if let id = dragId, let dragLoc = dragLoc, asset.id == id {
                    // Asset is dragging
                    let channel = floor(dragLoc.y / timeline.trackHeight)
                    let offset = dragLoc.y - (channel * timeline.trackHeight)
                    let y = max(CGFloat.zero,
                                min(CGFloat(timeline.tracks.count - 1) * timeline.trackHeight,
                                    dragLoc.y - offset))
                    origin = NSPoint(x: dragLoc.x, y: y)
                    
                } else {
                    origin = CGPoint(x: .zero, y: y)
                }
                
                // Draw waveform
                drawWaveform(asset: asset, track: track, timeline: timeline, origin: origin, color: NSColor.timelineWaveColor.cgColor, to: ctx)
                
                // Draw asset name
                let frame = CGRect(x: CGFloat(2) + CGFloat(asset.startTime - timeline.visibleTimeRange.lowerBound) * oneSecWidth,
                                   y: CGFloat(2) + origin.y,
                                   width: CGFloat(asset.duration) * oneSecWidth - CGFloat(4),
                                   height: timeline.trackHeight)
                NSString(string: asset.name).draw(in: frame, withAttributes: attributes)
                
                // Draw asset selection
                if asset.isSelected {
                    let frame = CGRect(x: CGFloat(asset.startTime - timeline.visibleTimeRange.lowerBound) * oneSecWidth,
                                       y: origin.y + CGFloat(1),
                                       width: CGFloat(asset.duration) * oneSecWidth,
                                       height: timeline.trackHeight - CGFloat(2))
                    ctx.setStrokeColor(NSColor.selectionStrokeColor.cgColor)
                    ctx.setLineWidth(CGFloat(2))
                    ctx.stroke(frame)
                }
            }
            
            y += timeline.trackHeight
        }
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
                fillColor = NSColor.selectionFillColor
                
            } else {
                fillColor = NSColor.timelineWaveBackgroundColor
            }
        }
        
        ctx.setFillColor(fillColor.cgColor)
        ctx.fill(frame)
        ctx.setStrokeColor(NSColor.timelineWaveBorderColor.cgColor)
        ctx.stroke(frame)
        
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
    
    // MARK: - Drag & Drop
    override func awakeFromNib() {
        super.awakeFromNib()
        registerForDraggedTypes([.fileURL])
    }
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard sender.draggingPasteboard.canReadObject(forClasses: [NSURL.self],
                                                      options: [.urlReadingContentsConformToTypes: Timeline.acceptableUTITypes]) else { return NSDragOperation() }
        
        timeline?.highlighted = true
        
        return .copy
    }
    override func draggingExited(_ sender: NSDraggingInfo?) {
        timeline?.highlighted = false
    }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let timeline = timeline else { return false }
        
        let pboard = sender.draggingPasteboard
        guard pboard.types?.contains(.fileURL) == true,
              let fileURL = NSURL(from: pboard) else { return false }
        
        timeline.highlighted = false
        
        let loc = convert(sender.draggingLocation, from: nil)
        let time = timeline.visibleTimeRange.lowerBound + (timeline.visibleDur * Double(loc.x) / Double(bounds.width))
        
        timeline.importFile(at: fileURL as URL, startTime: time, to: timeline.track(at: loc))
        
        return true
    }
}
