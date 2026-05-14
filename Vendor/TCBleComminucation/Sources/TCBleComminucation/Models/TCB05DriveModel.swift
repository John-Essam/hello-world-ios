//
//  TCB05DriveModel.swift
//  TCBleComminucation
//
//  Created by yifei on 2024/12/16.
//  Copyright © 2024 Changzhou Taochen. All rights reserved.
//

import Foundation

/// Drive model response model
public struct TCB05DriveModel: TCBBaseModel, Equatable {
    /// drive mode corresponds to (Bit0-2) 1 front drive, 2 front and rear drive, 3 rear drive
    public var driveMode: Int = 0
}

extension TCB05DriveModel: TCBBaseModelConvertable {    
    public typealias Output = Self
    
    public static func convert(from data: [UInt8]) -> TCB05DriveModel {
        var model = TCB05DriveModel()
        model.driveMode = Int(data[0] & 0b00000111)
        return model
    }
}
