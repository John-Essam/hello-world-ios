//
//  TCBE1Model.swift
//  TCBleComminucation
//
//  Created by yifei on 2024/12/19.
//  Copyright © 2024 Changzhou Taochen. All rights reserved.
//

import Foundation

/// Transmit upgrade data packet/query receiving status 0x00E1
public struct TCBE1Model: TCBBaseModel, Hashable {
    /// Data receiving status,
    /// - 0: send the next packet, 1: data error request resend
    /// - true: send the next packet, false: data error request resend
    public var dataReceivingStatus: Bool
    
    /// the received data packet number
    public var index: Int = 0
    
}

extension TCBE1Model: TCBBaseModelConvertable {
    
    public typealias Output = Self
    
    public static func convert(from data: [UInt8]) -> TCBE1Model {
        
        let status = data[0] == 0
        let packetIndex = Int(UInt16(bytes: Array(data.suffix(2))))
        return TCBE1Model(dataReceivingStatus: status, index: packetIndex)
    }
}

