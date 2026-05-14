//
//  TCBE0Model.swift
//  TCBleComminucation
//
//  Created by yifei on 2024/12/19.
//  Copyright © 2024 Changzhou Taochen. All rights reserved.
//

import Foundation

/// Query the upgrade conditions of the slave (Application) 0x00E0
public struct TCBE0Model: TCBBaseModel, Equatable {
    /// Ready to upgrade?
    /// - 0: Ready to upgrade; 1: Not ready
    /// - true: Ready to upgrade; false: Not ready
    public var readyToUpgrade: Bool
}

extension TCBE0Model: TCBBaseModelConvertable {
    public typealias Output = Self
    
    public static func convert(from data: [UInt8]) -> TCBE0Model {
     
        let result = data[0] == 0
        
        return TCBE0Model(readyToUpgrade: result)
    }
    
}
