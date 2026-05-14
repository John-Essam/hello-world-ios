//
//  TCB08Command.swift
//  TCBleComminucation
//
//  Created by yifei on 2024/12/20.
//  Copyright © 2024 Changzhou Taochen. All rights reserved.
//

import Foundation

/// Single mileage
public struct TCB08Command {
    
    /// Get Trip mileage
    /// - Returns: cmd data
    public static func readSingleTripMileage() throws -> Data {
        return try assemble(header: controllerReadHeader, content: [])
    }
}

extension TCB08Command: TCBCommandType {
    static let cmd: TCBFunctionCode = .cmd08
}

extension TCB08Command: TCBCommands {
    typealias CMD = Self
}
