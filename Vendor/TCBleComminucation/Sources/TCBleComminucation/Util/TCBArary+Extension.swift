//
//  TCBArary+Extension.swift
//  TCBleComminucation
//
//  Created by yifei on 2024/12/18.
//  Copyright © 2024 Changzhou Taochen. All rights reserved.
//

import Foundation

extension Array where Element == UInt8 {
    
    func asciiToString() -> String {
        `lazy`.reduce(into: "") {
            $0 += String(Character(UnicodeScalar($1)))
        }
    }
}

