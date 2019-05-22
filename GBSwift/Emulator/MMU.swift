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
    public var bootRomVisile: Bool
    public var content: [UInt8]

    init(bootRom: ReadWriteable) {
        self.bootRom = bootRom
        bootRomVisile = true
        content = [UInt8].init(repeating: 0x00, count: 65536)
    }

    public func reset() {
        bootRomVisile = true
        content = [UInt8].init(repeating: 0x00, count: 65536)
    }

    func read(address: UInt16) -> UInt8 {
        let high = address & 0xFF00

        switch high {
        case 0x0000:
            if (bootRomVisile) {
                return bootRom.read(address: address)
            }
            return content[Int(address)]
        default:
            return content[Int(address)]
        }
    }

    func write(address: UInt16, value: UInt8) {
        // Ignored
    }

    public func readRange(offset: UInt16, length: UInt16) -> [UInt8] {
        var output = [UInt8]()
        for i in offset...offset + length - 1 {
            output.append(read(address: i))
        }
        return output
    }

}
