//
//  TCB30Commnad.swift
//  TCBleComminucation
//
//  Created by yifei on 2024/12/20.
//  Copyright © 2024 Changzhou Taochen. All rights reserved.
//

import Foundation

/// Range mileage
public struct TCB30Command {
    
    /// Get Range mileage
    /// - Returns: cmd data
    public static func readRemainingMileage() throws -> Data {
        return try assemble(header: controllerReadHeader, content: [])
    }
}

extension TCB30Command: TCBCommandType {
    static let cmd: TCBFunctionCode = .cmd30
}

extension TCB30Command: TCBCommands {
    typealias CMD = Self
}
