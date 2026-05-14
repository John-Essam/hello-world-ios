//
//  TCB11Model.swift
//  TCBleComminucation
//
//  Created by yifei on 2024/12/17.
//  Copyright © 2024 Changzhou Taochen. All rights reserved.
//

import Foundation

/// Controller manufacturer code and software and hardware version reponse model
public protocol TCB11Model: TCBBaseModel, Equatable {
    /// manufacturer code (ASCII code of numbers or letters)
    var manufacturerCode: String {get set}
    /// Software version
    var binVersion: String {get set}
    /// Hardware version integer byte 0x99 means 99
    var hardwareVersion: String {get set}
}
