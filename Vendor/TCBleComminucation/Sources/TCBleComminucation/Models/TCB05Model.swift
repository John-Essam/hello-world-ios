//
//  TCB05Model.swift
//  TCBleComminucation
//
//  Created by yifei on 2024/12/16.
//  Copyright © 2024 Changzhou Taochen. All rights reserved.
//

import Foundation

/// Gear speed response model
public struct TCB05Model: TCBBaseModel, Equatable {
    /// max speed of gear
    public var speed: Int = 0
    ///  current gear
    public var gear: Int = 0
}

extension TCB05Model: TCBBaseModelConvertable {
    public typealias Output = Self
    
    public static func convert(from data: [UInt8]) -> TCB05Model {
        var speedModel = TCB05Model()
        speedModel.gear = Int(data[0] & 0b00000111)
        speedModel.speed = Int(data[1])
        return speedModel
    }
}

