//
//  TCBE2Model.swift
//  TCBleComminucation
//
//  Created by yifei on 2024/12/19.
//  Copyright © 2024 Changzhou Taochen. All rights reserved.
//

import Foundation

/// Upgrade verification/upgrade completion response 0x00E2
public struct TCBE2Model: TCBBaseModel, Hashable {
    /// Upgrade completion response, 0: Upgrade successful, 1: Upgrade failed, 2: Upgrading
    public var upgradeCompletionResponse: TCBUpgradeResponse?
    
}

extension TCBE2Model: TCBBaseModelConvertable {
    
    public typealias Output = Self
    
    public static func convert(from data: [UInt8]) -> TCBE2Model {
        
        let result = TCBUpgradeResponse(rawValue:Int(data[0]))
        
        return TCBE2Model(upgradeCompletionResponse: result)
    }
}

