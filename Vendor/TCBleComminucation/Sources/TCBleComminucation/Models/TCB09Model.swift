//
//  TCB09Model.swift
//  TCBleComminucation
//
//  Created by yifei on 2024/12/17.
//  Copyright © 2024 Changzhou Taochen. All rights reserved.
//

import Foundation

/// Total mileagereponse model
public struct TCB09Model: TCBBaseModel, Equatable {
    /// Total mileage
    public var totalMileage : Float = 0
}

extension TCB09Model: TCBBaseModelConvertable {
    public typealias Output = Self
    
    public static func convert(from data: [UInt8]) -> TCB09Model {
        var model = TCB09Model()
        let totalData: [UInt8] = Array(data.suffix(4))
        let totalMileage = UInt32(bytes: totalData)
        if totalMileage == UInt32.max {
            model.totalMileage = 0
        } else {
            model.totalMileage = Float(totalMileage) / 10.0
        }
        return model
    }
}
