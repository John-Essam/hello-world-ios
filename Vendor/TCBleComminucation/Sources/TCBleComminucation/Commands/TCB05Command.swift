//
//  TCB05Command.swift
//  TCBleComminucation
//
//  Created by yifei on 2024/12/20.
//  Copyright © 2024 Changzhou Taochen. All rights reserved.
//

import Foundation

/// Gear speed -- query/set 0x0005
public struct TCB05Command {
    
    /// set drvie mode front and rear
    /// - Parameter isFrontAndRear: true: dual, false: rear
    /// - Returns: cmd data
    public static func writeDriveMode(isFrontAndRear: Bool) throws -> Data {
        var data: [UInt8] = []
        let onData: UInt8 = isFrontAndRear ? 0x02: 0x03
        data.append(onData | (0b110 << 3))
        data.append(0x00)
        return try assemble(header: meterWriteHeader, content: data)
    }
    
    /// Get drive mode
    /// - Returns: cmd data
    public static func readDriveMode() throws -> Data {
        var data: [UInt8] = []
        data.append(UInt8(0b110 << 3))
        data.append(0x00)
        return try assemble(header: meterReadHeader, content: data)
    }
    
    /// switch gear
    /// - Parameter gear: changed gear
    /// - Returns: cmd data
    public static func writeGear(_ gear: Int) throws -> Data {
        var speedData: [UInt8] = []
        let speedValue = UInt8(gear)
        speedData.append(UInt8(0b100 << 3) | speedValue)
        speedData.append(0x00)
        return try assemble(header: meterWriteHeader, content: speedData)
    }
    
    /// Get  default max speed of the gear
    /// - Parameter gear: gear
    /// - Returns: cmd data
    public static func readGearMaxSpeed(gear: Int) throws -> Data {
        var data: [UInt8] = []
        let speedValue = UInt8(gear)
        data.append(UInt8(0b011 << 3) | speedValue)
        data.append(0x00)
        return try assemble(header: controllerReadHeader, content: data)
    }
    
    /// Set max speed of gear
    /// - Parameters:
    ///   - gear: gear
    ///   - speed: max speed
    /// - Returns: cmd data
    public static func writeGearMaxSpeed(gear: Int, speed: Int) throws -> Data {
        var data: [UInt8] = []
        let gearValue = UInt8(gear)
        data.append(UInt8(0b011 << 3) | gearValue)
        data.append(UInt8(speed))
        return try assemble(header: controllerWriteHeader, content: data)
    }
    
    /// Get the avalialbe setting speed
    /// - Returns: cmd data
    public static func readMaxSpeed() throws -> Data {
        var data: [UInt8] = []
        data.append(0x00)
        data.append(0x00)
        return try assemble(header: controllerReadHeader, content: data)
    }
    
}

extension TCB05Command: TCBCommandType {
    static let cmd: TCBFunctionCode = .cmd05
}

extension TCB05Command: TCBCommands {
    typealias CMD = Self
}
