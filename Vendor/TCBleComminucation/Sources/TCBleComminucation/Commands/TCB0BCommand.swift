//
//  TCB0BCommand.swift
//  TCBleComminucation
//
//  Created by yifei on 2024/12/20.
//  Copyright © 2024 Changzhou Taochen. All rights reserved.
//

import Foundation

/// Driving current
public struct TCB0BCommand {
    
    /// Get  current
    /// - Returns: cmd data
    public static func readDrivingCurrent() throws -> Data {
        var data: [UInt8] = []
        data.append(0x00)
        data.append(0x00)
        data.append(0x00)
        return try assemble(header: controllerReadHeader, content: data)
    }
}

extension TCB0BCommand: TCBCommandType {
    static let cmd: TCBFunctionCode = .cmd0B
}

extension TCB0BCommand: TCBCommands {
    typealias CMD = Self
}
