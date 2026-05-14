//
//  TCBBaseModel.swift
//  TCBleComminucation
//
//  Created by yifei on 2024/12/11.
//  Copyright © 2024 Changzhou Taochen. All rights reserved.
//

import Foundation
@_exported import CryptoSwift

/// Base model protocol
public protocol TCBBaseModel {

}

/// Empty model
public struct TCBBLEModel: TCBBaseModel {
    
    init() {
        
    }
}

/// Data to model protocol
public protocol TCBBaseModelConvertable<Output> {
    associatedtype Output: TCBBaseModel
    
    /// convert Model
    /// - Parameter data: BLE  content data, without frame header, functionc code, length, crc16 data
    /// - Returns: Model
    static func convert(from data: [UInt8]) -> Output
    
    static func convertBy(data: [UInt8]) -> TCBBaseModel
}

public extension TCBBaseModelConvertable where Self: TCBBaseModel {
    
    static func convertBy(data: [UInt8]) -> TCBBaseModel {
        return Self.convert(from: data)
    }
}

/*
public protocol TCBBaseModeler {
    associatedtype T
    
    func convertToModel(data: [UInt8]) -> T
}

struct TCBAnyModeler<U>: TCBBaseModeler {
    func convertToModel(data: [UInt8]) -> U {
        return _convert(data)
    }
    
    typealias T = U
    
    private let _convert: (_ data: [UInt8]) -> U
    
    init<Base: TCBBaseModeler>(base : Base) where Base.T == U {
        _convert = base.convertToModel
    }

}
*/
