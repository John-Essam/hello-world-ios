//
//  TCB11ControllerModel.swift
//  TCBleComminucation
//
//  Created by yifei on 2024/12/18.
//  Copyright © 2024 Changzhou Taochen. All rights reserved.
//

import Foundation

/// Controller manufacturer code and software and hardware version
public struct TCB11ControllerModel: TCB11Model {
    public var manufacturerCode: String = ""
    
    public var binVersion: String = ""
    
    public var hardwareVersion: String = ""

}

extension TCB11ControllerModel: TCBBaseModelConvertable {
    public typealias Output = Self
    
    public static func convert(from data: [UInt8]) -> TCB11ControllerModel {
        var model = Self()
        
        model.manufacturerCode = (Array(data.prefix(4)) + Array(data.suffix(4))).asciiToString()
        let frontHVersion = String(data[4], radix: 16)
        var rearHVersion = String(data[5], radix: 16)
        if rearHVersion.count == 1 {
            rearHVersion = "0" + rearHVersion
        }
        model.hardwareVersion = frontHVersion + "." + rearHVersion
        
        let frontSVersion = String(data[6], radix: 16)
        var rearSVersion = String(data[7], radix: 16)
        if rearSVersion.count == 1 {
            rearSVersion = "0" + rearSVersion
        }
        model.binVersion = frontSVersion + "." + rearSVersion
        return model
    }

}
