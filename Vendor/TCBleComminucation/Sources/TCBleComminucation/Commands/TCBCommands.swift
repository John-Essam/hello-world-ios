//
//  TCBCommands.swift
//  TCBleComminucation
//
//  Created by yifei on 2024/12/19.
//  Copyright © 2024 Changzhou Taochen. All rights reserved.
//

import Foundation

protocol TCBCommandType {
    
    static var cmd: TCBFunctionCode { get }
}

protocol TCBCommands<CMD> {
    
    associatedtype CMD: TCBCommandType
    
    static var meterWriteHeader: [UInt8] { get }
    
    static var controllerWriteHeader: [UInt8] { get }
    
    static var meterReadHeader: [UInt8] { get }
    
    static var controllerReadHeader: [UInt8] { get }
 
    static func assemble(header: [UInt8], content: [UInt8]) throws -> Data
}

extension TCBCommands {
    
    static var controllerReadHeader: [UInt8] {
        return [TCBConstant.frameHeader, TCBCMDHeader.controllerRead.value,
                CMD.cmd.headerLowByte, CMD.cmd.headerHighByte,
                CMD.cmd.cmdDataLength]
    }
    
    static var controllerWriteHeader: [UInt8] {
        return [TCBConstant.frameHeader,
                TCBCMDHeader.controllerWrite.value,
                CMD.cmd.headerLowByte,
                CMD.cmd.headerHighByte,
                CMD.cmd.cmdDataLength]
    }
    
    static var meterWriteHeader: [UInt8] {
        return [TCBConstant.frameHeader,
                TCBCMDHeader.meterWrite.value,
                CMD.cmd.headerLowByte,
                CMD.cmd.headerHighByte,
                CMD.cmd.cmdDataLength]
    }
    
    static var meterReadHeader: [UInt8] {
        return [TCBConstant.frameHeader,
                TCBCMDHeader.meterRead.value,
                CMD.cmd.headerLowByte,
                CMD.cmd.headerHighByte,
                CMD.cmd.cmdDataLength]
    }
    
    static func assemble(header: [UInt8], content: [UInt8]) throws -> Data {
        var data = header
        data += content
        let crc16 = try TCBCRC16.create(data)
        data += crc16
        TCBLogger.onLog(data.toHexString())
        return Data(bytes: data, count: data.count)
    }
}
