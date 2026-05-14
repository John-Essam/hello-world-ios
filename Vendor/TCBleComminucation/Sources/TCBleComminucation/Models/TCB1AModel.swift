//
//  TCB1AModel.swift
//  TCBleComminucation
//
//  Created by yifei on 2024/12/18.
//  Copyright © 2024 Changzhou Taochen. All rights reserved.
//

import Foundation

/// Colorful light setting response model
public struct TCB1AModel: TCBBaseModel, Equatable {
    ///Magic light mode: 0x01 monochrome, 0x02 monochrome breathing, 0x03 magic seven colors, 0x04 flowing light effect...
    public var magicLightMode: Int = 0
    /// (Monochrome effective) R 0-255
    public var R: Int = 0
    /// (Monochrome effective) G 0-255
    public var G: Int = 0
    /// (Monochrome effective) B 0-255
    public var B: Int = 0
}

extension TCB1AModel: TCBBaseModelConvertable {
    public typealias Output = Self

    public static func convert(from data: [UInt8]) -> TCB1AModel {
        var model = TCB1AModel()
        model.magicLightMode = Int(data[0])
        model.R = Int(data[1])
        model.G = Int(data[2])
        model.B = Int(data[3])
        return model
        
    }

}
