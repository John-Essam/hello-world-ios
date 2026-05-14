//
//  TCB09Command.swift
//  TCBleComminucation
//
//  Created by yifei on 2024/12/20.
//  Copyright © 2024 Changzhou Taochen. All rights reserved.
//

import Foundation

/// Total mileage
public struct TCB09Command {
    
    /// Get ODO
    /// - Returns: cmd data
    public static func readTotalTripMileage() throws -> Data {
        return try assemble(header: controllerReadHeader, content: [])
    }
}

extension TCB09Command: TCBCommandType {
    static let cmd: TCBFunctionCode = .cmd09
}

extension TCB09Command: TCBCommands {
    typealias CMD = Self
}
