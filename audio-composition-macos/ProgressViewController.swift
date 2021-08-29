//
//  ProgressViewController.swift
//  audio-composition-macos
//
//  Created by russell.dzhafarov@gmail.com on 29.08.2021.
//

import Cocoa

class ProgressViewController: NSViewController {

    @IBOutlet weak var progressIndicator: NSProgressIndicator!
    
    override func viewDidLoad() {
        view.wantsLayer = true
        let layer = CALayer()
        layer.cornerRadius = CGFloat(8)
        layer.backgroundColor = NSColor.black.withAlphaComponent(CGFloat(0.5)).cgColor
        view.layer = layer
    }
    
    override func viewWillAppear() {
        progressIndicator.startAnimation(nil)
    }
    override func viewWillDisappear() {
        progressIndicator.stopAnimation(nil)
    }
}
