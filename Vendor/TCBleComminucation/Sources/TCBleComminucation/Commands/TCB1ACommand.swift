//
//  TCB1ACommand.swift
//  TCBleComminucation
//
//  Created by yifei on 2024/12/20.
//  Copyright © 2024 Changzhou Taochen. All rights reserved.
//

import Foundation

/// Colorful light setting
public struct TCB1ACommand {
    
    /// Get  ambient light color
    /// - Returns: cmd data
    public static func readAmbientLight() throws -> Data {
        return try assemble(header: controllerReadHeader, content: [])
    }
    
    /// Set ambient light color
    /// - Parameters:
    ///   - type: ambilece mode:
    ///     - 1(monochrome)
    ///     - 2(monochrome breathing)
    ///     - 3(magic seven colors)
    ///   - R: Red
    ///   - G: Green
    ///   - B: Blue
    /// - Returns: cmd data
    public static func writeAmbientLight(type: Int, R: Int, G: Int, B: Int) throws -> Data {
        var data: [UInt8] = []
        // mode
        data.append(UInt8(type))
        // red
        data.append(UInt8(R))
        // grren
        data.append(UInt8(G))
        // blue
        data.append(UInt8(B))
        // lightness
        data.append(0xFF)
        return try assemble(header: controllerWriteHeader, content: data)
    }
    
    
}

extension TCB1ACommand: TCBCommandType {
    static let cmd: TCBFunctionCode = .cmd1A
}

extension TCB1ACommand: TCBCommands {
    typealias CMD = Self
}
