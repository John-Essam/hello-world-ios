//
//  TCB03Command.swift
//  TCBleComminucation
//
//  Created by yifei on 2024/12/20.
//  Copyright © 2024 Changzhou Taochen. All rights reserved.
//

import Foundation

/// Parameter configuration
public struct TCB03Command {
    
    /// Get  NFC ON/OFF
    /// - Returns: cmd data
    public static func readNfcStatus() throws -> Data {
        var data: [UInt8] = []
        data.append(0x00)
        data.append(0b00010000)
        return try assemble(header: meterReadHeader, content: data)
    }
    
    /// Set NFC Status
    /// - Parameter status: true: ON, false: OFF
    /// - Returns: cmd data
    public static func writeNfcStatus(_ status: Bool) throws -> Data {
        var data: [UInt8] = []
        if status {
            data.append(0b00010000)
        } else {
            data.append(0x00)
        }
        data.append(0b00010000)
        return try assemble(header: meterReadHeader, content: data)
    }
}

extension TCB03Command: TCBCommandType {
    static let cmd: TCBFunctionCode = .cmd03
}

extension TCB03Command: TCBCommands {
    typealias CMD = Self
}
