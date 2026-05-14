# iOS SDK Validation Notes

Repository: `HelloWorldApp`  
Track start date: 2026-05-14  
Rules: official iOS SDK APIs only, no custom packets, no protocol customization.

## BLE Foundation

| Feature | Official iOS API / Flow | Status | Classification | Evidence |
|---|---|---|---|---|
| BLE Scan | `CBCentralManager.scanForPeripherals(withServices:options:)` with vendor service UUIDs | NOT_TESTED | - | UI + logs implemented; live scooter test pending |
| BLE Connect / Disconnect | `CBCentralManager.connect`, `CBCentralManager.cancelPeripheralConnection`, `CBPeripheral.discoverServices` | NOT_TESTED | - | UI + logs implemented; live scooter test pending |
| BLE Authentication (Bind) | Pending implementation | NOT_TESTED | - | - |
| BLE Unbind | Pending implementation | NOT_TESTED | - | - |
| Heartbeat stream (`TCB01`) | Pending implementation | NOT_TESTED | - | - |

## Classification Rules

- `IOS_SDK_GAP`: Feature missing from official iOS SDK API.
- `IOS_SDK_BUG`: SDK API exists but SDK behavior/parsing fails.
- `IMPLEMENTATION_ISSUE`: App-side implementation issue.
