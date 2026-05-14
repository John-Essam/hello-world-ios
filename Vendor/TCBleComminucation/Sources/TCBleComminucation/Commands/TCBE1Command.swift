//
//  TCBE1Command.swift
//  TCBleComminucation
//
//  Created by yifei on 2024/12/20.
//  Copyright © 2024 Changzhou Taochen. All rights reserved.
//

import Foundation

/// Transmit upgrade data packet/query receiving status 0x00E1
public struct TCBE1Command {

    /// Send upgrade data
    /// - Parameters:
    ///   - type: response/meter
    ///   - total: packet total number
    ///   - current: current data packet number
    ///   - data: packet data
    /// - Returns: cmd data
    public static func writeUpgradeDataPacket(type: TCBDeviceType, index: Int,
                                              data: [UInt8]) throws -> Data {
        var header: [UInt8] = []
        var packetIndex = index
        switch type {
        case .control:
            header = controllerWriteHeader
        case .meter:
            packetIndex += 1
            header = meterWriteHeader
        default:
            TCBLogger.onLog("\(type.header)")
        }
        let dataLength = data.count + 2
        header.append(UInt8(dataLength))
        
        var content: [UInt8] = UInt16(packetIndex).bytes()
        content += data
        return try assemble(header: header, content: content)
    }
}

extension TCBE1Command: TCBCommandType {
    static let cmd: TCBFunctionCode = .cmdE1
    
    static var controllerWriteHeader: [UInt8] {
        return [TCBConstant.frameHeader,
                TCBCMDHeader.controllerWrite.value,
                CMD.cmd.headerLowByte,
                CMD.cmd.headerHighByte]
    }
    
    static var meterWriteHeader: [UInt8] {
        return [TCBConstant.frameHeader,
                TCBCMDHeader.meterWrite.value,
                CMD.cmd.headerLowByte,
                CMD.cmd.headerHighByte]
    }
}

extension TCBE1Command: TCBCommands {
    typealias CMD = Self
}
