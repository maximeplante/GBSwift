//
//  ScreenWindowController.swift
//  GBSwift
//
//  Created by Maxime Plante on 2019-05-25.
//  Copyright © 2019 Maxime Plante. All rights reserved.
//

import Cocoa

class ScreenWindowController: NSWindowController, PPUScreenDelegate {

    @IBOutlet weak var screen: ScreenView!
    
    override func windowDidLoad() {
        super.windowDidLoad()

        window?.contentAspectRatio = NSSize(width: 160, height: 144)
        window?.title = "Screen"
    }

    public func setPixel(x: Int, y: Int, color: PPU.Color) {
        switch color {
        case .white:
            screen.setPixel(x: x, y: y, color: .white)
            break
        case .lightGrey:
            screen.setPixel(x: x, y: y, color: .lightGrey)
            break
        case .darkGrey:
            screen.setPixel(x: x, y: y, color: .darkGrey)
            break
        case .black:
            screen.setPixel(x: x, y: y, color: .black)
            break
        }
    }
}
