//
//  TCB02Model.swift
//  TCBleComminucation
//
//  Created by yifei on 2024/12/12.
//  Copyright © 2024 Changzhou Taochen. All rights reserved.
//

import Foundation

/// Controller status Response Model
public struct TCB02Model: TCBBaseModel, Equatable {
    /// user id saved in meter
    public var boundId: String = ""
    /// Bluetooth status,
    /// - 0: not connected, 1: connected
    /// - 0: false, 1: true
    public var bluetoothStatus: Bool = false
    /// Lock status,
    ///  - 0: unlock, 1: lock
    ///  - 0: false, 1: true
    public var lockStatus: Bool = false
}

//protocol TCB02ModelConvertable: TCBBaseModelConvertable where Output == TCB02Model {
//    
//}

extension TCB02Model: TCBBaseModelConvertable {
    public typealias Output = Self
    
    public static func convert(from data: [UInt8]) -> TCB02Model {
        var model = TCB02Model()
        let byte5: [Bit] = data[0].bits().reversed()
        // Bit6    Bluetooth status, 0: not connected, 1: connected
        model.bluetoothStatus = byte5[6] == Bit.one
        // Bit0    Lock status, 0: unlock, 1: lock
        model.lockStatus = byte5[0] == Bit.one
        // user id
        let userID = Int(UInt32(bytes: Array(data.suffix(4))))
        model.boundId = "\(userID)"
        return model
    }
    
    public static func convertBy(data: [UInt8]) -> any TCBBaseModel {
        let byte2: [Bit] = data[1].bits().reversed()
        if byte2[6] == Bit.one {
            return Self.convert(from: data)
        } else {
            return TCBBLEModel()
        }
    }
}
