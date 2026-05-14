//
//  TCBECCMD.swift
//  TCBleComminucation
//
//  Created by yifei on 2024/12/20.
//  Copyright © 2024 Changzhou Taochen. All rights reserved.
//

import Foundation

/// OTA
/// Upgrade operations
open class TCBECCMD {
    
    /// bin file data
    private(set) var file: Data
    
    private(set) var firmwareType: TCBDeviceType
    
    private var errorHandler: ((TCBError) -> Void)?
    
    private var progress: ((Int) -> Void)?
    
    private var bleSender: ((Data) -> Void)?
    
    /// firmware data index
    private var sendIndex: Int = 0
    /// firmware data array
    private var firmDatas: [Data] = []
    // firmware data array size
    private var firmDataSize = 0
    // send times
    private var sendTimes: Int = 0
    
    private lazy var waitTimer = RepeatingTimer(timeInterval: 1)
    
    private var fileCRC32: UInt32 = 0
    
    // progress status value 0~100
    private var progressStatus: Int = 0 {
        didSet {
            progress?(progressStatus)
        }
    }
    
    private let kMaxSendTimes = 10
    private let kWatingSeconds = 20
    ///
    private var waitingTime: Int = 20 {
        didSet {
            if waitingTime <= 0 && progressStatus != 100 {
                errorHandler?(.upgradeTimeout)
                waitTimer.suspend()
            }
        }
    }
    
    public init(file: Data, type: TCBDeviceType) {
        self.file = file
        self.firmwareType = type
        
        waitTimer.eventHandler = { [weak self] in
            guard let `self` else { return }
            self.waitingTime -= 1
        }
    }
    
    /// START OTA
    /// - Parameters:
    ///   - progress: OTA progress 0~100, when 100 is finished.
    ///   - bleSneder: ble send data
    ///   - errorHandle: OTA Error
    public func startOTA(progress: @escaping (Int) -> Void,  bleSneder: @escaping (Data) -> Void,
                         error errorHandle: @escaping ((Error) -> Void) ) {
        self.progress = progress
        self.errorHandler = errorHandle
        self.bleSender = bleSneder
        
        startSendCMD()
    }
    
    /// Send data with response
    /// - Parameter reponse: ble response
    public func sendNextPacketWith(reponse: TCBBaseModel) {
        
        if let redayModel = reponse as? TCBE0Model {
            if redayModel.readyToUpgrade {
                // scooter is ready for upgrading
                progressStatus = 1
                prepareSendNextPacket()
            } else {
                waitTimer.suspend()
                errorHandler?(.crc16Error)
            }
        } else if let upgradeResponse = reponse as? TCBE1Model {
            if upgradeResponse.dataReceivingStatus {
                sendPacketSucess()
                prepareSendNextPacket()
            } else {
                resendPacket()
            }
        } else if let resultResponse = reponse as? TCBE2Model {
            if resultResponse.upgradeCompletionResponse == .upgrading {
                TCBLogger.onLog("IS UPGRADING")
                progressStatus = 99
                sendCRC32()
            } else if resultResponse.upgradeCompletionResponse == .success {
                TCBLogger.onLog("firmware UPGRADE success")
                waitTimer.suspend()
                progressStatus = 100
            } else {
                waitTimer.suspend()
                errorHandler?(.crc32Error)
            }
        }
    }
    
    private func startSendCMD() {
        prepareSend()
        sendReadyCMD()
    }
    
    private func prepareSend() {
        let dataLength = file.count
        var dataArray: [Data] = []
        let perDataCount = TCBConstant.OTAPacketLength - 2
        
        dataArray = stride(from: 0, to: dataLength, by: perDataCount).map { index -> Data in
            if index + perDataCount > dataLength {
                return file.subdata(in: index..<dataLength)
            }
            return file.subdata(in: index..<index+perDataCount)
        }
        
        firmDatas = dataArray
        let size = dataArray.count
        guard size > 0 else {
            TCBLogger.onLog("File Size is 0")
            errorHandler?(.binError)
            return
        }
        firmDataSize = size
        fileCRC32 = (try? TCBCRC32.generate(Array(file))) ?? 0
        progressStatus = 0
    }
    
    private func sendReadyCMD() {
        waitingTime = kWatingSeconds
        waitTimer.resume()
        do {
            let statusData = try TCBE0Command.readReadyToUpdate(type: firmwareType)
            bleSender?(statusData)
        } catch {
            TCBLogger.onLog(error.localizedDescription)
            errorHandler?(.crc16Error)
        }
    }

    /// OTA data send
    private func prepareSendNextPacket() {

        if sendIndex >= firmDataSize {
            sendCRC32()
        } else {
            sendTimes = 0
            sendNextPacket()
        }
    }
    
    /// OTA data sending
    private func sendNextPacket() {
        waitingTime = kWatingSeconds
        waitTimer.resume()
        
        let packetData = Array(firmDatas[sendIndex])
        do {
            let statusData = try TCBE1Command.writeUpgradeDataPacket(type: firmwareType, index: sendIndex,
                                                                     data: packetData)
            bleSender?(statusData)
        } catch {
            waitTimer.suspend()
            TCBLogger.onLog(error.localizedDescription)
            errorHandler?(.crc16Error)
        }
    }

    /// Send CRC32 data
    private func sendCRC32() {
        waitingTime = kWatingSeconds
        waitTimer.resume()
        do {
            let statusData = try TCBE2Command.readUpgradeCompletionResponse(type: firmwareType,
                                                                            data: fileCRC32.bytes())
            bleSender?(statusData)
        } catch {
            waitTimer.suspend()
            TCBLogger.onLog(error.localizedDescription)
            errorHandler?(.crc16Error)
        }
    }
    
    private func resendPacket() {
        guard sendTimes < kMaxSendTimes else {
            errorHandler?(.upgradeTimeout)
            waitTimer.suspend()
            return
        }
        sendTimes += 1
        
        sendNextPacket()
    }
    
    private func sendPacketSucess() {
        sendIndex += 1
        let progressValue = ((sendIndex) * 100 / firmDataSize)
        progressStatus = if progressValue == 0 {
            1
        } else if progressValue >= 99 {
            99
        } else {
            progressValue
        }
    }
}
