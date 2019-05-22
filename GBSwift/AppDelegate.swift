//
//  AppDelegate.swift
//  GBSwift
//
//  Created by Maxime Plante on 2019-05-17.
//  Copyright © 2019 Maxime Plante. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, TerminalWindowControllerDelegate {

    let terminal: TerminalWindowController
    let debugger: Debugger
    let gameboy: Gameboy
    let mmu: MMU
    let cpu: CPU

    override init() {
        let rom = Bundle.main.url(forResource: "rom", withExtension: "bin")
        let bootRom = BootRom(fromFile: rom!)
        mmu = MMU(bootRom: bootRom)
        cpu = CPU(mmu: mmu)
        gameboy = Gameboy(cpu: cpu, mmu: mmu)
        terminal = TerminalWindowController(windowNibName: "TerminalWindow")
        debugger = Debugger(withTerminal: terminal, andGameboy: gameboy)
        super.init()
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        showDebugger()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    @IBAction func showDebuggerMenuAction(_ sender: Any) {
        showDebugger()
    }

    func showDebugger() {
        terminal.window?.makeKeyAndOrderFront(nil)
    }

    public func command(input: String) {
        terminal.writeLine(content: input)
    }

}

