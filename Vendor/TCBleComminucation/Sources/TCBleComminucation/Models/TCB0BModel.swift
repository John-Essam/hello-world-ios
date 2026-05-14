//
//  TCB0BModel.swift
//  TCBleComminucation
//
//  Created by yifei on 2024/12/17.
//  Copyright © 2024 Changzhou Taochen. All rights reserved.
//

import Foundation

/// Driving current reponse model
public struct TCB0BModel: TCBBaseModel, Equatable {
    /// Current
    public var drivingCurrent: Float = 0
}

extension TCB0BModel: TCBBaseModelConvertable {
    public typealias Output = Self
    
    public static func convert(from data: [UInt8]) -> TCB0BModel {
        var model = TCB0BModel()
        let current = Int(Int16(bytes: Array(data.suffix(2))))
        model.drivingCurrent = Float(current) / 10.0
        return model
    }
}
