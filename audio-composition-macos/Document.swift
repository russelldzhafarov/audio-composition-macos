//
//  Document.swift
//  audio-composition-macos
//
//  Created by russell.dzhafarov@gmail.com on 21.08.2021.
//

import Cocoa

class Document: NSDocument {
    
    let timeline = Timeline(tracks: [AudioTrack(id: UUID(), name: "Channel # 1", assets: [])],
                            undoManager: nil)
    
    override init() {
        super.init()
        // Add your subclass-specific initialization here.
    }

    override class var autosavesInPlace: Bool {
        return true
    }

    override func makeWindowControllers() {
        // Returns the Storyboard that contains your Document window.
        let storyboard = NSStoryboard(name: .main, bundle: nil)
        let windowController = storyboard.instantiateController(withIdentifier: .documentWindowController) as! NSWindowController
        self.addWindowController(windowController)
        
        timeline.undoManager = windowController.window?.undoManager
        
        windowController.contentViewController?.representedObject = timeline
    }
    
    override func data(ofType typeName: String) throws -> Data {
        return try JSONEncoder().encode(timeline.tracks)
    }

    override func read(from data: Data, ofType typeName: String) throws {
        timeline.tracks = try JSONDecoder().decode([AudioTrack].self, from: data)
    }
}

