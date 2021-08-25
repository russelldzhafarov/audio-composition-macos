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
        if let token = token {
            NotificationCenter.default.removeObserver(token)
        }
    }
    
    var token: NSObjectProtocol?
    override func viewDidLoad() {
        super.viewDidLoad()
        // Observing view bounds changes
        overlayView.postsFrameChangedNotifications = true
        token = NotificationCenter.default.addObserver(forName: NSView.frameDidChangeNotification, object: overlayView, queue: .main) { [weak self] _ in
            guard let strongSelf = self else { return }
            
            strongSelf.timelineView.frame = NSRect(
                origin: strongSelf.timelineView.frame.origin,
                size: CGSize(width: strongSelf.timelineScrollView.documentVisibleRect.width - (strongSelf.timelineScrollView.verticalRulerView?.bounds.width ?? .zero),
                             height: strongSelf.timelineView.frame.height))
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
                    strongSelf.timelineView.frame = NSRect(
                        origin: strongSelf.timelineView.frame.origin,
                        size: CGSize(width: strongSelf.timelineScrollView.documentVisibleRect.width,
                                     height: timeline.trackHeight * CGFloat(newValue.count + 1)))
                    
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
    override func selectAll(_ sender: Any?) {
        guard let timeline = representedObject as? Timeline else { return }
        timeline.tracks.forEach{ $0.asset.isSelected = true }
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
        
        timeline.importFile(at: url)
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
