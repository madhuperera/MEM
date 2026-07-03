# Remove Old ScreenConnect — Intune Win32 App

Removes **legacy / unwanted** ScreenConnect Client instances from devices while **preserving
the RMM-managed instance**. Packaged as a Win32 app whose *install* command actually performs
an uninstall, with an inverse detection rule.

## How it separates the two instances

ScreenConnect stamps a unique **16-hex instance ID** into every client (identical on all
devices for a given server):

```
ScreenConnect Client (a1b2c3d4e5f6a7b8)
                      ^^^^^^^^^^^^^^^^  <- instance ID (DisplayName, service, folder)
```

Strategy = **keep-list**: keep the RMM instance ID, remove every other instance found.

## Files

| File                                   | Role in Intune                               |
| -------------------------------------- | -------------------------------------------- |
| `Uninstall-OldScreenConnect.ps1`     | **Install command** (does the removal) |
| `Detect-OldScreenConnectRemoved.ps1` | **Detection rule** (custom script)     |

## Configure before packaging

The keep ID must be set in **two places** and kept in sync:

1. Get the RMM instance ID (16-hex in parentheses of its Add/Remove Programs name).
2. **Install command:** pass it via `-KeepInstanceId` (see below).
3. **Detection script:** edit the `$KeepInstanceId` array near the top of
   `Detect-OldScreenConnectRemoved.ps1`. Intune runs detection scripts with no command line,
   so this value cannot be a parameter — it must be set in the script.

> ⚠️ The `$KeepInstanceId` in the detection script **must match** the `-KeepInstanceId` on the
> install command, or detection will never report compliant.

## Intune Win32 app settings

**Install command** (forces 64-bit PowerShell — see note below):

```
%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\Uninstall-OldScreenConnect.ps1" -KeepInstanceId 8a6694814c04969b
```

(For multiple keep IDs: `-KeepInstanceId 8a6694814c04969b,00112233445566ff`)

**Uninstall command** (placeholder — this app is install-to-remove; use a no-op):

```
%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "exit 0"
```

> **Why `Sysnative`?** The Intune Management Extension is a 32-bit process, so a bare
> `powershell.exe` launches the 32-bit engine. Under WOW64, reads of
> `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall` are redirected to `Wow6432Node`,
> which can hide 64-bit-registered uninstall entries. `%SystemRoot%\Sysnative\...` forces the
> 64-bit engine and keeps the install consistent with the 64-bit detection script.
> (`Sysnative` is only visible from a 32-bit process, which is exactly the IME case.)

**Install behaviour:** System
**Detection rule:** Use a custom detection script → upload `Detect-OldScreenConnectRemoved.ps1`.
Set **Run script as 32-bit process: No**.

## Behaviour matrix

| Device state              | Detection    | Action                              |
| ------------------------- | ------------ | ----------------------------------- |
| Old instance present      | Not detected | Install command runs → old removed |
| Only RMM instance present | Detected     | Nothing runs; RMM client untouched  |
| No ScreenConnect at all   | Detected     | Nothing runs                        |
| Old removed, RMM remains  | Detected     | Compliant                           |

## Safety notes

- If the install command is run **without** `-KeepInstanceId`, it **aborts** (exit 1) and
  removes nothing — a missing parameter can never wipe the RMM client.
- An instance whose ID cannot be parsed is **never removed** by the uninstaller, but **is**
  treated as unwanted by detection (conservative).
- Log: `C:\ProgramData\ScreenConnectCleanup\Uninstall-OldScreenConnect.log`

## Packaging

```
IntuneWinAppUtil.exe -c .\Remove-OldScreenConnect -s Uninstall-OldScreenConnect.ps1 -o .\output
```
