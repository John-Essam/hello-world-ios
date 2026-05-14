//
//  TCB02Command.swift
//  TCBleComminucation
//
//  Created by yifei on 2024/12/19.
//  Copyright © 2024 Changzhou Taochen. All rights reserved.
//

import Foundation

/// Controller status - query/set 0x0002
public struct TCB02Command {
    
    // MARK: - set command

    /// connect/disconnect device command
    /// - Parameters:
    ///   - on: connect/disconnect
    ///   - userID: userID
    ///   - isReset: reset  user info flag
    /// - Returns: cmd data
    public static func writeConnect(on: Bool, userID: UInt32 = 0, isReset: Bool = false) throws -> Data {
        var data = meterWriteHeader
        data[4] = data[4] + 4
        if isReset {
            data += [0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
        } else {
            if on {
                data.append(0b01000000)
            } else {
                data.append(0b00000000)
            }
            data.append(0b01000000)
            data += userID.bytes()
        }
        let crc16 = try TCBCRC16.create(data)
        data += crc16
        TCBLogger.onLog(data.toHexString())
        return Data(bytes: data, count: data.count)
    }
    
    /// set km mile
    /// - Parameter isKM: km: true, mile: false
    /// - Returns: cmd data
    public static func writeMetricMileSystemTheme(isKM: Bool) throws -> Data {
        var data = meterWriteHeader
        if isKM {
            data.append(0b00000000)
        } else {
            data.append(0b10000000)
        }
        data.append(0b10000000)
        let crc16 = try TCBCRC16.create(data)
        data += crc16
        TCBLogger.onLog(data.toHexString())
        return Data(bytes: data, count: data.count)
    }
    
    /// Set kick start
    /// - Parameter zeroStart: true: zero start, false: none-zero
    /// - Returns: cmd data
    public static func writeStartMode(zeroStart: Bool) throws -> Data {
        
        var data = meterWriteHeader
        if zeroStart {
            data.append(0b00000000)
        } else {
            data.append(0b00000010)
        }
        data.append(0b00000010)
        let crc16 = try TCBCRC16.create(data)
        data += crc16
        TCBLogger.onLog(data.toHexString())
        return Data(bytes: data, count: data.count)
    }
    
    /// Set cruise
    ///  - Parameter status: true: on, false: off
    /// - Returns: cmd data
    public static func writeCruiseControlFunction(status: Bool) throws -> Data {
        
        var data = meterWriteHeader
        if status {
            data.append(0b00000100)
        } else {
            data.append(0b00000000)
        }
        data.append(0b00000100)
        let crc16 = try TCBCRC16.create(data)
        data += crc16
        TCBLogger.onLog(data.toHexString())
        return Data(bytes: data, count: data.count)
    }
    
    /// Set lock/unclok
    /// - Parameter on: true:  lock, false:  unlock
    /// - Returns: cmd data
    public static func writeLockStatus(status: Bool) throws -> Data {
        var data = meterWriteHeader
        if status {
            data.append(0b00000001)
        } else {
            data.append(0b00000000)
        }
        data.append(0b00000001)
        let crc16 = try TCBCRC16.create(data)
        data += crc16
        TCBLogger.onLog(data.toHexString())
        let resultData = Data(bytes: data, count: data.count)
        return resultData
    }
    
    // MARK: - get command
    
    /// read connect info
    /// - Returns: cmd data
    public static func readUnbind() throws -> Data {
        var data = meterReadHeader
        data.append(0b00000000)
        data.append(0b01000000)
        let crc16 = try TCBCRC16.create(data)
        data += crc16
        TCBLogger.onLog(data.toHexString())
        return Data(bytes: data, count: data.count)
    }
    
}

extension TCB02Command: TCBCommandType {
    static let cmd: TCBFunctionCode = .cmd02
}

extension TCB02Command: TCBCommands {
    typealias CMD = Self
}
