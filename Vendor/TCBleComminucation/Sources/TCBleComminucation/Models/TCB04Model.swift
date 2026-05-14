//
//  TCB04Model.swift
//  TCBleComminucation
//
//  Created by yifei on 2024/12/16.
//  Copyright © 2024 Changzhou Taochen. All rights reserved.
//

import Foundation

/// Light response model
public struct TCB04Model: TCBBaseModel, Equatable {
    
    /// Ambient light switch,
    /// - 0: off, 1: on
    /// - false: off, true: on
    public var ambientLightStatus: Bool = false
}

extension TCB04Model: TCBBaseModelConvertable {
    public typealias Output = Self

    public static func convert(from data: [UInt8]) -> TCB04Model {
        var model = TCB04Model()
        let byte5: [Bit] = data[0].bits().reversed()
        // Bit3    Ambient light switch, 0: off, 1: on
        model.ambientLightStatus = byte5[3] == Bit.one
        return model
    }
    
    public static func convertBy(data: [UInt8]) -> any TCBBaseModel {
        let byte6: [Bit] = data[1].bits().reversed()
        
        if byte6[3] == Bit.one {
            return Self.convert(from: data)
        } else {
            return TCBBLEModel()
        }
    }
}
