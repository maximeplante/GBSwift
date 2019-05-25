//
//  AppDelegate.swift
//  GBSwift
//
//  Created by Maxime Plante on 2019-05-17.
//  Copyright © 2019 Maxime Plante. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    let terminal: TerminalWindowController
    let screen: ScreenWindowController
    let debugger: Debugger
    let gameboy: Gameboy
    let mmu: MMU
    let cpu: CPU
    let ppu: PPU

    override init() {
        // Initialize boot rom
        let rom = Bundle.main.url(forResource: "rom", withExtension: "bin")
        let bootRom = BootRom(fromFile: rom!)

        // Initialize Gameboy
        ppu = PPU()
        mmu = MMU(bootRom: bootRom, ppu: ppu)
        cpu = CPU(mmu: mmu)
        gameboy = Gameboy(cpu: cpu, mmu: mmu, ppu: ppu)

        // Initialize UI
        terminal = TerminalWindowController(windowNibName: "TerminalWindow")
        screen = ScreenWindowController(windowNibName: "ScreenWindow")
        ppu.screenDelegate = screen
        debugger = Debugger(withTerminal: terminal, andGameboy: gameboy)

        super.init()
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        showDebugger()
        showScreen()
    }

    @IBAction func showDebuggerMenuAction(_ sender: Any) {
        showDebugger()
    }

    @IBAction func showScreenMenuAction(_ sender: Any) {
        showScreen()
    }

    func showDebugger() {
        terminal.window?.makeKeyAndOrderFront(nil)
    }

    func showScreen() {
        screen.window?.makeKeyAndOrderFront(nil)
    }
}

