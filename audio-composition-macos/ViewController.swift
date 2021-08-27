//
//  ViewController.swift
//  audio-composition-macos
//
//  Created by russell.dzhafarov@gmail.com on 21.08.2021.
//

import Cocoa
import Combine

class ViewController: NSViewController {
    
    let exportPanel: NSSavePanel = {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "Untitled.m4a"
        return panel
    }()
    let importPanel: NSOpenPanel = {
        let panel = NSOpenPanel()
        panel.allowedFileTypes = Timeline.acceptableUTITypes
        return panel
    }()
    
    @IBOutlet weak var statusLabel: NSTextField!
    @IBOutlet weak var tableView: NSTableView! {
        didSet {
            tableView.backgroundColor = NSColor.timelineBackgroundColor
        }
    }
    @IBOutlet weak var backwardEndButton: NSButton!
    @IBOutlet weak var backwardButton: NSButton!
    @IBOutlet weak var playButton: NSButton!
    @IBOutlet weak var forwardButton: NSButton!
    @IBOutlet weak var forwardEndButton: NSButton!
    @IBOutlet weak var tableScrollView: NSScrollView!
    
    @IBOutlet weak var exportButton: NSButton! {
        didSet {
            let layer = CALayer()
            layer.borderWidth = CGFloat(1)
            layer.borderColor = NSColor.rulerColor.cgColor
            layer.cornerRadius = exportButton.bounds.height / CGFloat(2)
            exportButton.wantsLayer = true
            exportButton.layer = layer
        }
    }
    @IBOutlet weak var overlayView: OverlayView!
    @IBOutlet weak var timelineView: TimelineView!
    @IBOutlet weak var rulerView: RulerView!
    @IBOutlet weak var currentTimeLabel: NSTextField!
    @IBOutlet weak var timelineScrollView: NSScrollView! {
        didSet {
            timelineScrollView.backgroundColor = NSColor.timelineBackgroundColor
        }
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    deinit {
        // Remove observers
        cancellables.forEach{ $0.cancel() }
        cancellables.removeAll()
        // remove any existing notification registration
        NotificationCenter.default.removeObserver(self,
                                                  name: NSView.boundsDidChangeNotification,
                                                  object: tableScrollView)
        if let token = token {
            NotificationCenter.default.removeObserver(token)
        }
    }
    
    @objc func tableContentViewBoundsDidChange(_ notification: Notification) {
        // get the changed content view from the notification
        guard let changedContentView = notification.object as? NSClipView else { return }
        
        // get the origin of the NSClipView of the scroll view that
        // we're watching
        let changedBoundsOrigin = changedContentView.documentVisibleRect.origin
        
        // get the current scroll position of the document view
        let curOffset = timelineScrollView.contentView.bounds.origin
        var newOffset = curOffset
        
        // scrolling is synchronized in the vertical plane
        // so only modify the y component of the offset
        newOffset.y = changedBoundsOrigin.y
        
        // if our synced position is different from our current
        // position, reposition our content view
        if !NSEqualPoints(curOffset, changedBoundsOrigin) {
            // note that a scroll view watching this one will
            // get notified here
            timelineScrollView.contentView.scroll(to: newOffset)
            // we have to tell the NSScrollView to update its
            // scrollers
            timelineScrollView.reflectScrolledClipView(timelineScrollView.contentView)
        }
    }
    
    @objc func timelineContentViewBoundsDidChange(_ notification: Notification) {
        guard let changedContentView = notification.object as? NSClipView else { return }
        
        let changedBoundsOrigin = changedContentView.documentVisibleRect.origin
        
        let curOffset = tableScrollView.contentView.bounds.origin
        var newOffset = curOffset
        
        // scrolling is synchronized in the vertical plane
        // so only modify the y component of the offset
        newOffset.y = changedBoundsOrigin.y
        
        // if our synced position is different from our current
        // position, reposition our content view
        if !NSEqualPoints(curOffset, changedBoundsOrigin) {
            // note that a scroll view watching this one will
            // get notified here
            tableScrollView.contentView.scroll(to: newOffset)
            // we have to tell the NSScrollView to update its
            // scrollers
            tableScrollView.reflectScrolledClipView(tableScrollView.contentView)
        }
    }
    
    var token: NSObjectProtocol?
    override func viewDidLoad() {
        super.viewDidLoad()
        let timelineContentView = timelineScrollView.contentView
        timelineContentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(timelineContentViewBoundsDidChange(_:)),
                                               name: NSView.boundsDidChangeNotification,
                                               object: timelineContentView)
        
        
        // Synchronizing table and timeline scroll views
        // get the content view of the table view
        let synchronizedContentView = tableScrollView.contentView
        // Make sure the watched view is sending bounds changed
        // notifications (which is probably does anyway, but calling
        // this again won't hurt).
        synchronizedContentView.postsBoundsChangedNotifications = true
        // a register for those notifications on the synchronized content view.
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(tableContentViewBoundsDidChange(_:)),
                                               name: NSView.boundsDidChangeNotification,
                                               object: synchronizedContentView)
        
        // Observing view bounds changes to update timeline width
        overlayView.postsFrameChangedNotifications = true
        token = NotificationCenter.default.addObserver(forName: NSView.frameDidChangeNotification, object: overlayView, queue: .main) { [weak self] _ in
            guard let strongSelf = self, let timeline = strongSelf.representedObject as? Timeline else { return }
            
            let height = max(timeline.trackHeight * CGFloat(timeline.tracks.count),
                             strongSelf.timelineScrollView.documentVisibleRect.height - (strongSelf.timelineScrollView.horizontalRulerView?.bounds.height ?? .zero))
            
            strongSelf.timelineView.frame = NSRect(
                origin: strongSelf.timelineView.frame.origin,
                size: CGSize(width: strongSelf.timelineScrollView.documentVisibleRect.width - (strongSelf.timelineScrollView.verticalRulerView?.bounds.width ?? .zero),
                             height: height))
        }
    }
    
    override var representedObject: Any? {
        didSet {
            guard let timeline = representedObject as? Timeline,
                  isViewLoaded else { return }
            
            tableView.rowHeight = timeline.trackHeight
            
            timeline.$needsDisplay
                .receive(on: DispatchQueue.main)
                .sink { [weak self] newValue in
                    guard newValue else { return }
                    self?.timelineView.needsDisplay = true
                    timeline.needsDisplay = false
                }
                .store(in: &cancellables)
            
            timeline.$state
                .receive(on: DispatchQueue.main)
                .sink { [weak self] newValue in
                    let isEnabled = newValue == .ready
                    self?.exportButton.isEnabled = isEnabled
                    self?.playButton.isEnabled = isEnabled
                    self?.forwardButton.isEnabled = isEnabled
                    self?.forwardEndButton.isEnabled = isEnabled
                    self?.backwardButton.isEnabled = isEnabled
                    self?.backwardEndButton.isEnabled = isEnabled
                    self?.statusLabel.stringValue = newValue.rawValue
                }
                .store(in: &cancellables)
            
            timeline.$tracks
                .receive(on: DispatchQueue.main)
                .sink { [weak self] newValue in
                    guard let strongSelf = self else { return }
                    let height = max(timeline.trackHeight * CGFloat(timeline.tracks.count),
                                     strongSelf.timelineScrollView.documentVisibleRect.height - (strongSelf.timelineScrollView.horizontalRulerView?.bounds.height ?? .zero))
                    
                    strongSelf.timelineView.frame = NSRect(
                        origin: strongSelf.timelineView.frame.origin,
                        size: CGSize(width: strongSelf.timelineScrollView.documentVisibleRect.width - (strongSelf.timelineScrollView.verticalRulerView?.bounds.width ?? .zero),
                                     height: height))

                    strongSelf.timelineView.needsDisplay = true

                    strongSelf.tableView.reloadData()
                    
                    strongSelf.exportButton.isEnabled = !newValue.isEmpty
                    strongSelf.playButton.isEnabled = !newValue.isEmpty
                    strongSelf.forwardButton.isEnabled = !newValue.isEmpty
                    strongSelf.forwardEndButton.isEnabled = !newValue.isEmpty
                    strongSelf.backwardButton.isEnabled = !newValue.isEmpty
                    strongSelf.backwardEndButton.isEnabled = !newValue.isEmpty
                }
                .store(in: &cancellables)
            
            timeline.$highlighted
                .receive(on: DispatchQueue.main)
                .sink { [weak self] newValue in
                    self?.overlayView.needsDisplay = true
                }
                .store(in: &cancellables)
            
            timeline.$currentTime
                .receive(on: DispatchQueue.main)
                .sink { [weak self] newValue in
                    self?.overlayView.needsDisplay = true
                    self?.currentTimeLabel.stringValue = newValue.hhmmssms()
                }
                .store(in: &cancellables)
            
            timeline.$selectedTimeRange
                .receive(on: DispatchQueue.main)
                .sink { [weak self] newValue in
                    self?.overlayView.needsDisplay = true
                }
                .store(in: &cancellables)
            
            timeline.$visibleTimeRange
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    self?.rulerView.needsDisplay = true
                    self?.timelineView.needsDisplay = true
                    self?.overlayView.needsDisplay = true
                }
                .store(in: &cancellables)
            
            timeline.$playerState
                .receive(on: DispatchQueue.main)
                .sink { [weak self] newValue in
                    switch newValue {
                    case .playing:
                        self?.playButton.image = NSImage(systemSymbolName: .pause, accessibilityDescription: "")
                    case .stopped:
                        self?.playButton.image = NSImage(systemSymbolName: .play, accessibilityDescription: "")
                    }
                }
                .store(in: &cancellables)
            
            timeline.$error
                .receive(on: DispatchQueue.main)
                .sink { newValue in
                    if let newValue = newValue {
                        let alert = NSAlert()
                        alert.alertStyle = .critical
                        alert.messageText = "Something went wrong!"
                        alert.informativeText = newValue.localizedDescription
                        alert.runModal()
                    }
                }
                .store(in: &cancellables)
        }
    }
    
    // MARK: - Actions
    @IBAction func actionSolo(_ sender: NSButton) {
        guard let timeline = representedObject as? Timeline else { return }
        
        // Get current track
        let row = tableView.row(for: sender)
        guard timeline.tracks.indices.contains(row) else { return }
        let track = timeline.tracks[row]
        
        timeline.solo(track: track)
    }
    @IBAction func actionMute(_ sender: NSButton) {
        guard let timeline = representedObject as? Timeline else { return }
        
        // Get current track
        let row = tableView.row(for: sender)
        guard timeline.tracks.indices.contains(row) else { return }
        let track = timeline.tracks[row]
        
        timeline.mute(track: track)
    }
    
    override func selectAll(_ sender: Any?) {
        guard let timeline = representedObject as? Timeline else { return }
        for track in timeline.tracks {
            track.assets.forEach{ $0.isSelected = true }
        }
        timeline.needsDisplay = true
    }
    @IBAction func actionBackwardEnd(_ sender: Any) {
        guard let timeline = representedObject as? Timeline else { return }
        timeline.backwardEnd()
    }
    @IBAction func actionBackward(_ sender: Any) {
        guard let timeline = representedObject as? Timeline else { return }
        timeline.backward()
    }
    @IBAction func actionPlay(_ sender: Any) {
        guard let timeline = representedObject as? Timeline else { return }
        timeline.play()
    }
    @IBAction func actionForward(_ sender: Any) {
        guard let timeline = representedObject as? Timeline else { return }
        timeline.forward()
    }
    @IBAction func actionForwardEnd(_ sender: Any) {
        guard let timeline = representedObject as? Timeline else { return }
        timeline.forwardEnd()
    }
    @IBAction func actionExport(_ sender: Any) {
        let response = exportPanel.runModal()
        guard response == .OK,
              let url = exportPanel.url,
              let timeline = representedObject as? Timeline else { return }
        
        timeline.export(to: url)
    }
    @IBAction func importAction(_ sender: Any) {
        let response = importPanel.runModal()
        guard response == .OK,
              let url = importPanel.url,
              let timeline = representedObject as? Timeline else { return }
        
        timeline.importFile(at: url, to: nil)
    }
}

extension ViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        guard let timeline = representedObject as? Timeline else { return 0 }
        return timeline.tracks.count
    }
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        guard let timeline = representedObject as? Timeline else { return nil }
        return timeline.tracks[row]
    }
}
