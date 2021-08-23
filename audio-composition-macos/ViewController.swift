//
//  ViewController.swift
//  audio-composition-macos
//
//  Created by russell.dzhafarov@gmail.com on 21.08.2021.
//

import Cocoa
import Combine

class ViewController: NSViewController {
    
    let savePanel: NSSavePanel = {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "Untitled.m4a"
        return panel
    }()
    
    @IBOutlet weak var playButton: NSButton!
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
    
    private var cancellables = Set<AnyCancellable>()
    
    deinit {
        cancellables.forEach{ $0.cancel() }
        cancellables.removeAll()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override var representedObject: Any? {
        didSet {
            guard let timeline = representedObject as? Timeline else { return }
            
            timeline.$needsDisplay
                .receive(on: DispatchQueue.main)
                .sink { [weak self] newValue in
                    guard newValue else { return }
                    self?.timelineView.needsDisplay = true
                    timeline.needsDisplay = false
                }
                .store(in: &cancellables)
            
            timeline.$tracks
                .receive(on: DispatchQueue.main)
                .sink { [weak self] newValue in
                    self?.timelineView.needsDisplay = true
                    self?.exportButton.isEnabled = !newValue.isEmpty
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
        timeline.selectedTimeRange = 0.0 ..< timeline.duration
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
        savePanel.begin { [weak self] response in
            guard response == .OK,
                  let url = self?.savePanel.url,
                  let timeline = self?.representedObject as? Timeline else { return }
            
            timeline.export(to: url)
        }
    }
}

