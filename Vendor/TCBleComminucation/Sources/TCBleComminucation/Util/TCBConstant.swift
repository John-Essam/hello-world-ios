//
//  TCBConstant.swift
//  TCBleComminucation
//
//  Created by yifei on 2024/12/11.
//  Copyright © 2024 Changzhou Taochen. All rights reserved.
//

import Foundation

public let TCBSDKVersion: String = "1.0.0"

/// device type of communication
public enum TCBDeviceType {
    /// controller
    case control
    /// battery
    case battery
    ///  Instrument
    case meter
    /// motor
    case motor
    
    public var header: UInt8 {
        switch self {
        case .control:
            return UInt8(0b0001)
        case .battery:
            return UInt8(0b0010)
        case .meter:
            return UInt8(0b0011)
        default:
            return 0
        }
    }
    
    public var tempValue: UInt8 {
        switch self {
        case .control:
            return UInt8(0x00)
        case .battery:
            return UInt8(0x01 << 4)
        case .motor:
            return UInt8(0x03 << 4)
        default:
            return 0
        }
    }
    
    public var upgradValue: UInt8 {
        switch self {
        case .control:
            return 0
        case .meter:
            return 1
        default:
            return 0xFF
        }
    }
}

/// Device identify
public enum TCBMachineType {
    /// sub device
    case sub
    /// main device
    case main
    
    public var header: UInt8 {
        switch self {
        case .sub:
            return UInt8(1 << 7)
        case .main:
            return 0
        }
    }
}

/// ble read write repponse authorization
public enum TCBBleAuth {
    /// only read
    case read
    /// write without response
    case writeNoResponse
    /// write and reponse
    case writeResponse
    /// only reponse
    case response
    
    public var header: UInt8 {
        switch self {
        case .read:
            return UInt8(0b0000 << 4)
        case .writeNoResponse:
            return UInt8(0b0001 << 4)
        case .writeResponse:
            return UInt8(0b0010 << 4)
        case .response:
            return UInt8(0b0011 << 4)
        }
    }
}

/// Comminucation Commands
public enum TCBFunctionCode: UInt8, CaseIterable {
    /// Heartbeat data interaction (recommended every 20ms) 0x0001
    case cmd01 = 0x01
    /// Controller status - query/set 0x0002
    case cmd02 = 0x02
    /// Parameter configuration - query / set 0x0003
    case cmd03 = 0x03
    /// Lighting control -- query / set 0x0004
    case cmd04 = 0x04
    /// Gear speed -- query / set 0x0005
    case cmd05 = 0x05
    /// Automatic shutdown time configuration -- query / set 0x0006
    case cmd06 = 0x06
    /// Real-time time -- query / set controller 0x0007
    case cmd07 = 0x07
    /// Single mileage - query controller 0x0008
    case cmd08 = 0x08
    /// Total mileage - query controller 0x0009
    case cmd09 = 0x09
    /// Temperature query -- query controller 0x000A
    case cmd0A = 0x0A
    /// Driving current -- query / set controller 0x000B
    case cmd0B = 0x0B
    /// Battery voltage query -- query controller 0x000C
    case cmd0C = 0x0C
    /// Total battery capacity -- query controller 0x00 0D
    case cmd0D = 0x0D
    /// Battery remaining capacity -- query / set controller 0x000E
    case cmd0E = 0x0E
    /// Battery charge and discharge times - query / set controller 0x000F
    case cmd0F = 0x0F
    /// Battery manufacturer code and number - query / set controller 0x0010
    case cmd10 = 0x10
    /// Controller manufacturer code and software and hardware version - query / set 0x0011
    case cmd11 = 0x11
    /// Number of Hall pulses of geared motor - query / set controller 0x0012
    case cmd12 = 0x12
    /// The interval time between the geared motor receiving the Hall pulse (unit: ms ) --query 0x0013
    case cmd13 = 0x13
    /// Motor parameters - query / configure 0x0014
    case cmd14 = 0x14
    /// Wheel diameter size - query / set controller 0x0015
    case cmd15 = 0x015
    /// FLA SH data version -- query 0x0016
    case cmd16 = 0x16
    /// Manufacturer code and software and hardware version -- query 0x0017
    case cmd17 = 0x17
    /// Instrument backlight brightness -- query / set 0x0018
    case cmd18 = 0x18
    /// Night mode -- query / set 0x0019
    case cmd19 = 0x19
    /// Set the color light 0x00 1A
    case cmd1A = 0x1A
    /// SN serial number query 0x00 1D
    case cmd1D = 0x1D
    /// Battery status query 0x00 20
    case cmd20 = 0x20
    /// Gyroscope angle query 0x00 20
    case cmd21 = 0x21
    /// Response time query /set
    case cmd22 = 0x22
    /// BMS firmware version number query 0x00 2A ..
    case cmd2A = 0x2A
    /// Single mileage query 0x00 30
    case cmd30 = 0x30
    /// Single time query 0x00 31
    case cmd31 = 0x31
    /// Speed query 0x00 32
    case cmd32 = 0x32
    /// Incoming call push 0x00A0
    case cmdA0 = 0xA0
    /// SMS push 0x 00A1
    case cmdA1 = 0xA1
    /// Message push 0x00A2
    case cmdA2 = 0xA2
    /// Time push 0x00A3
    case cmdA3 = 0xA3
    /// Bluetooth password -- query / configure 0x00A4
    case cmdA4 = 0xA4
    /// Navigation push 0x00A5
    case cmdA5 = 0xA5
    /// Reset command ( restore factory settings ) 0x00A6
    case cmdA6 = 0xA6
    /// Lock / unlock settings 0x00A7
    case cmdA7 = 0xA7
    /// Change the vehicle lock password to 0x00A8
    case cmdA8 = 0xA8
    /// After-sales password query 0x00A9
    case cmdA9 = 0xA9
    /// Weather information push 0x00AA
    case cmdAA = 0xAA
    /// Query the upgrade conditions of the slave ( Bootl oader ) 0x00D0
    case cmdD0 = 0xD0
    /// Transmit upgrade data packet / query receiving status 0x00D1
    case cmdD1 = 0xD1
    /// Upgrade verification / upgrade completion response 0x00D2
    case cmdD2 = 0xD2
    /// Query the upgrade conditions of the slave ( Appl ication ) 0x00E0
    case cmdE0 = 0xE0
    /// Transmit upgrade data packet / query receiving status 0x00E1
    case cmdE1 = 0xE1
    /// Upgrade verification / upgrade completion response 0x00E2
    case cmdE2 = 0xE2
    /// Query the slave ( Flash ) upgrade conditions 0x00F0
    case cmdF0 = 0xF0
    /// Transmit upgrade data packet / query receiving status 0x00F1
    case cmdF1 = 0xF1
    /// Upgrade verification / upgrade completion response 0x00F2
    case cmdF2 = 0xF2
    
    public var headerLowByte: UInt8 {
        return self.rawValue
    }
    
    public var headerHighByte: UInt8 {
        return 0x00
    }
    
    public var cmdDataLength: UInt8 {
        switch self {
        case .cmd02:
            return 0x02
        case .cmd04:
            return 0x02
        case .cmd05:
            return 0x02
        case .cmd11:
            return 0x00
        case .cmdA4:
            return 0x06
        case .cmdE2:
            return 0x04
        case .cmd0C:
            return 0x01
        case .cmd0B:
            return 0x03
        case .cmd0F:
            return 0x01
        case .cmd0D:
            return 0x01
        case .cmd0E:
            return 0x01
        case .cmd0A:
            return 0x01
        case .cmd10:
            return 0x01
        case .cmd14:
            return 0x02
        case .cmdA8:
            return 0x0C
        case .cmd22:
            return 0x02
        default:
            return 0
        }
    }
    
    /// Get function code by code value
    /// - Parameter idValue: code value
    /// - Returns: Function Code
    public static func getFunctionCode(by idValue: UInt8) -> TCBFunctionCode? {
        return Self.allCases.first(where: { $0.headerLowByte == idValue})
    }
}

/// Ble reponse Data type
public enum TCBDataResponseType: CaseIterable {
    
    /// reponse from controller
    case controllerRes
    /// reponse from meter
    case meterRes
    
    public var header: UInt8 {
        switch self {
        case .controllerRes:
            // 0xB1
            return TCBMachineType.sub.header | TCBBleAuth.response.header | TCBDeviceType.control.header
        case .meterRes:
            // 0xB3
            return TCBMachineType.sub.header | TCBBleAuth.response.header | TCBDeviceType.meter.header
        }
    }
    
    public static func getBleResType(by resType: UInt8) -> TCBDataResponseType? {
        if resType == TCBDataResponseType.controllerRes.header {
            return .controllerRes
        } else if resType == TCBDataResponseType.meterRes.header  {
            return .meterRes
        } else {
            return nil
        }
    }
}

/// Ble  header write type
public enum TCBCMDHeader {
    
    /// write to controller
    case controllerWrite
    /// write to  meter
    case meterWrite
    /// read from controller
    case controllerRead
    /// read from  meter
    case meterRead
    
    public var value: UInt8 {
        switch self {
        case .controllerWrite:
            return TCBMachineType.main.header | TCBBleAuth.writeResponse.header | TCBDeviceType.control.header
        case .meterWrite:
            return TCBMachineType.main.header | TCBBleAuth.writeResponse.header | TCBDeviceType.meter.header
        case .controllerRead:
            return TCBMachineType.main.header | TCBBleAuth.read.header | TCBDeviceType.control.header
        case .meterRead:
            return TCBMachineType.main.header | TCBBleAuth.read.header | TCBDeviceType.meter.header
        }
    }
}


public enum TCBConstant {
    /// frame hader
    public static let frameHeader: UInt8 = 0x5A
    /// frame  fromat size:  Frame Header, Device Address, Function code low, hight,  Data length
    public static let frameFrormatSize: Int = 5
    
    public static let frameDataLengthIndex: Int = 4
    
    public static let frameFunctionIndex: Int = 2
    
    public static let OTAPacketLength: Int = 130
    
    /// ble write UUID
    public static let uuidWrite = "0000FFE1-0000-1000-8000-00805F9B34FB"
    /// ble notify UUID
    public static let uuidNotify = "0000FFE2-0000-1000-8000-00805F9B34FB"
    /// ble read UUID
    public static let uuidNbRead = "00002a28-0000-1000-8000-00805f9b34fb"
    /// DescriptorU UID
    public static let uuidDescriptor = "00002902-0000-1000-8000-00805f9b34fb"
    /// ble version UUID：2A28
    public static let bleVersionUUID = "2A28"
    /// ble version service UUID：180A
    public static let bleVersionServiceUUID = "180A"
}

/// Response time type
/// - 0: Throttle response: Adjustment range (0-10),
/// - 1: Brake response: Adjustment range (0-10),
public enum TCBResponseType: Int, CaseIterable {
    /// Throttle response
    case throttle = 0
    /// Brake response:
    case brake = 1
}

/// Upgrade completion response,
/// - 0: Upgrade successful,
/// - 1: Upgrade failed,
/// - 2: Upgrading
public enum TCBUpgradeResponse: Int, CaseIterable {
    /// Upgrade successful
    case success = 0
    /// Upgrade failed
    case failed = 1
    /// Upgrading
    case upgrading = 2
}

/// drive mode corresponds
/// - 1 front drive,
/// - 2 front and rear drive,
/// - 3 rear drive
public enum TCBDriveMode: Int, CaseIterable {
    case front = 1
    case frontAndRear = 2
    case rear = 3
}
/// Error
public enum TCBError: Error {
    case crcParamError
    case crc16Error
    case crc32Error
    case upgradeTimeout
    case notready
    case binError
}
