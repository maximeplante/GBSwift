//
//  ScreenView.swift
//  GBSwift
//
//  Created by Maxime Plante on 2019-05-25.
//  Copyright © 2019 Maxime Plante. All rights reserved.
//

import Cocoa

class ScreenView: NSView {

    enum ScreenColor {
        case white
        case lightGrey
        case darkGrey
        case black
    }

    let screenWidth = 160
    let screenHeight = 144

    var screenLines: [[ScreenColor]]

    override init(frame frameRect: NSRect) {
        screenLines = [[ScreenColor]]()
        for _ in 0..<screenHeight {
            let pixelRow = Array(repeating: ScreenColor.white, count: screenWidth)
            screenLines.append(pixelRow)
        }

        super.init(frame: frameRect)
    }

    required init?(coder decoder: NSCoder) {
        screenLines = [[ScreenColor]]()
        for _ in 0..<screenHeight {
            let pixelRow = Array(repeating: ScreenColor.white, count: screenWidth)
            screenLines.append(pixelRow)
        }

        super.init(coder: decoder)
    }

    func setPixel(x: Int, y: Int, color: ScreenColor) {
        screenLines[y][x] = color
    }

    func redraw() {
        setNeedsDisplay(frame)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let ctx = NSGraphicsContext.current?.cgContext

        ctx?.saveGState()

        // Draw background
        ctx?.setFillColor(.white)
        ctx?.fill(CGRect(x: 0, y: 0, width: frame.width, height: frame.height))

        // Draw each pixel
        for y in 0..<screenHeight {
            for x in 0..<screenWidth {
                switch screenLines[y][x] {
                case .white:
                    continue
                case .lightGrey:
                    ctx?.setFillColor(CGColor(gray: 0.66, alpha: 1.0))
                    break
                case .darkGrey:
                    ctx?.setFillColor(CGColor(gray: 0.33, alpha: 1.0))
                    break
                case .black:
                    ctx?.setFillColor(.black)
                    break
                }
                ctx?.fill(generatePixelCGRect(x: x, y: y))
            }
        }

        ctx?.restoreGState()
    }

    func generatePixelCGRect(x: Int, y: Int) -> CGRect {
        let pixelWidth = CGFloat(frame.width) / CGFloat(screenWidth)
        let pixelHeight = CGFloat(frame.height) / CGFloat(screenHeight)
        let viewY = CGFloat(screenHeight - y - 1) * pixelHeight
        return CGRect(x: CGFloat(x) * pixelWidth , y: viewY, width: CGFloat(pixelWidth), height: CGFloat(pixelHeight))
    }
}
