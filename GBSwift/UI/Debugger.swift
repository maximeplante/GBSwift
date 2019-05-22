//
//  Debugger.swift
//  GBSwift
//
//  Created by Maxime Plante on 2019-05-19.
//  Copyright © 2019 Maxime Plante. All rights reserved.
//

import Foundation

class Debugger: TerminalWindowControllerDelegate {
    let terminal: TerminalWindowController

    let gameboy: GameBoy

    var lastCommand: String

    public init(withTerminal terminal: TerminalWindowController,
                andGameboy gameboy: GameBoy) {
        self.terminal = terminal
        self.gameboy = gameboy
        lastCommand = ""
        self.terminal.delegate = self
        terminal.setTitle(title: "GBSwift Debugger")
        terminal.writeLine(content: "GBSwift Debugger Terminal\n")
    }

    public func command(input: String) {
        var command = input
        if command.count == 0 {
            command = lastCommand
        }
        if command.count == 0 {
            return
        }
        lastCommand = command
        let arguments = command.split(separator: " ")
        switch arguments[0] {
        case "step", "s":
            stepCommand(arguments: arguments)
            break;
        case "state", "st":
            stateCommand(arguments: arguments);
            break;
        case "reset", "rst":
            resetCommand(arguments: arguments)
            break;
        default:
            terminal.writeLine(content: "This command does not exist")
        }
    }

    func stepCommand(arguments: Array<Substring>) {
        let count = tryParseIntArgument(arguments: arguments, index: 1) ?? 1
        for _ in 0...count - 1 {
            do {
                try gameboy.step()
            } catch CPUError.notImplementedInstruction(let op, let pc) {
                terminal.writeLine(content: String(format: "Error: Opcode %02X at memory location %04X is not implemented", op, pc))
                return
            } catch {
                terminal.writeLine(content: "Unexpected error")
                return
            }
        }
        printGameBoyState()
    }

    func stateCommand(arguments: Array<Substring>) {
        printGameBoyState()
    }

    func resetCommand(arguments: Array<Substring>) {
        gameboy.reset()
        terminal.writeLine(content: "Gameboy Reset")
    }

    func tryParseIntArgument(arguments: Array<Substring>, index: Int) -> Int? {
        if arguments.count < index + 1 {
            return nil
        }
        let value: Int?
        if arguments[index].first == "$" {
            value = Int(arguments[index].dropFirst(), radix: 16)
        } else {
            value = Int(String(arguments[index]))
        }
        return value
    }

    func printGameBoyState() {
        terminal.writeLine(content: "=== Game Boy ===")
        terminal.writeLine(content: "--- Registers ---")
        terminal.write(content: String(format: "A:%02X BC:%04X DE:%04X HL:%04X SP:%04X PC:%04X F:",
                                       gameboy.cpu.r[gameboy.cpu.a],
                                       gameboy.cpu.rWR(gameboy.cpu.b, gameboy.cpu.c),
                                       gameboy.cpu.rWR(gameboy.cpu.d, gameboy.cpu.e),
                                       gameboy.cpu.rWR(gameboy.cpu.h, gameboy.cpu.l),
                                       gameboy.cpu.sp,
                                       gameboy.cpu.pc))
        if gameboy.cpu.flag(.z) {
            terminal.write(content: "Z")
        } else {
            terminal.write(content: "-")
        }
        if gameboy.cpu.flag(.n) {
            terminal.write(content: "N")
        } else {
            terminal.write(content: "-")
        }
        if gameboy.cpu.flag(.h) {
            terminal.write(content: "H")
        } else {
            terminal.write(content: "-")
        }
        if gameboy.cpu.flag(.c) {
            terminal.write(content: "C")
        } else {
            terminal.write(content: "-")
        }
        terminal.writeLine(content: "")
        terminal.writeLine(content: "--- Memory ---")
        let offset = 15 * (Int(gameboy.cpu.pc) / 16)
        printMemorySegment(offset: offset, length: 48, cursor: Int(gameboy.cpu.pc) - offset)
        terminal.writeLine(content: "")
    }

    func printMemorySegment(offset: Int, length: Int, cursor: Int) {
        printByteArray(gameboy.mmu.readRange(offset: UInt16(offset), length: UInt16(length)), startAddress: offset, bytesPerLine: 16, cursor: cursor)
    }

    func printByteArray(_ byteArray: [UInt8], startAddress: Int, bytesPerLine: Int, cursor: Int) {
        for i in 0...byteArray.count - 1 {
            if i % bytesPerLine == 0 {
                if i != 0 {
                    terminal.writeLine(content: "")
                }
                terminal.write(content: String(format: "%04X: ", i + startAddress))
            }
            if i == cursor {
                terminal.write(content: String(format: "[%02X]", byteArray[i]))
            } else {
                terminal.write(content: String(format: " %02X ", byteArray[i]))
            }
        }
    }
}
