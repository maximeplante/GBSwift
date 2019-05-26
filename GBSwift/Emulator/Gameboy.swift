//
//  Gameboy.swift
//  GBSwift
//
//  Created by Maxime Plante on 2019-05-20.
//  Copyright © 2019 Maxime Plante. All rights reserved.
//

import Foundation

class Gameboy: PPUScreenDelegate {
    public let cpu: CPU
    public let mmu: MMU
    public let ppu: PPU
    public var breakpoints = [UInt16]()
    public var debuggerDelegate: GameboyDebuggerDelegate? = nil
    public var screenDelegate: GameboyScreenDelegate? = nil
    let queue: DispatchQueue
    let timePerCycle = 1.0 / 4194304.0
    var running = false

    public init(cpu: CPU, mmu: MMU, ppu: PPU) {
        self.cpu = cpu
        self.mmu = mmu
        self.ppu = ppu
        self.queue = DispatchQueue(label: "Gameboy")
        self.ppu.screenDelegate = self
    }

    public func reset() {
        mmu.reset()
        cpu.reset()
    }

    public func step() throws {
        let _ = try cpu.step()
    }

    public func run() {
        running = true
        loop()
    }

    public func stop() {
        running = false
    }

    public func loop() {
        self.queue.async {
            let start = Date().timeIntervalSince1970
            var cycles = 0

            do {
                while cycles < 1000 && self.running {
                    let delta = try self.cpu.step()
                    cycles += delta
                    self.ppu.step(cpuCyclesDelta: delta)
                    if (self.breakpoints.count > 0 && self.breakpoints.contains(self.cpu.pc)) {
                        self.running = false
                        DispatchQueue.main.async {
                            self.debuggerDelegate?.didEncounterBreakpoint()
                        }
                    }
                }
            } catch CPUError.notImplementedInstruction(let op, let pc) {
                self.running = false
                let message = String(format: "Error: Opcode %02X at memory location %04X is not implemented", op, pc)
                DispatchQueue.main.async {
                    self.debuggerDelegate?.didEncounterExecutionError(message: message)
                }
            } catch {
                self.running = false
                DispatchQueue.main.async {
                    self.debuggerDelegate?.didEncounterExecutionError(message: "Unexpected error")
                }
            }

            let elapsed = Date().timeIntervalSince1970 - start

            if !self.running {
                return
            }

            let deadline = DispatchTime.now() + Double(Int64(Double(NSEC_PER_SEC) * (self.timePerCycle * Double(cycles) - elapsed))) / Double(NSEC_PER_SEC)
            self.queue.asyncAfter(deadline: deadline) {
                self.loop()
            }
        }
    }

    public func addBreakpoint(address: UInt16) {
        breakpoints.append(address)
    }

    public func removeBreakpoint(address: UInt16) {
        if let index = breakpoints.firstIndex(of: address) {
            breakpoints.remove(at: index)
        }
    }

    public func removeAllBreakpoints() {
        breakpoints.removeAll()
    }

    // MARK: - PPUScreenDelegate

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
}

protocol GameboyScreenDelegate {
    func setPixel(x: Int, y: Int, color: PPU.Color)
    func drawScreen()
}
