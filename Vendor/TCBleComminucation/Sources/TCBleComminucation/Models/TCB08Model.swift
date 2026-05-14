//
//  TCB08Model.swift
//  TCBleComminucation
//
//  Created by yifei on 2024/12/17.
//  Copyright © 2024 Changzhou Taochen. All rights reserved.
//

import Foundation

/// Single mileage reponse model
public struct TCB08Model: TCBBaseModel, Equatable {
    /// Single trip mileage
    public var singleTripMileage : Float = 0
}

extension TCB08Model: TCBBaseModelConvertable {
    public typealias Output = Self
    
    public static func convert(from data: [UInt8]) -> TCB08Model {
        var model = TCB08Model()
        let singleData: [UInt8] = Array(data.prefix(2))
        model.singleTripMileage = Float(UInt16(bytes: singleData)) / 10.0
        return model
    }
}

