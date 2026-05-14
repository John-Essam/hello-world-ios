//
//  TCB30Model.swift
//  TCBleComminucation
//
//  Created by yifei on 2024/12/20.
//  Copyright © 2024 Changzhou Taochen. All rights reserved.
//

import Foundation

/// Range mileage response model 0 0030
public struct TCB30Model: TCBBaseModel, Equatable {
    /// range mileage
    public var remainingMileage: Float
}

extension TCB30Model: TCBBaseModelConvertable {
    public typealias Output = Self
    
    public static func convert(from data: [UInt8]) -> TCB30Model {
        
        let range = Float(UInt16(bytes: data)) / 10
        
        return TCB30Model(remainingMileage:range)
    }
}
    
