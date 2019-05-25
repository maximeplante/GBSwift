//
//  PPU.swift
//  GBSwift
//
//  Created by Maxime Plante on 2019-05-25.
//  Copyright © 2019 Maxime Plante. All rights reserved.
//

import Foundation

class PPU {
    public enum Color {
        case white
        case lightGrey
        case darkGrey
        case black
    }

    var screenDelegate: PPUScreenDelegate?
    
}

protocol PPUScreenDelegate {
    func setPixel(x: Int, y: Int, color: PPU.Color)
}
