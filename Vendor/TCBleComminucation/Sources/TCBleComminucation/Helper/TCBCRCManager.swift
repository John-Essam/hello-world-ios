//
//  TCBCRCManager.swift
//  TCBleComminucation
//
//  Created by yifei on 2021/12/4.
//  Copyright © 2024 Changzhou Taochen. All rights reserved.
//

import Foundation
import CryptoSwift

/// CRC data manger
public class TCBCRCManager {
    
    public static func check16(message: [UInt8], crc16Value: UInt16) throws -> Bool {
        let crc16Val = try TCBCRC16.generate(message)
        return crc16Val == crc16Val
    }
    
    public static func check16(message: Data, crc16Value: UInt16) throws -> Bool {
        let messageArray = Array(message)
        return try check16(message: messageArray, crc16Value: crc16Value)
    }
    
    public static func check32(message: Data, crc32Value: UInt32) throws -> Bool {
        let messageArray = Array(message)
        return try check32(message: messageArray, crc32Value: crc32Value)
    }
    
    public static func check32(message: [UInt8], crc32Value: UInt32) throws -> Bool {
        let crc32Val = try TCBCRC32.generate(message)
        return crc32Val == crc32Value
    }
    
    public static func crc16Value(by message: Data) throws -> UInt16 {
        let messageArray = Array(message)
        return try crc16Value(by: messageArray)
    }
    
    public static func crc16Value(by message: [UInt8]) throws -> UInt16 {
        return try TCBCRC16.generate(message)
    }

    public static func crc32Value(by message: Data) throws -> UInt32 {
        let messageArray = Array(message)
        return try crc32Value(by: messageArray)
    }
    
    /// create crc32 data with content data when OTA bin
    /// - Parameter message: content data
    /// - Returns: crc32 data
    public static func crc32Value(by message: [UInt8]) throws -> UInt32 {
        return try TCBCRC32.generate(message)
    }
}
