//
//  EditorWindowController.swift
//  audio-composition-macos
//
//  Created by russell.dzhafarov@gmail.com on 21.08.2021.
//

import Cocoa

extension NSPasteboard.PasteboardType {
    static let audioAsset = NSPasteboard.PasteboardType("com.russelldzhafarov.audio-composition-macos.audioasset.pbtype")
}

class EditorWindowController: NSWindowController {
    
    var timeline: Timeline? {
        (document as? Document)?.timeline
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        window?.backgroundColor = NSColor.windowBackgroundColor
    }
    
    @IBAction func undo(_ sender: Any) {
        window?.undoManager?.undo()
    }
    @IBAction func redo(_ sender: Any) {
        window?.undoManager?.redo()
    }
    @IBAction func cut(_ sender: Any) {
        timeline?.cut()
    }
    @IBAction func copy(_ sender: Any) {
        timeline?.copy()
    }
    @IBAction func paste(_ sender: Any) {
        timeline?.paste()
    }
    @IBAction func delete(_ sender: Any) {
        timeline?.delete()
    }
}

extension EditorWindowController: NSMenuItemValidation {
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(cut(_:)):
            var assets: [AudioAsset] = []
            for track in timeline?.tracks ?? [] {
                for asset in track.assets {
                    if asset.isSelected { assets.append(asset) }
                }
            }
            return !assets.isEmpty
            
        case #selector(copy(_:)):
            var assets: [AudioAsset] = []
            for track in timeline?.tracks ?? [] {
                for asset in track.assets {
                    if asset.isSelected { assets.append(asset) }
                }
            }
            return !assets.isEmpty
            
        case #selector(paste(_:)):
            return NSPasteboard.general.data(forType: .audioAsset)?.isEmpty == false
            
        case #selector(delete(_:)):
            var assets: [AudioAsset] = []
            for track in timeline?.tracks ?? [] {
                for asset in track.assets {
                    if asset.isSelected { assets.append(asset) }
                }
            }
            return !assets.isEmpty
            
        default:
            return true
        }
    }
}
