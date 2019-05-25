//
//  PPU.swift
//  GBSwift
//
//  Created by Maxime Plante on 2019-05-25.
//  Copyright © 2019 Maxime Plante. All rights reserved.
//

import Foundation

class PPU : ReadWriteable {

    public enum Color {
        case white
        case lightGrey
        case darkGrey
        case black
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

    // Background
    // 0: tile map #1, 1: tile map#2
    var bgTileMapSelect: Int
    // Contains the four colors of the background palette
    var bgPalette: [Color]
    /* bgTileMaps[0]: tile map #0, bgTileMaps[1]: tile map #1
     * The tile map contains the index in the TileData array of the tile to
     * be displayed. The indexes are converted when the tile data is switched
     * between #0 and #1. */
    var bgTileMaps: [[Int]]

    var screenDelegate: PPUScreenDelegate?

    init() {
        bgTileMapSelect = 0
        tileDataSelect = 0
        bgPalette = [.white, .lightGrey, .darkGrey, .black]

        displayOn = false
        tileData = [Tile]()
        for _ in 0..<385 {
            tileData.append(Tile())
        }

        bgTileMaps = [[Int]]()
        bgTileMaps.append([Int](repeating: 0, count: 32 * 32))
        bgTileMaps.append([Int](repeating: 0, count: 32 * 32))

        memory = [UInt8](repeating: 0, count: 65536)
    }

    // MARK: - ReadWriteable

    func read(address: UInt16) -> UInt8 {
        return memory[Int(address)]
    }

    func write(address: UInt16, value: UInt8) {
        memory[Int(address)] = value

        switch address {
        case 0x8000...0x97FF:
            // Tile Data
            updateTileData(fromByteAtAddress: address)
            break
        default:
            /* This mean that somehow the MMU gaves us an address that does not map
             * to anything in the PPU. */
            fatalError()
            break
        }
    }

    // MARK: - Tile Data Management

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
            tile.pixels[lineNumber][i] = Int(colorIndex)
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
    public var pixels: [[Int]]

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
