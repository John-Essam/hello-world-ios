//
//  TCBE0Command.swift
//  TCBleComminucation
//
//  Created by yifei on 2024/12/20.
//  Copyright © 2024 Changzhou Taochen. All rights reserved.
//

import Foundation

/// Query the upgrade conditions of the controller/meter
public struct TCBE0Command {
    
    /// Get  the upgrade conditions of the controller/meter
    /// - Returns: cmd data
    public static func readReadyToUpdate(type: TCBDeviceType) throws -> Data {
        var header: [UInt8] = []
        switch type {
        case .control:
            header = controllerReadHeader
        case .meter:
            header = meterReadHeader
        default:
            TCBLogger.onLog("\(type.header)")
        }
        return try assemble(header: header, content: [])
    }
}

extension TCBE0Command: TCBCommandType {
    static let cmd: TCBFunctionCode = .cmdE0
}

extension TCBE0Command: TCBCommands {
    typealias CMD = Self
}
