//
//  MMU.swift
//  GBSwift
//
//  Created by Maxime Plante on 2019-05-19.
//  Copyright © 2019 Maxime Plante. All rights reserved.
//

import Foundation

class MMU: ReadWriteable {

    public let bootRom: ReadWriteable
    public let ppu: PPU
    public var bootRomVisile: Bool
    public var content: [UInt8]

    // TODO: Remove once the boorom is fully tested
    public var logo: [UInt8] = [0xCE, 0xED, 0x66, 0x66, 0xCC, 0x0D, 0x00, 0x0B, 0x03, 0x73, 0x00, 0x83, 0x00, 0x0C, 0x00, 0x0D, 0x00, 0x08, 0x11, 0x1F, 0x88, 0x89, 0x00, 0x0E, 0xDC, 0xCC, 0x6E, 0xE6, 0xDD, 0xDD, 0xD9, 0x99, 0xBB, 0xBB, 0x67, 0x63, 0x6E, 0x0E, 0xEC, 0xCC, 0xDD, 0xDC, 0x99, 0x9F, 0xBB, 0xB9, 0x33, 0x3E]

    init(bootRom: ReadWriteable, ppu: PPU) {
        self.bootRom = bootRom
        self.ppu = ppu
        bootRomVisile = true
        content = [UInt8].init(repeating: 0x00, count: 65536)
    }

    public func reset() {
        bootRomVisile = true
        content = [UInt8].init(repeating: 0x00, count: 65536)
    }

    func read(address: UInt16) -> UInt8 {
        switch address {
        // TODO: Remove once the boorom is fully tested
        case 0x104...0x133:
            return logo[Int(address) - 0x104]
        case 0x0000...0x00FF:
            if (bootRomVisile) {
                return bootRom.read(address: address)
            }
            return content[Int(address)]
        case 0x8000...0x9FFF:
            return ppu.read(address: address)
        default:
            return content[Int(address)]
        }
    }

    func write(address: UInt16, value: UInt8) {
        // Keep the raw value
        content[Int(address)] = value

        switch address {
        case 0x8000...0x9FFF:
            ppu.write(address: address, value: value)
            break
        default:
            break
        }
    }

    public func readRange(offset: UInt16, length: UInt16) -> [UInt8] {
        var output = [UInt8]()
        for i in Int(offset)...Int(offset) + Int(length) - 1 {
            if i <= UInt16.max {
                output.append(read(address: UInt16(i)))
            }
        }
        return output
    }

}
