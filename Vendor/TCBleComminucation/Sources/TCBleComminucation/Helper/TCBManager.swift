//
//  TCBManager.swift
//  TCBleComminucation
//
//  Created by yifei on 2024/12/17.
//  Copyright © 2024 Changzhou Taochen. All rights reserved.
//

import Foundation

fileprivate typealias Logger = TCBLogger

fileprivate typealias Constants = TCBConstant

open class TCBManager {

    /// ble response data to model
    /// - Parameter data: ble data
    /// - Returns: model
    public static func convertToModel(data: Data) -> TCBBaseModel {
        
        Logger.onLog(data.toHexString())
        
        guard checkCRC16Data(data) else {
            return TCBBLEModel()
        }
        
        let dataBytes = data.bytes
        // data length
        let dataLength = Int(dataBytes[Constants.frameDataLengthIndex])
        let dataEnd = dataLength + Constants.frameFrormatSize
        guard dataBytes.count >= dataEnd + 2 else {
            Logger.onLog("data length error: \(dataBytes.count)")
            return TCBBLEModel()
        }
        let bizDatas: [UInt8] = Array(dataBytes[Constants.frameFrormatSize..<dataEnd])
        // Function code
        let functionID = dataBytes[Constants.frameFunctionIndex]
        guard let type = TCBFunctionCode.getFunctionCode(by: functionID) else {
            Logger.onLog("INCORRECT Function Code: \(functionID)")
            return TCBBLEModel()
        }
        let model = type.converToModel(with: bizDatas, deviceType: data[1])
        
        return model
    }
    
    /// ble response data CRC16 check
    /// - Parameter data: ble reponse data
    /// - Returns: true false
    public static func checkCRC16Data( _ data: Data) -> Bool {
        let dataBytes = data.bytes
        guard dataBytes.count > 2 else {
            return false
        }
        let message = dataBytes.prefix(dataBytes.count - 2)
        let validate = dataBytes.suffix(2)
        do {
            return try TCBCRC16.check(Array(message), validate: Array(validate))
        } catch {
            Logger.onLog("CRC16 error: \(error)")
            return false
        }
    }
}

extension TCBFunctionCode {
    
    /// model convert by the ble data
    /// - Parameters:
    ///   - data: ble data
    ///   - deviceType: device type, meter, controller
    /// - Returns: model
    func converToModel(with data: [UInt8], deviceType: UInt8) -> TCBBaseModel { // swiftlint:disable:this cyclomatic_complexity function_body_length
        switch self {
        case .cmd01:
            return TCB01Model.convertBy(data: data)
        case .cmd02:
            return TCB02Model.convertBy(data: data)
        case .cmd03:
            return TCB03Model.convertBy(data: data)
        case .cmd04:
            return TCB04Model.convertBy(data: data)
        case .cmd05:
            if deviceType == TCBDataResponseType.controllerRes.header && (data[0] >> 3) == 0b0011 {
                // Gear & Speed
                return TCB05Model.convertBy(data: data)
            } else if deviceType == TCBDataResponseType.meterRes.header && (data[0] >> 3) == 0b0110 {
                // Drive mode
                return TCB05DriveModel.convertBy(data: data)
            } else if deviceType == TCBDataResponseType.controllerRes.header && (data[0] >> 3) == 0b0000 {
                // Drive mode
                return TCB05MaxSpeedModel.convertBy(data: data)
            } else {
                return TCBBLEModel()
            }
        case .cmd08:
            return TCB08Model.convertBy(data: data)
        case .cmd09:
            return TCB09Model.convertBy(data: data)
        case .cmd0A:
            return TCB0AModel.convertBy(data: data)
        case .cmd0B:
            return TCB0BModel.convertBy(data: data)
        case .cmd11:
            if deviceType == TCBDataResponseType.controllerRes.header {
                return TCB11ControllerModel.convertBy(data: data)
            } else if deviceType == TCBDataResponseType.meterRes.header {
                return TCB11MeterModel.convertBy(data: data)
            } else {
                return TCBBLEModel()
            }
        case .cmd1A:
            return TCB1AModel.convertBy(data: data)
        case .cmd22:
            return TCB22Model.convertBy(data: data)
        case .cmd30:
            return TCB30Model.convertBy(data: data)
        case .cmdE0:
            return TCBE0Model.convertBy(data: data)
        case .cmdE1:
            return TCBE1Model.convertBy(data: data)
        case .cmdE2:
            return TCBE2Model.convertBy(data: data)
       
        default:
            Logger.onLog("No model: \(self.headerLowByte)")
            return TCBBLEModel()
        }
    }
}

// MARK: - log

open class TCBLogger: TCBLogable {
    
    /// logger queue
    static let loggerQueue = DispatchQueue(label: "com.tcet.TCBleComminucation.logger", qos: .default)
}

public protocol TCBLogable: Any {
    static func onLog(_ message: String)
}

extension TCBLogable where Self: TCBLogger {
    public static func onLog(_ message: String) {
        TCBLogger.loggerQueue.async {
            print(message)
        }
    }
}
