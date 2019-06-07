//
//  CPU.swift
//  GBSwift
//
//  Created by Maxime Plante on 2019-05-19.
//  Copyright © 2019 Maxime Plante. All rights reserved.
//

import Foundation

enum CPUError: Error {
    case notImplementedInstruction(opcode: UInt8, pc: UInt16)
}

class CPU {

    enum Flag: UInt8 {
        case z = 0x80
        case n = 0x40
        case h = 0x20
        case c = 0x10
    }

    var r: [UInt8]
    let b = 0
    let c = 1
    let d = 2
    let e = 3
    let h = 4
    let l = 5
    let f = 6
    let a = 7

    var pc: UInt16
    var sp: UInt16

    let mmu: MMU

    init(mmu: MMU) {
        r = [UInt8](repeating: 0, count: 8)
        self.mmu = mmu
        pc = 0
        sp = 0
    }

    func reset() {
        r = [UInt8](repeating: 0, count: 8)
        pc = 0
        sp = 0
    }

    // Read a word from two registers (shortened name because it is often used)
    func wWR(_ high: Int, _ low: Int, word: UInt16) {
        r[high] = UInt8((word & 0xFF00) >> 8)
        r[low] = UInt8(word & 0x00FF)
    }

    // Write a word from the mmu (shortened name because it is often used)
    func wWM(address: UInt16, word: UInt16) {
        mmu.write(address: address, value: UInt8(word & 0x00FF))
        mmu.write(address: address + 1, value: UInt8((word & 0xFF00) >> 8))
    }

    // Write a word from two registers (shortened name because it is often used)
    func rWR(_ high: Int, _ low: Int) -> UInt16 {
        return (UInt16(r[high]) << 8) + UInt16(r[low])
    }

    // Read a word from the mmu (shortened name because it is often used)
    func rWM(address: UInt16) -> UInt16 {
        return UInt16(mmu.read(address: address))
            + UInt16(mmu.read(address: address + 1)) << 8
    }

    /* Use to detect if the addition of v1 and v2 causes a nibble overflow.
     * When a nibble overflows, the H flag generally needs to be set.
     * The sub argument must be true if it is a substraction.
     */
    func hasNibbleOverflow(v1: UInt8, v2: UInt8, sub: Bool = false) -> Bool {
        let correctV2 = sub ? ~v2 + 1 : v2
        return (v1 & 0x0F + correctV2 & 0x0F) & 0x10 == 0x10
    }

    func setFlag(_ flag: Flag) {
        r[f] |= flag.rawValue
    }

    func resetFlag(_ flag: Flag) {
        r[f] &= ~flag.rawValue
    }

    func flag(_ flag: Flag) -> Bool {
        return r[f] & flag.rawValue == flag.rawValue
    }

    func unsignedToSigned(_ byte: UInt8) -> Int8 {
        return Int8(bitPattern: byte)
    }

    func step() throws -> Int {
        let opcode = mmu.read(address: pc)
        let info = try executeInstruction(opcode: opcode,
                                      byte: mmu.read(address: pc + 1),
                                      word: rWM(address: pc + 1))
        pc += UInt16(info.size)
        return info.cycles
    }

    func executeInstruction(opcode: UInt8, byte: UInt8, word: UInt16) throws -> (size: Int, cycles: Int) {
            switch opcode {
            case 0x00:
                // NOP
                return (1, 4)
            case 0x01:
                // LD BC, d16
                wWR(b, c, word: word)
                return (3, 12)
            case 0x03:
                // INC BC
                wWR(b, c, word: rWR(b, c) + 1)
                return (1, 8)
            case 0x04, 0x05, 0x0C, 0x0D,
                 0x14, 0x15, 0x1C, 0x1D,
                 0x24, 0x25, 0x2C, 0x2D,
                 0x34, 0x35, 0x3C, 0x3D:
                // INC/DEC R
                return incDecR(opcode: opcode);
            case 0x0B:
                // DEC BC
                wWR(b, c, word: rWR(b, c) - 1)
                return (1, 8)
            case 0x11:
                wWR(d, e, word: word)
                return (3, 12)
            case 0x13:
                // INC DE
                wWR(d, e, word: rWR(d, e) + 1)
                return (1, 8)
            case 0x06, 0x0E, 0x16, 0x1E, 0x26, 0x2E, 0x36, 0x3E:
                // LD R, d8
                return ldR8(opcode: opcode, byte: byte)
            case 0x17:
                // RLA
                // Call the equivalent CB instruction but with a lower cycle cost
                let _ = cb(opcode: 0x17)
                return (1, 4)
            case 0x18, 0x20, 0x28, 0x30, 0x38:
                // JR
                return jr(opcode: opcode, byte: byte)
            case 0x1A:
                // LD A, (DE)
                r[a] = mmu.read(address: rWR(d, e))
                return (1, 8)
            case 0x21:
                // LD HL, d16
                wWR(h, l, word: word)
                return (3, 12)
            case 0x22:
                // LD (HL+), A
                mmu.write(address: rWR(h, l), value: r[a])
                wWR(h, l, word: rWR(h, l) + 1)
                return (1, 8)
            case 0x23:
                // INC HL
                wWR(h, l, word: rWR(h, l) + 1)
                return (1, 8)
            case 0x2A:
                // LD A, (HL+)
                r[a] = mmu.read(address: rWR(h, l))
                wWR(h, l, word: rWR(h, l) + 1)
                return (1, 8)
            case 0x2F:
                // CPL
                r[a] = ~r[a]
                setFlag(.h)
                setFlag(.n)
                return (1, 4)
            case 0x31:
                // LD SP, d16
                sp = word
                return (3, 12)
            case 0x32:
                // LD (HL-), A
                let addr = rWR(h, l)
                let v = r[a]
                mmu.write(address: addr, value: v)
                wWR(h, l, word: rWR(h, l) - 1)
                return (1, 8)
            case 0x33:
                // INC SP
                sp += 1
                return (1, 8)
            // 0x40 - 0x7f (without 0x76)
            case 0x40, 0x41, 0x42, 0x43, 0x44, 0x45,
                 0x46, 0x47, 0x48, 0x49, 0x4A, 0x4B,
                 0x4C, 0x4D, 0x4E, 0x4F, 0x50, 0x51,
                 0x52, 0x53, 0x54, 0x55, 0x56, 0x57,
                 0x58, 0x59, 0x5A, 0x5B, 0x5C, 0x5D,
                 0x5E, 0x5F, 0x60, 0x61, 0x62, 0x63,
                 0x64, 0x65, 0x66, 0x67, 0x68, 0x69,
                 0x6A, 0x6B, 0x6C, 0x6D, 0x6E, 0x6F,
                 0x70, 0x71, 0x72, 0x73, 0x74, 0x75,
                 0x77, 0x78, 0x79, 0x7A, 0x7B,
                 0x7C, 0x7D, 0x7E, 0x7F:
                // LD R1, R2
                return ldR1R2(opcode: opcode)
            case 0x80...0x9F, 0xB8...0xBF,
                 0xC6, 0xD6, 0xE6, 0xF6,
                 0xCE, 0xDE, 0xEE, 0xFE:
                // ADD, ADC, SUB, SBC, CP
                return addSubCp(opcode: opcode, byte: byte)
            case 0xA0...0xB7:
                // AND, XOR, OR
                return bitwise(opcode: opcode)
            case 0xAF:
                // XOR A
                r[f] = 0
                r[a] = 0
                setFlag(.z)
                return (1, 4)
            case 0xC1:
                // POP BC
                wWR(b, c, word: rWM(address: sp))
                sp += 2
                return (1, 12)
            case 0xC3:
                // JP a16
                pc = word - 3
                return (3, 16)
            case 0xC5:
                // PUSH BC
                sp -= 2
                wWM(address: sp, word: rWR(b, c))
                return (1, 16)
            case 0xC9:
                // RET
                pc = rWM(address: sp) - 1
                sp += 2
                return (1, 16)
            case 0xCB:
                // CB prefix instructions
                let info = cb(opcode: byte)
                return (info.size + 1, info.cycles)
            case 0xCD:
                // CALL a16
                wWM(address: sp - 2, word: pc + 3)
                sp -= 2
                pc = word - 3
                return (3, 24)
            case 0xE0:
                // LDH (a8), A
                mmu.write(address: 0xFF00 + UInt16(byte), value: r[a])
                return (2, 12)
            case 0xE2:
                // LDH (C), A
                mmu.write(address: 0xFF00 + UInt16(r[c]), value: r[a])
                return (1, 8)
            case 0xEA:
                // LD (a16), A
                mmu.write(address: word, value: r[a])
                return (3, 16)
            case 0xF0:
                // LDH A, (a8)
                r[a] = mmu.read(address: 0xFF00 + UInt16(byte))
                return (2, 12)
            case 0xF3:
                // DI
                // TODO: When implementing interrupts
                return (1, 4)
            case 0xFA:
                // LD A, (a16)
                r[a] = mmu.read(address: word)
                return (3, 16)
            case 0xFB:
                // EI
                // TODO: When implementing interrupts
                return (1, 4)
            default:
                throw CPUError.notImplementedInstruction(opcode: opcode, pc: pc)
            }
    }

    // MARK: - Instruction Implementation

    func incDecR(opcode: UInt8) -> (size: Int, cycles: Int) {
        let decrement = (opcode & 0x01) == 0x01
        let reg = Int((opcode & 0x38) >> 3)
        // (HL) instead of register
        let useHL = reg == 6

        decrement ? setFlag(.n) : resetFlag(.n)

        var original: UInt8
        var final: UInt8

        if (useHL) {
            original = mmu.read(address: rWR(h, l))

            if decrement {
                final = original - 1
                mmu.write(address: rWR(h, l),
                          value: final)
            } else {
                final = original + 1
                mmu.write(address: rWR(h, l),
                          value: final)
            }
        } else {
            original = r[reg]

            if (decrement) {
                r[reg] &-= 1
            } else {
                r[reg] += 1
            }

            final = r[reg]
        }

        if hasNibbleOverflow(v1: original, v2: 1, sub: decrement) {
            setFlag(.h)
        } else {
            resetFlag(.h)
        }

        final == 0 ? setFlag(.z) : resetFlag(.z)

        return (1, useHL ? 12 : 4)
    }

    func ldR8(opcode: UInt8, byte: UInt8) -> (size: Int, cycles: Int) {
        let reg = Int((opcode & 0x38) >> 3)
        let ptrDestination = reg == 6
        if (ptrDestination) {
            mmu.write(address: rWR(h, l), value: byte)
        } else {
            r[reg] = byte
        }
        return (2, ptrDestination ? 12 : 8)
    }

    func jr(opcode: UInt8, byte: UInt8) -> (size: Int, cycles: Int) {
        var jump = false
        switch opcode {
        case 0x18:
            // JR r8
            jump = true;
            break;
        case 0x20:
            // JR NZ, r8
            jump = !flag(.z);
            break;
        case 0x30:
            // JR NC, r8
            jump = !flag(.c);
            break;
        case 0x28:
            // JR Z, r8
            jump = flag(.z);
            break;
        case 0x38:
            // JR C, r8
            jump = flag(.c);
            break;
        default:
            // The method is never called with an invalid opcode
            fatalError("The JR CPU method got called with an opcode that is not a JR instruction")
        }
        if jump {
            pc = UInt16(Int16(pc) + Int16(unsignedToSigned(byte)))
            return (2, 12)
        } else {
            return (2, 8)
        }
    }

    func ldR1R2(opcode: UInt8) -> (size: Int, cycles: Int) {
        let r1 = Int((opcode & 0x38) >> 3)
        let r2 = Int(opcode & 0x07)
        // If true, the source is not a register, it is (HL)
        let ptrSource = r2 == 6
        // If true, the destination is not a register, it is (HL)
        let ptrDestination = r1 == 6
        // Handles whether the source is a register of (HL)
        let value = ptrSource ? mmu.read(address: rWR(h, l)) : r[r2]
        // Handles whether the destination is a register of (HL)
        if (ptrDestination) {
            mmu.write(address: rWR(h, l), value: value)
        } else {
            r[r1] = value;
        }
        // Register source & destination -> 4 cycles
        // Either source or destination is (HL) -> 8 cycles
        let cycles = ptrSource || ptrSource ? 8 : 4
        return (1, cycles)
    }

    func addSubCp(opcode: UInt8, byte: UInt8) -> (size: Int, cycles: Int) {
        var op = opcode
        var writeOutput = true

        // Turn the CP into a SUB but ignore the output
        // CP
        if opcode & 0xB8 == 0xB8 {
            op = (opcode & 0x07) + 0x90
            writeOutput = false
        }
        // CP d8
        if opcode == 0xFE {
            op = 0xD6
            writeOutput = false
        }

        r[f] = 0
        // Is it a substraction
        let sub = op & 0x10 == 0x10
        // Does it consider the carry
        let carry = op & 0x80 == 0x80
        // The input register
        let register = Int(op & 0x07)
        // The input is an immediate value instead of a register
        let immediate = op & 0x40 == 0x40
        // Is it using (HL) as input instead of a register
        let useHL = register == 6

        var input = useHL ? mmu.read(address: rWR(h, l)) : r[register]
        input = immediate ? byte : input

        // Invert the input if it is a substraction
        input = sub ? ~input &+ 1 : input
        var output = r[a] &+ input
        // Add the carry if necessary
        output += carry && flag(.c) ? 1 : 0

        if output == 0 {
            setFlag(.z)
        }
        if sub {
            setFlag(.n)
        }
        if hasNibbleOverflow(v1: r[a], v2: input) {
            setFlag(.h)
        }
        if (Int(r[a]) + Int(input) > 255) {
            setFlag(.c)
        }

        if writeOutput {
            r[a] = output
        }

        return (immediate ? 2 : 1, useHL ? 8 : 4)
    }

    func bitwise(opcode: UInt8) -> (size: Int, cycles: Int) {
        let register = Int(opcode & 0x7)
        let useHL = register == 6
        let input = useHL ? mmu.read(address: rWR(h, l)) : r[register]
        r[f] = 0
        switch opcode & 0xF8 {
        case 0xA0:
            // AND
            r[a] = r[a] & input
            setFlag(.h)
            break
        case 0xA8:
            // XOR
            r[a] = r[a] ^ input
            break
        case 0xB0:
            // OR
            r[a] = r[a] | input
            break
        default:
            fatalError("The cpu bitwise function got called with an opcode that is not a bitwise operation")
        }

        if (r[a] == 0) {
            setFlag(.z)
        } else {
            resetFlag(.z)
        }

        return (1, useHL ? 8 : 4)
    }

    func cb(opcode: UInt8) -> (size: Int, cycles: Int) {
        // TODO: Clean & split this function
        // The source register (used by all instructions)
        let register = Int(opcode & 0x07)
        // Position of the bit operations (used in BIT, SET, RES)
        let bit = 2 * ((opcode & 0x30) >> 4) + ((opcode & 0x08) >> 3)
        // Direction of the rotation (used in RLC, RRC, RR, RL, SLA, SRA, SRL)
        let right = (opcode & 0x08) == 0x08
        // Carry of the rotation (used in RLC, RRC, SLA, SRA, SRL)
        let carry = (opcode & 0x10) != 0x10
        // True if it is a shift instead of a rotation
        let shift = (opcode & 0x20) == 0x20
        var source = r[register]
        var cycles = 8
        // When the register F is selected, it actually means (HL) in asm code
        if register == 6 {
            cycles = 16
            source = mmu.read(address: rWR(h, l))
        }

        var result: Int;

        // SWAP
        if (opcode & 0xF8) == 0x20 {
            r[f] = 0 // Reset all flags
            result = ((Int(source) & 0xF0) >> 4) & ((Int(source) & 0x0F) << 4)
            if result == 0 {
                setFlag(.z)
            }
        }
        // RLC, RRC, RR, RL, SLA, SRA, SRL, BIT, RES, SET
        else {
            switch (opcode & 0xC0)
            {
            case 0x00:
                // RLC, RRC, RR, RL, SLA, SRA, SRL
                // Find the but that will be shifted/rotated out of the byte
                let extraBit = right ? source & 0x01 : (source & 0x80) >> 7
                // Shift the byte
                result = right ? Int(source) >> 1 : Int(source) << 1
                // Apply the carry to the other end of the byte if it is a rotation with carry
                if !shift && flag(.c) && !carry {
                    result |= Int(right ? 0x80 : 0x01)
                // Apply the extra bit to the other end of the byte if it is a rotation without carry
                } else if !shift && carry {
                    result |= Int(right ? extraBit * 0x80 : extraBit * 0x01)
                }
                // Special case for SRA where bit 7 keeps its value during the shift
                if shift && right && carry {
                    result |= Int(source & 0x80)
                }
                // Reset all flags
                r[f] = 0
                if extraBit == 1 {
                    setFlag(.c)
                }
                if result == 0 {
                    setFlag(.z)
                }
                break;
            case 0x40:
                // BIT X, R
                resetFlag(.n)
                resetFlag(.h)
                resetFlag(.z)
                if (source & (1 << bit)) == 0 {
                    setFlag(.z)
                }
                return (1, cycles);
            case 0x90:
                // RES X, R
                result = Int(source ^ (1 << bit));
                break;
            case 0xC0:
                // SET X, R
                result = Int(source | (1 << bit));
                break;
            default:
                result = 0
                break;
            }
        }
        // When the register F is selected, it actually means (HL) in asm code
        if (register == 6) {
            mmu.write(address: rWR(h, l), value: UInt8(result & 0xFF))
        } else {
            r[register] = UInt8(result & 0xFF)
        }
        return (1, cycles);
    }
}
