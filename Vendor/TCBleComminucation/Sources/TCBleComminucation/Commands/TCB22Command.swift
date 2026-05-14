//
//  TCB22Command.swift
//  TCBleComminucation
//
//  Created by yifei on 2024/12/20.
//  Copyright © 2024 Changzhou Taochen. All rights reserved.
//

import Foundation

/// Response time query
public struct TCB22Command {
    
    /// Get  Response time query
    /// - 0: Throttle response: Adjustment range (0-10),
    /// - 1: Brake response: Adjustment range (0-10)
    /// - Returns: cmd data
    public static func readResponseTime(type: Int) throws -> Data {
        var data: [UInt8] = []
        data.append(UInt8(type))
        data.append(0x00)
        return try assemble(header: controllerReadHeader, content: data)
    }
    
    /// Set Response Time
    /// - Parameters:
    ///   - type: reponse type
    ///     - 0: Throttle response: Adjustment range (0-10),
    ///     - 1: Brake response: Adjustment range (0-10)
    ///   - time:  value
    /// - Returns: cmd data
    public static func writeResponseTime(type: Int,time: Int) throws -> Data {
        var data: [UInt8] = []
        data.append(UInt8(type))
        data.append(UInt8(time))
        return try assemble(header: controllerWriteHeader, content: data)
    }
}

extension TCB22Command: TCBCommandType {
    static let cmd: TCBFunctionCode = .cmd22
}

extension TCB22Command: TCBCommands {
    typealias CMD = Self
}
