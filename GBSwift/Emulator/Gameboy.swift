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

    public init(cpu: CPU, mmu: MMU) {
        self.cpu = cpu
        self.mmu = mmu
    }

    public func reset() {
        mmu.reset()
        cpu.reset()
    }

    public func step() throws {
        try cpu.step()
    }
}
