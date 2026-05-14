//
//  TCB01Model.swift
//  TCBleComminucation
//
//  Created by yifei on 2024/12/11.
//  Copyright © 2024 Changzhou Taochen. All rights reserved.
//

import Foundation


/// Heartbeat data interaction reponse model
public struct TCB01Model: TCBBaseModel, Equatable {
    /// Vehicle power percentage (0-100)
    public var power: Int = 0
    /// Cruise control function,
    /// - 0: turn off cruise, 1: turn on cruise
    /// - false: turn off cruise, true: turn on cruise
    public var cruiseControlFunction: Bool = false
    /// Metric mile unit switch,
    /// - 0: kilometer system, 1: mile system
    /// - false: kilometer system, true: mile system
    public var metricMileUnit: Bool = false
    /// Gear (0-7)
    public var gear: Int = 0
    /// Undervoltage status,
    /// - 0: not undervoltage, 1: undervoltage
    /// - false: not undervoltage, true: undervoltage
    public var undervoltageStatus: Bool = false
    /// Assist status,
    /// - 0: no assistance, 1 : assisting
    /// - false: no assistance, true : assisting
    public var assistStatus: Bool = false
    /// Cruise status,
    /// - 0: not cruising, 1: cruising
    /// - false: not cruising, true: cruising
    public var cruiseStatus: Bool = false
    /// Charging status,
    /// - 0: not charging; 1: charging
    /// - false: not charging; true: charging
    public var chargingStatus: Bool = false
    /// Valid state of the throttle,
    /// - 0: invalid, 1: valid (1 when the voltage is greater than 1.2V)
    /// - false: invalid, true: valid (1 when the voltage is greater than 1.2V)
    public var validState: Bool = false
    /// Electronic brake status,
    /// - 0: not braking, 1: braking
    /// - false: not braking, true: braking
    public var electronicBrakeStatus: Bool = false
    /// Mechanical brake status,
    /// - 0: not braking, 1: braking
    /// - false: not braking, true: braking
    public var mechanicalBrakeStatus: Bool = false
    /// Motor running status,
    /// - 0: Motor not running; 1: Motor running
    /// - false: Motor not running; true: Motor running
    public var motorRunningStatus: Bool = false
    /// Speaker status,
    /// -  0: no sound, 1: sound
    /// -  false: no sound, true: sound
    public var speakerStatus: Bool = false
    /// Start mode,
    /// - 0: zero start, 1: non-zero start
    /// - false: zero start, true: non-zero start
    public var startMode: Bool = false
    /// Lock status,
    /// - 0: unlock, 1: lock
    /// - false: unlock, true: lock
    public var lockStatus: Bool = false
    /// Push mode,
    /// - 0: normal driving, 1: push mode
    /// - false: normal driving, true: push mode
    public var pushMode: Bool = false
    /// Headlight switch,
    /// - 0: off, 1: on
    /// - false: off, true: on
    public var headlight: Bool = false
    /// Power on/off status,
    /// - 0x00: power off status, 0x01: power on status, 0x02: power off command
    public var powerStatus: Int = 0
    /// Gyroscope fault 0: No fault 1: Faulty
    public var gyroscopeFault: Bool = false
    /// Battery failure,
    /// - 0: no failure, 1: failure
    /// - false: no failure, true: failure
    public var batteryFault: Bool = false
    /// Controller fault,
    /// - 0: no fault, 1: fault
    /// - false: no fault, true: fault
    public var MOSFault: Bool = false
    /// Motor phase line or MOS tube short circuit fault,
    /// - 0: no fault, 1: fault
    /// - false: no fault, true: fault
    public var motorHallFault: Bool = false
    /// Brake fault,
    /// - 0: no fault, 1: fault
    /// - false: no fault, true: fault
    public var brakeFault: Bool = false
    /// Turn handle fault,
    /// - 0: no fault, 1: fault
    /// - false: no fault, true: fault
    public var turnHandleFault: Bool = false
    /// Communication fault,
    /// - 0: no fault, 1: fault
    /// - false: no fault, true: fault
    public var communicationFault: Bool = false
    /// Battery overvoltage
    /// - 0: No fault 1: Fault
    /// - false: No fault true: Fault
    public var batteryOvervoltage: Bool = false
    /// Battery temperature is too high
    /// - 0: No fault 1: Fault
    /// - false: No fault true: Fault
    public var batteryTemperatureHigh: Bool = false
    /// Controller temperature protection
    /// - 0: No fault 1: Fault
    /// - false: No fault true: Fault
    public var controllerTemperatureProtection: Bool = false
    /// Controller fault,
    /// - 0: no fault, 1: fault
    /// - false: no fault, true: fault
    public var controllerFault: Bool = false
    
    /// Real-time battery voltage
    public var batteryVoltage: Int = 0
    /// Vehicle real-time speed
    public var realTimeSpeed: Int = 0
}

extension TCB01Model: TCBBaseModelConvertable {
    
    public typealias Output = Self
    
    public static func convert(from data: [UInt8]) -> TCB01Model {
        
        var bleDataModel = Self()
        
        let byte5 = data[0]
        // Vehicle power percentage (0-100)
        bleDataModel.power = Int(byte5)
        
        // Vehicle real-time speed
        let speedData = [(data[1] & 0b01111111), data[2]]
        bleDataModel.realTimeSpeed = Int(UInt16(bytes: speedData))
        
        let byte8: [Bit] = data[3].bits().reversed()
   
        // Cruise control function, 0: turn off cruise, 1: turn on cruise
        bleDataModel.cruiseControlFunction = byte8[4] == Bit.one
        // Metric mile unit switch, 0: kilometer system, 1: mile system
        bleDataModel.metricMileUnit = byte8[3] == Bit.one
        // Gear (0-7)
        bleDataModel.gear = Int((data[3] & 0b00000111))
        
        let byte9: [Bit] = data[4].bits().reversed()
        // Undervoltage status, 0: not undervoltage, 1: undervoltage
        bleDataModel.undervoltageStatus = byte9[7] == Bit.one
        // Assist status, 0: no assistance, 1 : assisting
        bleDataModel.assistStatus = byte9[6] == Bit.one
        // Cruise status, 0: not cruising, 1: cruising
        bleDataModel.cruiseStatus = byte9[5] == Bit.one
        // Charging status, 0: not charging; 1: charging
        bleDataModel.chargingStatus = byte9[4] == Bit.one
        // Valid state of the throttle, 0: invalid, 1: valid (1 when the voltage is greater than 1.2V)
        bleDataModel.validState = byte9[3] == Bit.one
        // Electronic brake status, 0: not braking, 1: braking
        bleDataModel.electronicBrakeStatus = byte9[2] == Bit.one
        // Mechanical brake status, 0: not braking, 1: braking
        bleDataModel.mechanicalBrakeStatus = byte9[1] == Bit.one
        // Motor running status, 0: Motor not running; 1: Motor running
        bleDataModel.motorRunningStatus = byte9[0] == Bit.one
        
        let byte10: [Bit] = data[5].bits().reversed()
        // Speaker status, 0: no sound, 1: sound
        bleDataModel.speakerStatus = byte10[7] == Bit.one
        // Start mode, 0: zero start, 1: non-zero start
        bleDataModel.startMode = byte10[6] == Bit.one
        // Lock status, 0: unlock, 1: lock
        bleDataModel.lockStatus = byte10[5] == Bit.one
        // Push mode, 0: normal driving, 1: push mode
        bleDataModel.pushMode = byte10[4] == Bit.one
        // Headlight switch, 0: off, 1: on
        bleDataModel.headlight = byte10[3] == Bit.one
        // Power on/off status, 0x00: power off status, 0x01: power on status, 0x02: power off command
        bleDataModel.powerStatus = Int(UInt8(data[5] & 0b00000011))
        
        let byte11: [Bit] = data[6].bits().reversed()
        // Gyroscope fault 0: No fault 1: Faulty
        bleDataModel.gyroscopeFault = byte11[7] == Bit.one
        // Battery failure, 0: no failure, 1: failure
        bleDataModel.batteryFault = byte11[6] == Bit.one
        // Controller fault, 0: no fault, 1: fault
        bleDataModel.controllerFault = byte11[5] == Bit.one
        // Motor phase line or MOS tube short circuit fault, 0: no fault, 1: fault
        bleDataModel.MOSFault = byte11[4] == Bit.one
        // Motor Hall fault, 0: no fault, 1: fault
        bleDataModel.motorHallFault = byte11[3] == Bit.one
        // Brake fault, 0: no fault, 1: fault
        bleDataModel.brakeFault = byte11[2] == Bit.one
        // Turn handle fault, 0: no fault, 1: fault
        bleDataModel.turnHandleFault = byte11[1] == Bit.one
        // Communication fault, 0: no fault, 1: fault
        bleDataModel.communicationFault = byte11[0] == Bit.one
        
        // Real-time battery voltage (unit 0.1V)
        bleDataModel.batteryVoltage = Int(UInt16(bytes: Array(data[7...8])))
        
        let byte14: [Bit] = data[6].bits().reversed()
        // Battery overvoltage 0: No fault 1: Fault
        bleDataModel.batteryOvervoltage = byte14[0] == Bit.one
        // Battery temperature is too high 0: No fault 1: Fault
        bleDataModel.batteryTemperatureHigh = byte14[1] == Bit.one
        // Controller temperature protection 0: No fault 1: Fault
        bleDataModel.controllerTemperatureProtection = byte14[2] == Bit.one
        
        return bleDataModel
    }
}

extension TCB01Model: CustomStringConvertible {
    public var description: String {
        return "[TCB01Model]" + " power:\(power)"
        + " realTimeSpeed:\(realTimeSpeed)"
        + " cruiseControlFunction:\(cruiseControlFunction)"
        + " metricMileUnit:\(metricMileUnit)"
        + " gear:\(gear)"
        + " undervoltageStatus:\(undervoltageStatus)"
        + " assistStatus:\(assistStatus)"
        + " cruiseStatus:\(cruiseStatus)"
        + " chargingStatus:\(chargingStatus)"
        + " validState:\(validState)"
        + " electronicBrakeStatus:\(electronicBrakeStatus)"
        + " mechanicalBrakeStatus:\(mechanicalBrakeStatus)"
        + " motorRunningStatus:\(motorRunningStatus)"
        + " speakerStatus:\(speakerStatus)"
        + " startMode:\(startMode)"
        + " lockStatus:\(lockStatus)"
        + " pushMode:\(pushMode)"
        + " headlight:\(headlight)"
        + " powerStatus:\(powerStatus)"
        + " gyroscopeFault:\(gyroscopeFault)"
        + " batteryFault:\(batteryFault)"
        + " controllerFault:\(controllerFault)"
        + " MOSFault:\(MOSFault)"
        + " motorHallFault:\(motorHallFault)"
        + " brakeFault:\(brakeFault)"
        + " turnHandleFault:\(turnHandleFault)"
        + " communicationFault:\(communicationFault)"
        + " batteryVoltage:\(batteryVoltage)"
        + " batteryTemperatureHigh:\(batteryTemperatureHigh)"
        + " controllerTemperatureProtection:\(controllerTemperatureProtection)"
    }
    
}
