//
//  Document.swift
//  audio-composition-macos
//
//  Created by russell.dzhafarov@gmail.com on 21.08.2021.
//

import Cocoa

class Document: NSDocument {
    
    let timeline = Timeline()
    
    override init() {
        super.init()
        // Add your subclass-specific initialization here.
    }

    override class var autosavesInPlace: Bool {
        return true
    }

    override func makeWindowControllers() {
        // Returns the Storyboard that contains your Document window.
        let storyboard = NSStoryboard(name: NSStoryboard.Name("Main"), bundle: nil)
        let windowController = storyboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("Document Window Controller")) as! NSWindowController
        self.addWindowController(windowController)
        
        windowController.contentViewController?.representedObject = timeline
    }

    override func data(ofType typeName: String) throws -> Data {
        return try JSONEncoder().encode(timeline.tracks)
    }

    override func read(from data: Data, ofType typeName: String) throws {
        timeline.tracks = try JSONDecoder().decode([AudioTrack].self, from: data)
    }
}

