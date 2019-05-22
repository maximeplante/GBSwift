//
//  Gameboy.swift
//  GBSwift
//
//  Created by Maxime Plante on 2019-05-20.
//  Copyright © 2019 Maxime Plante. All rights reserved.
//

import Foundation

class Gameboy {
    public let cpu: CPU
    public let mmu: MMU
    public var breakpoints = [UInt16]()
    public var delegate: GameboyDelegate? = nil
    let queue: DispatchQueue
    let timePerCycle = 1.0 / 4194304.0
    var running = false

    public init(cpu: CPU, mmu: MMU) {
        self.cpu = cpu
        self.mmu = mmu
        self.queue = DispatchQueue(label: "Gameboy")
    }

    public func reset() {
        mmu.reset()
        cpu.reset()
    }

    public func step() throws {
        try cpu.step()
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
                    cycles += try self.cpu.step()
                    if (self.breakpoints.count > 0 && self.breakpoints.contains(self.cpu.pc)) {
                        self.running = false
                        DispatchQueue.main.async {
                            self.delegate?.didEncounterBreakpoint()
                        }
                    }
                }
            } catch CPUError.notImplementedInstruction(let op, let pc) {
                self.running = false
                let message = String(format: "Error: Opcode %02X at memory location %04X is not implemented", op, pc)
                DispatchQueue.main.async {
                    self.delegate?.didEncounterExecutionError(message: message)
                }
            } catch {
                self.running = false
                DispatchQueue.main.async {
                    self.delegate?.didEncounterExecutionError(message: "Unexpected error")
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
}

protocol GameboyDelegate {
    func didEncounterBreakpoint()
    func didEncounterExecutionError(message: String)
}
