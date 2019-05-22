//
//  BootRom.swift
//  GBSwift
//
//  Created by Maxime Plante on 2019-05-09.
//  Copyright © 2019 Maxime Plante. All rights reserved.
//

import Foundation

class BootRom : ReadWriteable {
    let content: [UInt8]

    public init(fromFile f:URL) {
        if let data = NSData(contentsOf: f) {
            var buffer = [UInt8](repeating: 0, count: data.length)
            data.getBytes(&buffer, length: data.length)
            content = buffer
        } else {
            // TODO: throw error
            content = [UInt8](repeating: 0, count: 256)
        }
    }

    public func read(address: UInt16) -> UInt8 {
        return content[Int(address)];
    }

    public func write(address: UInt16, value: UInt8) {
        // TODO: throw error
    }
}
