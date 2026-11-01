<#
.SYNOPSIS
  Preflight check for nv-uefi-unlocker on the ASUS ProArt PX13 HN7306WU.

.DESCRIPTION
  Read-only. Run in Windows PowerShell on the target laptop BEFORE a test
  boot. It re-measures the facts the tailored build depends on and compares
  them with the constants baked into the ProArt profile:

    * the dGPU is the expected RTX 4050 Laptop (PCI 10DE:28A1,
      subsystem 1043:1ED3) -- the loader routes by device ID, so a different
      ID means this build is not for this card;
    * the dGPU still sits at BDF c4:00.0 (bus 196) -- the stick pins the
      transaction to that address via tx-select-bdf.txt, and the loader
      REFUSES to guess if the pin matches nothing;
    * Secure Boot state -- the loader cannot run under stock Secure Boot,
      so this reports whether the BIOS step is still outstanding;
    * VBIOS and driver versions, printed for the evidence record (they are
      informational: the unlock works at the silicon boot layer and is
      decoupled from the driver version).

  Nothing is changed. Exit code 0 = every hard check passed (Secure Boot
  may still be ON; that is reported as a warning, because disabling it is
  the operator's deliberate BIOS action, not a machine defect).

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\preflight.ps1
#>

# --- Expected values, measured on this machine 2026-11-01 (PROFILE.md). ----
$Expected = @{
    VendorId    = '10DE'          # NVIDIA
    DeviceId    = '28A1'          # AD107, RTX 4050 Laptop
    Subsystem   = '1043:1ED3'     # ASUSTeK subsystem vendor:device
    BusHex      = 'C4'            # bus 196 decimal; the loader parses hex
    DeviceHex   = '00'
    FunctionHex = '0'
    MinVramMiB  = 6000            # 6 GB card; allow small reporting slack
}

$failures = @()
function Check([string]$Name, [bool]$Ok, [string]$Detail) {
    $mark = if ($Ok) { 'PASS' } else { 'FAIL' }
    Write-Host ("[{0}] {1} -- {2}" -f $mark, $Name, $Detail)
    if (-not $Ok) { $script:failures += $Name }
}
function Warn([string]$Name, [string]$Detail) {
    Write-Host ("[WARN] {0} -- {1}" -f $Name, $Detail)
}

# --- Locate the dGPU among all display adapters. -----------------------------
# Win32_VideoController also lists the Radeon 890M iGPU; select by the
# NVIDIA vendor ID inside the PNP device ID, never by adapter order.
$gpu = Get-CimInstance Win32_VideoController |
    Where-Object { $_.PNPDeviceID -match 'VEN_10DE' } |
    Select-Object -First 1
if (-not $gpu) { Write-Host '[FAIL] no NVIDIA display adapter found'; exit 1 }
Write-Host ("GPU found: {0}" -f $gpu.Name)

# PNPDeviceID shape: PCI\VEN_10DE&DEV_28A1&SUBSYS_1ED31043&REV_A1\...
$pnp = $gpu.PNPDeviceID
$dev = if ($pnp -match 'DEV_([0-9A-F]{4})') { $Matches[1] } else { '' }
$sub = if ($pnp -match 'SUBSYS_([0-9A-F]{8})') {
    # SUBSYS packs device(4) then vendor(4): 1ED31043 -> 1043:1ED3
    '{0}:{1}' -f $Matches[1].Substring(4, 4), $Matches[1].Substring(0, 4)
} else { '' }
Check 'device id' ($dev -eq $Expected.DeviceId) `
    "DEV_$dev (expected DEV_$($Expected.DeviceId))"
Check 'subsystem' ($sub -eq $Expected.Subsystem) `
    "$sub (expected $($Expected.Subsystem))"

# --- PCI location -> BDF, formatted the way the loader's pin file wants it. -
$pnpObj   = Get-PnpDevice -Class Display | Where-Object { $_.FriendlyName -like '*4050*' }
$location = (Get-PnpDeviceProperty -InstanceId $pnpObj.InstanceId `
                -KeyName 'DEVPKEY_Device_LocationInfo').Data   # "PCI bus 196, device 0, function 0"
if ($location -match 'bus (\d+), device (\d+), function (\d+)') {
    $bdf = '{0:x2}:{1:x2}.{2}' -f [int]$Matches[1], [int]$Matches[2], [int]$Matches[3]
    $want = '{0}:{1}.{2}' -f $Expected.BusHex.ToLower(), $Expected.DeviceHex, $Expected.FunctionHex
    Check 'BDF pin' ($bdf -eq $want) "BDF $bdf (stick pins $want)"
} else {
    Check 'BDF pin' $false "could not parse location '$location'"
}

# --- Secure Boot: registry value is readable without admin rights. ----------
# (Confirm-SecureBootUEFI needs elevation; the state key does not.)
$sb = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\State' `
        -Name UEFISecureBootEnabled).UEFISecureBootEnabled
if ($sb -eq 1) {
    Warn 'secure boot' 'ENABLED -- disable it in BIOS (or enrol a self-signed cert) before booting the stick'
} else {
    Write-Host '[PASS] secure boot -- disabled'
}

# --- Informational lines for the evidence record. ----------------------------
$bios = Get-CimInstance Win32_BIOS
Write-Host ("INFO  BIOS {0} | Windows driver {1}" -f $bios.SMBIOSBIOSVersion, $gpu.DriverVersion)
Write-Host 'INFO  VBIOS is not exposed here; read it with: nvidia-smi --query-gpu=vbios_version --format=csv'

if ($failures.Count -gt 0) {
    Write-Host ("`nPREFLIGHT FAILED: {0}" -f ($failures -join ', '))
    exit 1
}
Write-Host "`nPREFLIGHT OK -- machine matches the ProArt PX13 4050 profile."
exit 0
