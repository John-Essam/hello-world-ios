//
//  TCB04Command.swift
//  TCBleComminucation
//
//  Created by yifei on 2024/12/19.
//  Copyright © 2024 Changzhou Taochen. All rights reserved.
//

import Foundation

/// Lighting control -- query/set 0x0004
public struct TCB04Command {

    // MARK: - set commnad
    
    /// Set Front light on/off
    /// - Parameter status: true: ON, false: OFF
    /// - Returns: light data
    public static func writeFrontLightStatus(_ status: Bool) throws -> Data {
        
        var data = meterWriteHeader
        if status {
            data.append(0b00100000)
        } else {
            data.append(0b00000000)
        }
        data.append(0b00100000)
        let crc16 = try TCBCRC16.create(data)
        data += crc16
        TCBLogger.onLog(data.toHexString())
        return Data(bytes: data, count: data.count)
    }
    
    /// Set ambience light ON/OFF
    /// - Parameter on: status: ON, false: OFF
    /// - Returns: light data
    public static func writeAmbientLightStatus(_ status: Bool) throws -> Data {
        var data = controllerWriteHeader
        if status {
            data.append(0b0001000)
        } else {
            data.append(0b00000000)
        }
        data.append(0b00001000)
        let crc16 = try TCBCRC16.create(data)
        data += crc16
        TCBLogger.onLog(data.toHexString())
        return Data(bytes: data, count: data.count)
    }
    
    // MARK: - get command
    
    /// Get ambience light ON/OFF
    /// - Returns: light status data
    public static func readAmbientLightStatus() throws -> Data {
        var data: [UInt8] = []
        data.append(0x00)
        data.append(0b00001000)
        return try assemble(header: controllerWriteHeader, content: data)
    }
}
    
extension TCB04Command: TCBCommandType {
    static let cmd: TCBFunctionCode = .cmd04
}

extension TCB04Command: TCBCommands {
    typealias CMD = Self
}
