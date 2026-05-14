//
//  TCB0AModel.swift
//  TCBleComminucation
//
//  Created by yifei on 2024/12/17.
//  Copyright © 2024 Changzhou Taochen. All rights reserved.
//

import Foundation

/// Temperature reponse model
public struct TCB0AModel: TCBBaseModel, Equatable {
    /// °C
    public var temperature: Int = 0
    
    public var type: Int = 0
}

extension TCB0AModel: TCBBaseModelConvertable {
    public typealias Output = Self
    
    public static func convert(from data: [UInt8]) -> TCB0AModel {
        var model = TCB0AModel()
        model.temperature = Int(data[1]) - 60
        model.type = Int(data[0] >> 4)
        return model
    }
}
