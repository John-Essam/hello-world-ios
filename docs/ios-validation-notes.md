# iOS SDK Validation Notes

Repository: `HelloWorldApp`  
Track start date: 2026-05-14  
Rules: official iOS SDK APIs only, no custom packets, no protocol customization.

## BLE Foundation

| Feature | Official iOS API / Flow | Status | Classification | Evidence |
|---|---|---|---|---|
| BLE Scan | `CBCentralManager.scanForPeripherals(withServices:options:)` (broad scan `nil`, vendor UUIDs logged for diagnosis) | PARTIAL | IMPLEMENTATION_ISSUE | Initial implementation filtered by vendor service UUIDs and could hide valid peripherals if advertisements omit those UUIDs. Added callback/permission/filter diagnostics and broad official CoreBluetooth scan; live scooter retest pending. |
| BLE Connect / Disconnect | `CBCentralManager.connect`, `CBCentralManager.cancelPeripheralConnection`, `CBPeripheral.discoverServices` | NOT_TESTED | - | UI + logs implemented; live scooter test pending |
| BLE Authentication (Bind) | `TCB02Command.writeConnect(on:userID:isReset:)` + `TCBManager.convertToModel` (`TCB02Model`) | PARTIAL | IMPLEMENTATION_ISSUE | Live RX evidence showed `requestedUserID=10027` but meter returned `boundId=5` with `bluetoothStatus=false`. Bind input is now aligned to scooter-bound ID `5` with explicit mismatch logs; physical retest pending. |
| BLE Unbind | `TCB02Command.readUnbind()` + `TCBManager.convertToModel` (`TCB02Model`) | NOT_TESTED | - | UI + logs implemented; live scooter test pending |
| BLE Lock / Unlock | `TCB02Command.writeLockStatus(status:)` + `TCBManager.convertToModel` (`TCB02Model`) | NOT_TESTED | - | UI + TX/RX logs implemented; live scooter physical reaction pending |
| Heartbeat stream (`TCB01`) | notify callback + `TCBManager.convertToModel` (`TCB01Model`) | NOT_TESTED | - | UI + logs implemented; live scooter test pending |

## Core Controls

| Feature | Official iOS API / Flow | Status | Classification | Evidence |
|---|---|---|---|---|
| Gear Selection (read/write) | `TCB05Command.writeGear(_:)` + parsed model/heartbeat (`TCB05Model`/`TCB01Model`) | NOT_TESTED | - | Segmented Walk/Gear1/Gear2/Gear3 UI with TX/RX/SDK-parse/timing confirmation logs implemented; live scooter validation pending |
| Gear Max Speed Read (G1/G2/G3) | `TCB05Command.readGearMaxSpeed(gear:)` + parsed `TCB05Model` | NOT_TESTED | - | Dedicated read controls for G1/G2/G3 with TX/RX/SDK-parse/timing logs and per-gear value cards implemented; live scooter validation pending |
| Gear Max Speed Write | `TCB05Command.writeGearMaxSpeed(gear:speed:)` + parsed `TCB05Model` | NOT_TESTED | - | Per-gear write controls implemented with requested/written/readback logging; live scooter validation pending |
| Custom Gear Profiles | `TCB05Command.writeGearMaxSpeed(gear:speed:)` + `TCB05Command.readGearMaxSpeed(gear:)` | NOT_TESTED | - | Profile apply flow implemented with official SDK only: 1500ms write spacing, ~4500ms delayed readback, requested/written/readback evidence logs; live scooter validation pending |
| Global Max Speed Read | `TCB05Command.readMaxSpeed()` + parsed `TCB05MaxSpeedModel` | NOT_TESTED | - | Dedicated global max speed read card + validation logs implemented; live scooter validation pending |
| Start Mode (Zero/Kick) | `TCB02Command.writeStartMode(zeroStart:)` + heartbeat confirmation from `TCB01Model.startMode` | NOT_TESTED | - | Segmented Zero Start/Kick Start UI with TX/RX/SDK-parse/timing confirmation logs implemented; live scooter validation pending |
| Unit System (KM/Mile) | `TCB02Command.writeMetricMileSystemTheme(isKM:)` + heartbeat confirmation from `TCB01Model.metricMileUnit` | NOT_TESTED | - | Segmented KM/Mile UI with TX/RX/SDK-parse/timing confirmation logs implemented; live scooter validation pending |
| Throttle Response Read | `TCB22Command.readResponseTime(type:)` with `type=0` | NOT_TESTED | - | Read button + value display with TX/RX/SDK-parse/timing logs implemented; live scooter validation pending |
| Brake Response Read | `TCB22Command.readResponseTime(type:)` with `type=1` | NOT_TESTED | - | Read button + value display with TX/RX/SDK-parse/timing logs implemented; live scooter validation pending |
| Throttle / Brake Response Write | `TCB22Command.writeResponseTime(type:time:)` with `type=0` / `type=1` | NOT_TESTED | - | Slider-based 0-10 write controls for throttle/brake with TX/RX/SDK-parse/timing confirmation logs implemented; live scooter validation pending |
| NFC Status Read | `TCB03Command.readNfcStatus()` + parsed `TCB03Model.nfcStatus` | FAILED | IOS_SDK_BUG | SDK source audit + runtime frame audit show `cmd03` frames are generated with declared payload length `0` while `TCB03Command` appends 2 bytes. Issue: [#2](https://github.com/John-Essam/hello-world-ios/issues/2) |
| NFC Enable / Disable | `TCB03Command.writeNfcStatus(_:)` + parsed `TCB03Model.nfcStatus` | FAILED | IOS_SDK_BUG | Same `cmd03` frame-length mismatch root cause as NFC read (SDK command payload vs metadata mismatch). Issue: [#1](https://github.com/John-Essam/hello-world-ios/issues/1) |
| Cruise Control ON/OFF | `TCB02Command.writeCruiseControlFunction(status:)` + heartbeat confirmation from `TCB01Model.cruiseControlFunction` | NOT_TESTED | - | TX + timing + parsed heartbeat confirmation logs implemented in dedicated Core Controls section UI; live scooter validation pending |

## Lights

| Feature | Official iOS API / Flow | Status | Classification | Evidence |
|---|---|---|---|---|
| Front Light Control | `TCB04Command.writeFrontLightStatus(_:)` + heartbeat confirmation from `TCB01Model.headlight` | NOT_TESTED | - | ON/OFF controls with TX/RX/SDK-parse/timing logs implemented; heartbeat confirmation logic wired for validation on real scooter |
| Ambient Light ON/OFF | `TCB04Command.writeAmbientLightStatus(_:)` + parsed `TCB04Model.ambientLightStatus` | NOT_TESTED | - | ON/OFF controls with TX/RX/SDK-parse/timing logs implemented; TCB04 callback confirmation wired for validation |
| Ambient Light RGB / Modes | `TCB1ACommand.readAmbientLight()` + `TCB1ACommand.writeAmbientLight(type:R:G:B)` + parsed `TCB1AModel` | FAILED | IOS_SDK_BUG | SDK source audit + runtime frame audit show `cmd1A` write frames are generated with declared payload length `0` while write API appends 5 bytes. Issues: [#3](https://github.com/John-Essam/hello-world-ios/issues/3), [#4](https://github.com/John-Essam/hello-world-ios/issues/4), [#5](https://github.com/John-Essam/hello-world-ios/issues/5), [#6](https://github.com/John-Essam/hello-world-ios/issues/6) |

## Telemetry

| Feature | Official iOS API / Flow | Status | Classification | Evidence |
|---|---|---|---|---|
| Battery Percentage | `TCB01Model.power` from heartbeat notify stream | PASSED | - | User-validated on device: live heartbeat values update correctly. |
| Battery Voltage | `TCB01Model.batteryVoltage` from heartbeat notify stream | PASSED | - | User-validated on device with stable heartbeat-driven updates. |
| Real-Time Speed | `TCB01Model.realTimeSpeed` from heartbeat notify stream | PASSED | - | User-validated on device during telemetry testing. |
| Fault Flags | `TCB01Model` fault bitfields | PASSED | - | User-validated fault/status decoding flow with readable labels. |
| Operational Status Flags | `TCB01Model` status bitfields (+ `TCB03Model` for NFC when available) | PASSED | - | User-validated live status flag updates from heartbeat stream. |
| Controller Temperature | `TCB0ACommand.readTemp()` + `TCB0AModel` parse (`type == 0`) | PASSED | - | User-validated with TX/RX + parsed model flow. |
| Battery Temperature | No documented battery-target `TCB0A` helper in iOS SDK | FAILED | IOS_SDK_GAP | No official `readTemp(.battery)` API in iOS SDK; issue [#7](https://github.com/John-Essam/hello-world-ios/issues/7). |
| Motor Temperature | No documented motor-target `TCB0A` helper in iOS SDK | FAILED | IOS_SDK_GAP | No official `readTemp(.motor)` API in iOS SDK; issue [#8](https://github.com/John-Essam/hello-world-ios/issues/8). |
| Driving Current | `TCB0BCommand.readDrivingCurrent()` + `TCB0BModel` parse | PASSED | - | User confirmed feature passes; `0.0A` alone is not treated as SDK bug when RX + parser are healthy. |
| Battery Voltage Detail | No official iOS `TCB0C` command helper/model flow exposed | FAILED | IOS_SDK_GAP | SDK has `cmd0C` metadata but no official helper/parser flow; issue [#9](https://github.com/John-Essam/hello-world-ios/issues/9). |

## Mileage & Trip

| Feature | Official iOS API / Flow | Status | Classification | Evidence |
|---|---|---|---|---|
| Remaining Mileage | `TCB30Command.readRemainingMileage()` + `TCB30Model.remainingMileage` | NOT_TESTED | - | Dedicated Mileage & Trip section added with TX/RX/SDK-parse/timing logs and timeout diagnostics; scooter-side validation pending. |
| Single-Trip Mileage | `TCB08Command.readSingleTripMileage()` + `TCB08Model.singleTripMileage` | NOT_TESTED | - | UI now persists latest successful trip read and logs TX/RX/model conversion + callback timing for evidence collection. |
| Total Mileage / ODO | `TCB09Command.readTotalTripMileage()` + `TCB09Model.totalMileage` | NOT_TESTED | - | ODO card + command flow implemented with TX/RX/SDK-parse/timing diagnostics using official iOS SDK only. |
| Speed Stats (avg / max) | No official iOS SDK command helper/model parser for `cmd32` | FAILED | IOS_SDK_GAP | iOS SDK exposes function code metadata only; no documented command API or parser model path is available in SDK source. |

## Investigation Notes (2026-05-14)

- Repeated scan callbacks were caused by app configuration: `CBCentralManagerScanOptionAllowDuplicatesKey` was set to `true`, which intentionally emits a discovery callback for every advertisement packet.
- Scan now runs with duplicate coalescing (`allowDuplicates=false`) and records both total callbacks and duplicate update counters to keep validation readable.
- Scan now auto-stops when connect is requested, and stop logs include callback/device counters for auditability.
- Connection milestones are surfaced in UI: Scanning, Device discovered, Connecting, Connected, Notify enabled, Bound, Heartbeat receiving.
- Connection diagnostics now include: device candidate labeling (`LIKELY SCOOTER` / `UNVERIFIED`), service list logging after connect, connect timeout handling (15s pending attempt cancel), and normalized CoreBluetooth error logging with domain/code/localized message.
- Scan UI now prioritizes scooter prefixes (`cardoOX1`, `cardoOX2`, `cardoOX3`) to reduce wrong-device connection attempts.
- Command TX is now gated on channel readiness (connected + vendor service discovered + write characteristic ready + notify enabled) to prevent premature bind/lock/unbind writes.
- Real-device evidence showed `cardoOX3` can connect with services `180A` + `5443000B-...` instead of the earlier hard-coded reference UUIDs, so characteristic binding now uses official vendor write/notify UUIDs (`FFE1` / `FFE2`) across discovered services.
- Bind investigation found parameter sensitivity per scooter/account context. Current target scooter returns `boundId=5` when bind is attempted with another ID, so iOS bind now uses `userID=5` and logs requested-vs-returned IDs for clear root-cause evidence.
- UI/UX flow now matches validation workflow: scan/connect is isolated on a dedicated scanner screen, and successful connect navigates to a separate scooter-control/testing screen.

## SDK Audit Notes (2026-05-17)

- Added strict SDK audit logs for failing features:
  - command name, payload byte count, declared frame payload length, expected frame size validity, RX CRC validity, parse model type, pending callback timeout, and parser-risk warnings.
- Static SDK command audit confirms malformed generated command frames:
  - `TCB03Command.readNfcStatus` and `TCB03Command.writeNfcStatus` append 2 content bytes, but `TCBFunctionCode.cmdDataLength` has no `.cmd03` case and defaults to `0`.
  - `TCB1ACommand.writeAmbientLight` appends 5 content bytes, but `TCBFunctionCode.cmdDataLength` has no `.cmd1A` case and defaults to `0`.
- This is a vendor SDK command framing defect (not app packet logic), and feature-level issues were created with shared-root-cause mapping:
  - NFC Read: [#2](https://github.com/John-Essam/hello-world-ios/issues/2)
  - NFC Write: [#1](https://github.com/John-Essam/hello-world-ios/issues/1)
  - Ambient Solid: [#3](https://github.com/John-Essam/hello-world-ios/issues/3)
  - Ambient Breathing: [#4](https://github.com/John-Essam/hello-world-ios/issues/4)
  - Ambient 7-Color Magic: [#5](https://github.com/John-Essam/hello-world-ios/issues/5)
  - Ambient Read/Apply flow: [#6](https://github.com/John-Essam/hello-world-ios/issues/6)

## Classification Rules

- `IOS_SDK_GAP`: Feature missing from official iOS SDK API.
- `IOS_SDK_BUG`: SDK API exists but SDK behavior/parsing fails.
- `IMPLEMENTATION_ISSUE`: App-side implementation issue.
