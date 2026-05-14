//
//  TCB05MaxSpeedModel.swift
//  TCBleComminucation
//
//  Created by yifei on 2024/12/31.
//  Copyright © 2024 Changzhou Taochen. All rights reserved.
//

import Foundation

/// Vehicle speed limit upper limit (read-only speed value)
public struct TCB05MaxSpeedModel: TCBBaseModel, Equatable {
    /// Vehicle speed limit upper limit km/h
    public var maxSpeed: Int = 0
}

extension TCB05MaxSpeedModel: TCBBaseModelConvertable {
    public typealias Output = Self
    
    public static func convert(from data: [UInt8]) -> TCB05MaxSpeedModel {
        var model = TCB05MaxSpeedModel()
        model.maxSpeed = Int(data[1])
        return model
    }
}
