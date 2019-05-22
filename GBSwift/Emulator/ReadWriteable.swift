//
//  ReadWriteable.swift
//  GBSwift
//
//  Created by Maxime Plante on 2019-05-19.
//  Copyright © 2019 Maxime Plante. All rights reserved.
//

import Foundation

protocol ReadWriteable {
    func read(address: UInt16) -> UInt8
    func write(address: UInt16, value: UInt8)
}
