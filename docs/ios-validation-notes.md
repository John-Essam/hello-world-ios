# iOS SDK Validation Notes

Repository: `HelloWorldApp`  
Track start date: 2026-05-14  
Rules: official iOS SDK APIs only, no custom packets, no protocol customization.

## BLE Foundation

| Feature | Official iOS API / Flow | Status | Classification | Evidence |
|---|---|---|---|---|
| BLE Scan | `CBCentralManager.scanForPeripherals(withServices:options:)` (broad scan `nil`, vendor UUIDs logged for diagnosis) | PARTIAL | IMPLEMENTATION_ISSUE | Initial implementation filtered by vendor service UUIDs and could hide valid peripherals if advertisements omit those UUIDs. Added callback/permission/filter diagnostics and broad official CoreBluetooth scan; live scooter retest pending. |
| BLE Connect / Disconnect | `CBCentralManager.connect`, `CBCentralManager.cancelPeripheralConnection`, `CBPeripheral.discoverServices` | NOT_TESTED | - | UI + logs implemented; live scooter test pending |
| BLE Authentication (Bind) | `TCB02Command.writeConnect(on:userID:isReset:)` + `TCBManager.convertToModel` (`TCB02Model`) | NOT_TESTED | - | UI + logs implemented; live scooter test pending |
| BLE Unbind | `TCB02Command.readUnbind()` + `TCBManager.convertToModel` (`TCB02Model`) | NOT_TESTED | - | UI + logs implemented; live scooter test pending |
| BLE Lock / Unlock | `TCB02Command.writeLockStatus(status:)` + `TCBManager.convertToModel` (`TCB02Model`) | NOT_TESTED | - | UI + TX/RX logs implemented; live scooter physical reaction pending |
| Heartbeat stream (`TCB01`) | notify callback + `TCBManager.convertToModel` (`TCB01Model`) | NOT_TESTED | - | UI + logs implemented; live scooter test pending |

## Investigation Notes (2026-05-14)

- Repeated scan callbacks were caused by app configuration: `CBCentralManagerScanOptionAllowDuplicatesKey` was set to `true`, which intentionally emits a discovery callback for every advertisement packet.
- Scan now runs with duplicate coalescing (`allowDuplicates=false`) and records both total callbacks and duplicate update counters to keep validation readable.
- Scan now auto-stops when connect is requested, and stop logs include callback/device counters for auditability.
- Connection milestones are surfaced in UI: Scanning, Device discovered, Connecting, Connected, Notify enabled, Bound, Heartbeat receiving.
- Connection diagnostics now include: device candidate labeling (`LIKELY SCOOTER` / `UNVERIFIED`), service list logging after connect, connect timeout handling (15s pending attempt cancel), and normalized CoreBluetooth error logging with domain/code/localized message.

## Classification Rules

- `IOS_SDK_GAP`: Feature missing from official iOS SDK API.
- `IOS_SDK_BUG`: SDK API exists but SDK behavior/parsing fails.
- `IMPLEMENTATION_ISSUE`: App-side implementation issue.
