//
//  TCB22Model.swift
//  TCBleComminucation
//
//  Created by yifei on 2024/12/18.
//  Copyright © 2024 Changzhou Taochen. All rights reserved.
//

import Foundation

/// Response time query /set 0x0022
public struct TCB22Model: TCBBaseModel, Equatable {
    /// Response type,
    /// - 0: Throttle response: Adjustment range (0-10),
    /// - 1: Brake response: Adjustment range (0-10),
    public var responseType: TCBResponseType?
    /// response: Adjustment range (0-10),
    public var response: Int = 0
}

extension TCB22Model: TCBBaseModelConvertable {
    public typealias Output = Self
    
    public static func convert(from data: [UInt8]) -> TCB22Model {
        let type = TCBResponseType(rawValue: Int(data[0]))
        
        return TCB22Model(responseType: type, response: Int(data[1]))
    }
    
}
