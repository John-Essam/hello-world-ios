//
//  TCB0ACommand.swift
//  TCBleComminucation
//
//  Created by yifei on 2024/12/20.
//  Copyright © 2024 Changzhou Taochen. All rights reserved.
//

import Foundation

/// Temperature query
public struct TCB0ACommand {
    
    /// Get  controller temperature
    /// - Returns: cmd data
    public static func readTemp() throws -> Data {
        var data: [UInt8] = []
        data.append(TCBDeviceType.control.tempValue)
        return try assemble(header: controllerReadHeader, content: data)
    }
}

extension TCB0ACommand: TCBCommandType {
    static let cmd: TCBFunctionCode = .cmd0A
}

extension TCB0ACommand: TCBCommands {
    typealias CMD = Self
}
