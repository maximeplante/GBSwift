//
//  PPU.swift
//  GBSwift
//
//  Created by Maxime Plante on 2019-05-25.
//  Copyright © 2019 Maxime Plante. All rights reserved.
//

import Foundation

class PPU : ReadWriteable {

    enum Color: UInt8 {
        case white = 0
        case lightGrey = 1
        case darkGrey = 2
        case black = 3
    }

    // General
    var displayOn: Bool
    // 0: tile data #0, 1: tile data #1
    var tileDataSelect: Int
    /* All the tiles are from 0x8000 to 0x97FF. The address of a tile in memory
     * is its index in the table * 16 + 0x8000. */
    var tileData: [Tile]
    // Raw representation of the memory for read/write operations
    var memory: [UInt8]

    // Window
    // 0: tile map #1, 1: tile map#2
    var wTileMapSelect: Int
    var displayWindow: Bool

    // Background
    var displayBackground: Bool
    // 0: tile map #1, 1: tile map#2
    var bgTileMapSelect: Int
    // Contains the four colors of the background palette
    var bgPalette: [Color]
    /* Store tile maps #0 and #1 one after the other. Index 0 is the tile at
     * 0x9800 and index 2047 is the tile at 0x9FFF. The value in the array are
     * the indexes of the tile in the internal tileData array. The indexes
     * written to memory by the CPU are converted to indexes of the internal
     * tileData array when written. */
    var bgTileMap: [Int]

    // Sprite
    var largeSprites: Bool
    var displaySprites: Bool

    // Raster
    enum RasterMode: Int {
        case hblank = 0
        case vblank = 1
        case oam = 2
        case vram = 3
    }
    var rasterMode: RasterMode
    var rasterClock: Int
    var rasterLine: Int

    // Screen
    var scrollX: UInt8
    var scrollY: UInt8

    var screenDelegate: PPUScreenDelegate?

    init() {
        displayBackground = false
        largeSprites = false
        displaySprites = false
        wTileMapSelect = 0
        displayWindow = false
        bgTileMapSelect = 0
        tileDataSelect = 0
        bgPalette = [.white, .lightGrey, .darkGrey, .black]

        displayOn = false
        tileData = [Tile]()
        for _ in 0..<385 {
            tileData.append(Tile())
        }

        bgTileMap = [Int](repeating: 0, count: 2 * 32 * 32)

        memory = [UInt8](repeating: 0, count: 65536)

        rasterLine = 0
        rasterClock = 0
        rasterMode = RasterMode.hblank

        scrollX = 0
        scrollY = 0
    }

    func reset() {
        bgTileMapSelect = 0
        tileDataSelect = 0
        bgPalette = [.white, .lightGrey, .darkGrey, .black]

        displayOn = false
        tileData = [Tile]()
        for _ in 0..<385 {
            tileData.append(Tile())
        }

        bgTileMap = [Int](repeating: 0, count: 2 * 32 * 32)

        memory = [UInt8](repeating: 0, count: 65536)

        rasterLine = 0
        rasterClock = 0
        rasterMode = RasterMode.hblank

        scrollX = 0
        scrollY = 0
    }

    // MARK: - Raster

    func step(cpuCyclesDelta: Int) {
        rasterClock += cpuCyclesDelta

        /* Code heavily inspired from
         * http://imrannazar.com/GameBoy-Emulation-in-JavaScript:-GPU-Timings */
        switch rasterMode {
        case .oam:
            if rasterClock >= 80 {
                rasterClock = rasterClock - 80
                rasterMode = .vram
            }
            break
        case .vram:
            if rasterClock >= 172 {
                rasterClock = rasterClock - 172
                rasterMode = .hblank
                display(line: rasterLine)
            }
            break
        case .hblank:
            if rasterClock >= 204 {
                rasterClock = rasterClock - 204
                rasterLine += 1
                if rasterLine == 143 {
                    rasterMode = .vblank
                } else {
                    rasterMode = .oam
                }
            }
        case .vblank:
            if rasterClock >= 456 {
                rasterClock = rasterClock - 456
                rasterLine += 1

                if (rasterLine > 153) {
                    screenDelegate?.drawScreen()
                    rasterMode = .oam
                    rasterLine = 0
                }
            }
        }
    }

    func display(line screenY: Int) {
        let bgY = (screenY + Int(scrollY)) & 0xFF
        for screenX in 0..<160 {
            if (displayBackground) {
                let bgX = (screenX + Int(scrollX)) & 0xFF
                var tileMapIndex = ((bgY & 0xF8) >> 3) * 32 + ((bgX & 0xF8) >> 3)
                tileMapIndex += bgTileMapSelect == 0 ? 0 : 256
                let tileIndex = bgTileMap[Int(tileMapIndex)]
                let tile = tileData[tileIndex]
                let yInTile = bgY % 8
                let xInTile = bgX % 8
                let relativeColor = tile.pixels[yInTile][xInTile]
                let color = bgPalette[relativeColor]
                screenDelegate?.setPixel(x: screenX, y: screenY, color: color)
            }
        }
    }

    // MARK: - ReadWriteable

    func read(address: UInt16) -> UInt8 {
        switch address {
        case 0xFF42:
            // SCY
            return scrollY
        case 0xFF44:
            // LY
            return UInt8(rasterLine)
        default:
            return memory[Int(address)]
        }
    }

    func write(address: UInt16, value: UInt8) {
        memory[Int(address)] = value

        switch address {
        case 0x8000...0x97FF:
            // Tile Data
            updateTileData(fromByteAtAddress: address)
            break
        case 0x9800...0x9FFF:
            // Tile Map #0 and #1
            updateTileMap(fromByteAtAddress: address)
            break
        case 0xFF40:
            // LCDC
            updateLCDC(withValue: value)
            break
        case 0xFF42:
            // SCY
            scrollY = value
            break
        case 0xFF44:
            // Ignore writes to LY
            break
        case 0xFF47:
            // BGP
            bgPalette[0] = Color(rawValue: (value & 0x03))!
            bgPalette[1] = Color(rawValue: ((value & 0x0C) >> 2))!
            bgPalette[2] = Color(rawValue: ((value & 0x30) >> 4))!
            bgPalette[3] = Color(rawValue: ((value & 0xC0) >> 6))!
            break
        default:
            /* This mean that somehow the MMU gaves us an address that does not map
             * to anything in the PPU. */
            // fatalError()
            break
        }
    }

    // MARK: - General Registers

    func updateLCDC(withValue value: UInt8) {
        displayOn = value & 0x80 == 0x80
        wTileMapSelect = Int(value & 0x40) >> 6
        displayWindow = value & 0x40 == 0x40
        tileDataSelect = Int(value & 0x10) >> 4
        bgTileMapSelect = Int(value & 0x08) >> 3
        largeSprites = value & 0x04 == 0x04
        displaySprites = value & 0x02 == 0x02
        displayBackground = value & 0x01 == 0x01
    }

    // MARK: - Background Tile Map

    func updateTileMap(fromByteAtAddress address: UInt16) {
        // From which tile map is this byte in
        let tileDataIndex = internalTileDataIndex(fromIndex: memory[Int(address)])
        bgTileMap[Int(address) - 0x9800] = tileDataIndex
    }

    // Convert a value in the tile map to the internal index of the tileData
    func internalTileDataIndex(fromIndex index: UInt8) -> Int {
        if tileDataSelect == 0 {
            return Int(index)
        } else {
            let signedIndex = Int8(bitPattern: index)
            return 256 + Int(signedIndex)
        }
    }

    // MARK: - Tile Data

    /* Updates the internal representation of a tile by reading the byte at the
     * given address. */
    func updateTileData(fromByteAtAddress address: UInt16) {
        let tileStartAddress = address & 0xFFF0
        let lineStartAddress = address & 0xFFFE
        let lineNumber = Int((lineStartAddress - tileStartAddress) / 2)
        let tile = tileData[tileDataIndex(atAddress: tileStartAddress)]
        let firstByte = memory[Int(lineStartAddress)]
        let secondByte = memory[Int(lineStartAddress + 1)]

        for i in 0..<8 {
            let colorIndex = (Int((firstByte) & (0x1 << i)) >> i)
                + (Int(secondByte & (0x1 << i)) >> (i - 1))
            tile.pixels[lineNumber][7 - i] = Int(colorIndex)
        }
    }

    /* Compute the index of a tile in the tile data array from its address.
     * The address does not have to be at the start of the tile. The function
     * will round down the address to the closest tile. */
    func tileDataIndex(atAddress address: UInt16) -> Int {
        return Int(((address % 0xFFF0) - 0x8000) / 16)
    }
}

class Tile {
    // The integer stores the index of the color in the palette
    var pixels: [[Int]]

    init() {
        pixels = [[Int]]()
        for _ in 0..<8 {
            pixels.append([Int](repeating: 0, count: 8))
        }
    }
}

protocol PPUScreenDelegate {
    func setPixel(x: Int, y: Int, color: PPU.Color)
    func drawScreen()
}
