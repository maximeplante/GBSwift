//
//  Cartridge.swift
//  GBSwift
//
//  Created by Maxime Plante on 2019-05-31.
//  Copyright © 2019 Maxime Plante. All rights reserved.
//

import Foundation

class Cartridge: ReadWriteable {
    var romBanks: [RomBank]
    var selectedRomBank: Int
    var mbc: MBC

    enum MBC {
        case RomOnly
    }

    init(fromFile f: URL) {
        guard let data = NSData(contentsOf: f) else {
            fatalError()
        }

        // Setup the rom banks
        romBanks = [RomBank]()
        selectedRomBank = 1
        for i in 0...Int(ceil(Double(data.length) / Double(RomBank.romSize))) {
            romBanks.append(RomBank(withDataSource: data, offset: i * RomBank.romSize))
        }

        // Setup the Memory Bank Controller
        switch (romBanks[0].read(address: 0x147)) {
        case 0x00:
            mbc = .RomOnly
        default:
            fatalError()
        }
    }

    func read(address: UInt16) -> UInt8 {
        switch mbc {
        case .RomOnly:
            return readBanks(atAddress: address)
        }
    }

    func write(address: UInt16, value: UInt8) {
        switch mbc {
        case .RomOnly:
            return
        }
    }

    private func readBanks(atAddress address: UInt16) -> UInt8 {
        if (address < RomBank.romSize) {
            return romBanks[0].read(address: address)
        }
        return romBanks[selectedRomBank].read(address: address - UInt16(RomBank.romSize))
    }

}

class RomBank {
    static let romSize = 16384

    var content: [UInt8]

    init(withDataSource source: NSData, offset: Int) {
        content = [UInt8](repeating: 0, count: RomBank.romSize)
        source.getBytes(&content, range: NSRange(location: offset, length: min(RomBank.romSize, source.length - offset)))
    }

    func read(address: UInt16) -> UInt8 {
        return content[Int(address)]
    }
}
