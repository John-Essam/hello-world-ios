//
//  TCBE2Command.swift
//  TCBleComminucation
//
//  Created by yifei on 2024/12/20.
//  Copyright © 2024 Changzhou Taochen. All rights reserved.
//

import Foundation

/// Upgrade verification/upgrade completion response 0x00E2
public struct TCBE2Command {

    /// Send  CRC32 data
    /// - Parameters:
    ///   - type: response/meter
    ///   - data: crc32 data
    /// - Returns: cmd data
    public static func readUpgradeCompletionResponse(type: TCBDeviceType,
                                                     data: [UInt8]) throws -> Data {
        var header: [UInt8] = []
        switch type {
        case .control:
            header = controllerWriteHeader
        case .meter:
            header = meterWriteHeader
        default:
            TCBLogger.onLog("\(type.header)")
        }
        return try assemble(header: header, content: data)
    }
}

extension TCBE2Command: TCBCommandType {
    static let cmd: TCBFunctionCode = .cmdE2

}

extension TCBE2Command: TCBCommands {
    typealias CMD = Self
}
