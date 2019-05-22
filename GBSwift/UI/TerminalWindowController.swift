//
//  DebuggerWindowController.swift
//  GBSwift
//
//  Created by Maxime Plante on 2019-05-19.
//  Copyright © 2019 Maxime Plante. All rights reserved.
//

import Cocoa

class TerminalWindowController: NSWindowController {

    @IBOutlet var outputTextView: NSTextView!
    @IBOutlet weak var inputTextView: NSTextField!
    
    var delegate: TerminalWindowControllerDelegate? = nil

    override func windowDidLoad() {
        super.windowDidLoad()
        self.outputTextView.isEditable = false
    }

    public func setTitle(title: String) {
        self.window?.title = title
    }

    public func writeLine(content: String) {
        write(content: content)
        write(content: "\n")
    }

    public func write(content: String) {
        if let ts = outputTextView?.textStorage {
            let attributes = [NSAttributedString.Key.font: NSFont(name: "Menlo", size: 12)]
            let str = NSAttributedString(string: content, attributes: attributes as [NSAttributedString.Key : Any])
            ts.insert(str, at: ts.length)
        }
        outputTextView.scrollToEndOfDocument(self)
    }

    @IBAction func onEnter(_ sender: Any) {
        writeLine(content: "> " + inputTextView.stringValue)
        delegate?.command(input: inputTextView.stringValue)
        inputTextView.stringValue = ""
    }
}

protocol TerminalWindowControllerDelegate {
    func command(input: String)
}
