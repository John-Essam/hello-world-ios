//
//  TCB11Command.swift
//  TCBleComminucation
//
//  Created by yifei on 2024/12/20.
//  Copyright © 2024 Changzhou Taochen. All rights reserved.
//

import Foundation

/// Controller manufacturer code and software and hardware version -- query/set 0x0011
public struct TCB11Command {
    
    /// Get  meter version and code information
    /// - Returns: cmd data
    public static func readMeterVersion() throws -> Data {
        return try assemble(header: meterReadHeader, content: [])
    }
    
    /// Get  controller version and code information
    /// - Returns: cmd data
    public static func readControllerVersion() throws -> Data {
        return try assemble(header: controllerReadHeader, content: [])
    }
}

extension TCB11Command: TCBCommandType {
    static let cmd: TCBFunctionCode = .cmd11
}

extension TCB11Command: TCBCommands {
    typealias CMD = Self
}
