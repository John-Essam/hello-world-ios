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
| Start Mode (Zero/Kick) | `TCB02Command.writeStartMode(zeroStart:)` + heartbeat confirmation from `TCB01Model.startMode` | NOT_TESTED | - | Segmented Zero Start/Kick Start UI with TX/RX/SDK-parse/timing confirmation logs implemented; live scooter validation pending |
| Unit System (KM/Mile) | `TCB02Command.writeMetricMileSystemTheme(isKM:)` + heartbeat confirmation from `TCB01Model.metricMileUnit` | NOT_TESTED | - | Segmented KM/Mile UI with TX/RX/SDK-parse/timing confirmation logs implemented; live scooter validation pending |
| Throttle Response Read | `TCB22Command.readResponseTime(type:)` with `type=0` | NOT_TESTED | - | Read button + value display with TX/RX/SDK-parse/timing logs implemented; live scooter validation pending |
| Brake Response Read | `TCB22Command.readResponseTime(type:)` with `type=1` | NOT_TESTED | - | Read button + value display with TX/RX/SDK-parse/timing logs implemented; live scooter validation pending |
| Throttle / Brake Response Write | `TCB22Command.writeResponseTime(type:time:)` with `type=0` / `type=1` | NOT_TESTED | - | Slider-based 0-10 write controls for throttle/brake with TX/RX/SDK-parse/timing confirmation logs implemented; live scooter validation pending |
| NFC Status Read | `TCB03Command.readNfcStatus()` + parsed `TCB03Model.nfcStatus` | NOT_TESTED | - | Read action + current status indicator with TX/RX/SDK-parse/timing logs implemented; live scooter validation pending |
| NFC Enable / Disable | `TCB03Command.writeNfcStatus(_:)` + parsed `TCB03Model.nfcStatus` | NOT_TESTED | - | Enable/Disable actions with TX/RX/SDK-parse/timing confirmation logs implemented; live scooter validation pending |
| Cruise Control ON/OFF | `TCB02Command.writeCruiseControlFunction(status:)` + heartbeat confirmation from `TCB01Model.cruiseControlFunction` | NOT_TESTED | - | TX + timing + parsed heartbeat confirmation logs implemented in dedicated Core Controls section UI; live scooter validation pending |

## Lights

| Feature | Official iOS API / Flow | Status | Classification | Evidence |
|---|---|---|---|---|
| Front Light Control | `TCB04Command.writeFrontLightStatus(_:)` + heartbeat confirmation from `TCB01Model.headlight` | NOT_TESTED | - | ON/OFF controls with TX/RX/SDK-parse/timing logs implemented; heartbeat confirmation logic wired for validation on real scooter |
| Ambient Light ON/OFF | `TCB04Command.writeAmbientLightStatus(_:)` + parsed `TCB04Model.ambientLightStatus` | NOT_TESTED | - | ON/OFF controls with TX/RX/SDK-parse/timing logs implemented; TCB04 callback confirmation wired for validation |

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

## Classification Rules

- `IOS_SDK_GAP`: Feature missing from official iOS SDK API.
- `IOS_SDK_BUG`: SDK API exists but SDK behavior/parsing fails.
- `IMPLEMENTATION_ISSUE`: App-side implementation issue.
