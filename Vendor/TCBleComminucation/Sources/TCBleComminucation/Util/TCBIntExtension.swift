//
//  TCBIntExtension.swift
//  TCBleDataRepo
//
//  Created by yifei on 2024/3/21.
//

import Foundation

/// Array of bytes. Caution: don't use directly because generic is slow.
///
/// - parameter value: integer value
/// - parameter length: length of output array. By default size of value type
///
/// - returns: Array of bytes
@_specialize(where T == Int)
@_specialize(where T == UInt)
@_specialize(where T == UInt8)
@_specialize(where T == UInt16)
@_specialize(where T == UInt32)
@_specialize(where T == UInt64)
@inlinable
func arrayOfBytes<T: FixedWidthInteger>(value: T, length totalBytes: Int = MemoryLayout<T>.size) -> [UInt8] {
    let valuePointer = UnsafeMutablePointer<T>.allocate(capacity: 1)
    valuePointer.pointee = value
    
    let bytesPointer = UnsafeMutablePointer<UInt8>(OpaquePointer(valuePointer))
    var bytes = [UInt8](repeating: 0, count: totalBytes)
    for j in 0..<min(MemoryLayout<T>.size, totalBytes) {
        bytes[totalBytes - 1 - j] = (bytesPointer + j).pointee
    }
    
    valuePointer.deinitialize(count: 1)
    valuePointer.deallocate()
    
    return bytes
}

extension FixedWidthInteger {
    @inlinable
    func bytes(totalBytes: Int = MemoryLayout<Self>.size) -> [UInt8] {
        arrayOfBytes(value: self.littleEndian, length: totalBytes)
    }
}

extension Int16 {
    @_specialize(where T == ArraySlice<UInt8>)
    init<T: Collection>(bytes: T) where T.Element == UInt8, T.Index == Int {
        self = Int16(bytes: bytes, fromIndex: bytes.startIndex)
    }
    
    @_specialize(where T == ArraySlice<UInt8>)
    init<T: Collection>(bytes: T, fromIndex index: T.Index) where T.Element == UInt8, T.Index == Int {
        if bytes.isEmpty {
            self = 0
            return
        }
        
        let count = bytes.count
        
        let val0 = count > 0 ? Int16(bytes[index.advanced(by: 0)]) << 8 : 0
        let val1 = count > 1 ? Int16(bytes[index.advanced(by: 1)]) : 0
        
        self = val0 | val1
    }
}

extension UInt16 {
    @_specialize(where T == ArraySlice<UInt8>)
    init<T: Collection>(bytes: T) where T.Element == UInt8, T.Index == Int {
        self = UInt16(bytes: bytes, fromIndex: bytes.startIndex)
    }
    
    @_specialize(where T == ArraySlice<UInt8>)
    init<T: Collection>(bytes: T, fromIndex index: T.Index) where T.Element == UInt8, T.Index == Int {
        if bytes.isEmpty {
            self = 0
            return
        }
        
        let count = bytes.count
        
        let val0 = count > 0 ? UInt16(bytes[index.advanced(by: 0)]) << 8 : 0
        let val1 = count > 1 ? UInt16(bytes[index.advanced(by: 1)]) : 0
        
        self = val0 | val1
    }
}

extension UInt32 {
    @_specialize(where T == ArraySlice<UInt8>)
    init<T: Collection>(bytes: T) where T.Element == UInt8, T.Index == Int {
        self = UInt32(bytes: bytes, fromIndex: bytes.startIndex)
    }
    
    @_specialize(where T == ArraySlice<UInt8>)
    init<T: Collection>(bytes: T, fromIndex index: T.Index) where T.Element == UInt8, T.Index == Int {
        if bytes.isEmpty {
            self = 0
            return
        }
        
        let count = bytes.count
        
        let val0 = count > 0 ? UInt32(bytes[index.advanced(by: 0)]) << 24 : 0
        let val1 = count > 1 ? UInt32(bytes[index.advanced(by: 1)]) << 16 : 0
        let val2 = count > 2 ? UInt32(bytes[index.advanced(by: 2)]) << 8 : 0
        let val3 = count > 3 ? UInt32(bytes[index.advanced(by: 3)]) : 0
        
        self = val0 | val1 | val2 | val3
    }
}
