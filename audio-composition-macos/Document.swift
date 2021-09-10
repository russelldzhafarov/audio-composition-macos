//
//  Document.swift
//  audio-composition-macos
//
//  Created by russell.dzhafarov@gmail.com on 21.08.2021.
//

import Cocoa
import AVFoundation

extension NSStoryboard.Name {
    static let main = NSStoryboard.Name("Main")
}
extension NSStoryboard.SceneIdentifier {
    static let documentWindowController = NSStoryboard.SceneIdentifier("Document Window Controller")
    static let progressViewController = NSStoryboard.SceneIdentifier("ProgressViewController")
}

class Document: NSDocument {
    
    // Model
    let timeline = Timeline(tracks: [AudioTrack(id: UUID(), name: "Channel # 1", assets: [])],
                            undoManager: nil)
    
    override class var preservesVersions: Bool { false }
    override class var autosavesInPlace: Bool { false }
    
    // Top-level document wrapper
    var documentFileWrapper: FileWrapper?
    
    override func makeWindowControllers() {
        // Returns the Storyboard that contains your Document window.
        let storyboard = NSStoryboard(name: .main, bundle: nil)
        if let windowController = storyboard.instantiateController(withIdentifier: .documentWindowController) as? EditorWindowController {
            
            addWindowController(windowController)
            
            timeline.undoManager = windowController.window?.undoManager
            
            windowController.contentViewController?.representedObject = timeline
        }
    }
    
    override class func canConcurrentlyReadDocuments(ofType typeName: String) -> Bool { true }
    
    override func read(from fileWrapper: FileWrapper, ofType typeName: String) throws {
        guard fileWrapper.isDirectory,
              let fileWrappers = fileWrapper.fileWrappers,
              let docWrapper = fileWrappers["data.json"],
              let jsonData = docWrapper.regularFileContents
        else {
            throw NSError(domain: "com.russelldzhafarov.audio-composition-macos",
                          code: 0,
                          userInfo: [NSLocalizedDescriptionKey: "Project file is broken"])
        }

        timeline.tracks = try JSONDecoder().decode([AudioTrack].self, from: jsonData)
        
        self.documentFileWrapper = fileWrapper
    }
    
    override func canAsynchronouslyWrite(to url: URL, ofType typeName: String, for saveOperation: NSDocument.SaveOperationType) -> Bool { true }
    
    override func fileWrapper(ofType typeName: String) throws -> FileWrapper {
        
        if documentFileWrapper == nil {
            documentFileWrapper = FileWrapper(directoryWithFileWrappers: [:])
        }

        let jsonData = try JSONEncoder().encode(timeline.tracks)
        if let fileWrapper = documentFileWrapper?.fileWrappers?["data.json"] {
            documentFileWrapper?.removeFileWrapper(fileWrapper)
        }
        
        documentFileWrapper?.addRegularFile(withContents: jsonData, preferredFilename: "data.json")
        
        return documentFileWrapper!
    }
}

