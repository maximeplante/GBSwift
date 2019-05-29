//
//  Gameboy.swift
//  GBSwift
//
//  Created by Maxime Plante on 2019-05-20.
//  Copyright © 2019 Maxime Plante. All rights reserved.
//

import Foundation

class Gameboy: PPUScreenDelegate {
    let cpu: CPU
    let mmu: MMU
    let ppu: PPU
    var breakpoints = [UInt16]()
    var debuggerDelegate: GameboyDebuggerDelegate? = nil
    var screenDelegate: GameboyScreenDelegate? = nil
    var stopRequested = false
    var resetRequested = false
    let queue: DispatchQueue
    let timePerCycle = 1.0 / 4194304.0
    var running = false

    init(cpu: CPU, mmu: MMU, ppu: PPU) {
        self.cpu = cpu
        self.mmu = mmu
        self.ppu = ppu
        self.queue = DispatchQueue(label: "Gameboy")
        self.ppu.screenDelegate = self
    }

    func step() throws {
        let _ = cpu.step()
    }

    func run() {
        running = true
        self.loop()
    }

    func shouldReset() {
        resetRequested = true
    }

    func shouldStop() {
        stopRequested = true
    }

    func loop() {
        let start = Date().timeIntervalSince1970
        var cycles = 0

        while cycles < 100000 {
            let delta = self.cpu.step()
            cycles += delta
            self.ppu.step(cpuCyclesDelta: delta)
            if (self.breakpoints.count > 0 && self.breakpoints.contains(self.cpu.pc)) {
                self.running = false
                DispatchQueue.main.async {
                    self.debuggerDelegate?.didEncounterBreakpoint()
                }
            }
            if self.stopRequested {
                stopRequested = false
                running = false
                DispatchQueue.main.async {
                    self.debuggerDelegate?.didStop()
                }
                return
            }
            if self.resetRequested {
                resetRequested = false
                mmu.reset()
                cpu.reset()
                ppu.reset()
                DispatchQueue.main.async {
                    self.debuggerDelegate?.didReset()
                }
            }
            if !self.running {
                return
            }
        }

        let elapsed = Date().timeIntervalSince1970 - start

        let wait = Double(Int64(Double(NSEC_PER_SEC) * (self.timePerCycle * Double(cycles) - elapsed))) / Double(NSEC_PER_SEC)

        let deadline = DispatchTime.now() + wait
        self.queue.asyncAfter(deadline: deadline) {
            self.loop()
        }
    }

    func addBreakpoint(address: UInt16) {
        breakpoints.append(address)
    }

    func removeBreakpoint(address: UInt16) {
        if let index = breakpoints.firstIndex(of: address) {
            breakpoints.remove(at: index)
        }
    }

    func removeAllBreakpoints() {
        breakpoints.removeAll()
    }

    // MARK: - GameboyScreenDelegate

    func setPixel(x: Int, y: Int, color: PPU.Color) {
        screenDelegate?.setPixel(x: x, y: y, color: color)
    }

    func drawScreen() {
        DispatchQueue.main.async {
            self.screenDelegate?.drawScreen()
        }
    }
}

protocol GameboyDebuggerDelegate {
    func didEncounterBreakpoint()
    func didEncounterExecutionError(message: String)
    func didStop()
    func didReset()
}

protocol GameboyScreenDelegate {
    func reset()
    func setPixel(x: Int, y: Int, color: PPU.Color)
    func drawScreen()
}
