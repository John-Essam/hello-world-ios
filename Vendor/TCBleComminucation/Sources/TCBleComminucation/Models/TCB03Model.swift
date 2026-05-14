//
//  TCB03Model.swift
//  TCBleComminucation
//
//  Created by yifei on 2024/12/17.
//  Copyright © 2024 Changzhou Taochen. All rights reserved.
//

import Foundation

/// Parameter configuration reponse model
public struct TCB03Model: TCBBaseModel, Equatable {
    /// nfc on/off
    public var nfcStatus: Bool = false
}

extension TCB03Model: TCBBaseModelConvertable {
    public typealias Output = Self
    
    public static func convert(from data: [UInt8]) -> TCB03Model {
        var model = TCB03Model()
        let byte5: [Bit] = data[0].bits().reversed()
        model.nfcStatus = byte5[4] == Bit.one
        return model
    }
    
    public static func convertBy(data: [UInt8]) -> any TCBBaseModel {
        let byte6: [Bit] = data[1].bits().reversed()
        if byte6[4] == Bit.one {
            return Self.convert(from: data)
        } else {
            return TCBBLEModel()
        }
    }
}
