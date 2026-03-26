# ============================================================
# FORCE POWERSHELL ENVIRONMENT & MODULES
# ============================================================
Import-Module CIMCmdlets -ErrorAction SilentlyContinue
Import-Module TrustedPlatformModule -ErrorAction SilentlyContinue

$Host.UI.RawUI.WindowTitle = "Kernel Security Checker v0.1.6"

# --- DEVICEGUARD & VBS DEEP CHECK
$vbs = "NOT SUPPORTED"
$vbsRunning = "NOT RUNNING"
$hvci = "NOT SUPPORTED"
$cg = "NOT SUPPORTED"

try {
    $dg = Get-CimInstance -Namespace root\Microsoft\Windows\DeviceGuard -ClassName Win32_DeviceGuard -ErrorAction Stop
    $vbs = if ($dg.VirtualizationBasedSecurityStatus -eq 2) { "ENABLED" } else { "DISABLED" }
    $vbsRunning = if ($dg.VirtualizationBasedSecurityStatus -eq 2) { "RUNNING" } else { "STOPPED/NOT ACTIVE" }
    $hvci = if ($dg.CodeIntegrityPolicyEnforcementStatus -eq 2) { "ENABLED" } else { "DISABLED" }
    $cg = if ($dg.SecurityServicesConfigured -ne 0) { "ENABLED/PRESENT" } else { "NOT PRESENT" }
} catch { $vbs = "CAN'T CHECK" }

# --- HYPERVISOR SAFE (The "Truth" Engine)
try {
    $sysInfo = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
    $hvCounter = Get-Counter "\Hyper-V Hypervisor\*" -ErrorAction SilentlyContinue

    if ($hvCounter -or $sysInfo.HypervisorPresent) {
        $hyper = "ENABLED (Running)"
    } 
    elseif (bcdedit /enum {current} | Select-String "hypervisorlaunchtype\s+(Auto|Automatico)") {
        $hyper = "ENABLED (Pending Reboot)"
    }
    else {
        # Qui gestiamo il tuo caso: Hardware pronto ma Hypervisor spento
        $hyper = "DISABLED (Hardware Compatible)"
    }
} catch {
    $hyper = "CAN'T CHECK"
}

# --- DSE SAFE
try {
    $dseData = bcdedit /enum {current} 2>$null
    $noIntegrity = $dseData | Select-String "nointegritychecks"
    $testSigning = $dseData | Select-String "testsigning"
    if ($noIntegrity) { $dse = "DISABLED (NO_INTEGRITY_CHECKS)" }
    elseif ($testSigning) { $dse = "TEST MODE (ACTIVE)" }
    else { $dse = "ENABLED" }
} catch { $dse = "CAN'T CHECK" }

# --- LSA SAFE
try {
    $lsaRegistry = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "RunAsPPL" -ErrorAction SilentlyContinue
    $lsaStatus = if ($null -ne $lsaRegistry -and $lsaRegistry.RunAsPPL -gt 0) { "ENABLED" } else { "DISABLED" }
} catch { $lsaStatus = "CAN'T CHECK" }

# --- SECURE BOOT SAFE
try {
    $sb = if (Confirm-SecureBootUEFI -ErrorAction SilentlyContinue) { "ENABLED" } else { "DISABLED" }
} catch { $sb = "NOT SUPPORTED/OFF" }

# --- TPM SAFE (Hardware vs Software Logic)
try {
    $pnpTpm = Get-CimInstance Win32_PnPEntity -Filter "PNPDeviceID LIKE '%MSFT0101%'" -ErrorAction SilentlyContinue
    $wmiTpm = Get-CimInstance -Namespace root\cimv2\security\microsofttpm -ClassName Win32_Tpm -ErrorAction SilentlyContinue
    if ($null -ne $wmiTpm) {
        $spec = [string]($wmiTpm.SpecVersion.Split(',')[0])
        $tpmStatus = "ENABLED (Spec: $($spec.Trim()))"
    } elseif ($pnpTpm) {
        $tpmStatus = "DISABLED / MANUAL (Hardware Detected)"
    } else {
        $tpmStatus = "NOT PRESENT / OFF (Check BIOS)"
    }
} catch { $tpmStatus = "CAN'T CHECK" }

# =========================
# COERENZA LOGICA & WARNINGS (REINTEGRATI)
# =========================
$warnings = @()
if ($vbs -eq "ENABLED" -and $vbsRunning -ne "RUNNING") {
    $warnings += "VBS is enabled but NOT running. Check BIOS (VT-x/AMD-V) or Hardware Virtualization."
}
if ($tpmStatus -match "DISABLED / MANUAL") {
    $warnings += "TPM Chip detected but NOT active. Please start 'tpm.msc' or the TPM Windows Service."
}
if ($hyper -eq "DISABLED" -and $vbsRunning -eq "RUNNING") {
    $warnings += "Logic Mismatch: VBS is active but Hypervisor reports as disabled."
}
if ($hyper -eq "ENABLED" -and $vbs -eq "DISABLED") {
    $warnings += "Hyper-V is ON but VBS is OFF. Enable 'Core Isolation > Memory Integrity' in Windows Security."
}
# =========================
# OUTPUT ENGINE
# =========================
function Print($label, $value) {
    $v = $value.ToUpper()
    if ($v -match "DISABLED|OFF|NOINTEGRITY|STOPPED|NOT PRESENT") {
        Write-Host "$label $value" -ForegroundColor Red ; return
    }
    if ($v -match "NOT SUPPORTED|CAN'T CHECK|UNKNOWN") {
        Write-Host "$label $value" -ForegroundColor Yellow ; return
    }
    if ($v -match "ENABLED|PRESENT|RUNNING|ACTIVE") {
        Write-Host "$label $value" -ForegroundColor Green ; return
    }
    Write-Host "$label $value" -ForegroundColor Gray
}

Write-Host "#============================================" -ForegroundColor Cyan
Write-Host "#" -ForegroundColor Cyan
Write-Host "# Kernel Security Checker" -ForegroundColor Cyan
Write-Host "# DraftmanCorp. ©2026" -ForegroundColor Cyan
Write-Host "#" -ForegroundColor Cyan
Write-Host "#============================================" -ForegroundColor Cyan

Print "VBS (Virtualization-based Security):" $vbs
Print "VBS Runtime State:" $vbsRunning
Print "HVCI (Memory Integrity):" $hvci
Print "DSE (Driver Signing):" $dse
Print "Windows Credential Guard:" $cg
Print "LSA Protection:" $lsaStatus
Print "Hypervisor:" $hyper
Print "Secure Boot:" $sb
Print "TPM Hardware:" $tpmStatus

# --- STAMPA WARNINGS
if ($warnings.Count -gt 0) {
    Write-Host "`nREMEDIATION STEPS / WARNINGS:" -ForegroundColor Yellow
    foreach ($w in $warnings) { Write-Host " [!] $w" -ForegroundColor Yellow }
}

# --- SCORE ENGINE
function IsActive($v) {
    if ($null -eq $v) { return $false }
    return [string]$v -match "ENABLED|PRESENT|RUNNING|ACTIVE" -and $v -notmatch "DISABLED"
}

$score = 0
$score += if ($vbsRunning -eq "RUNNING") { 20 } else { 0 }
$score += if (IsActive $hvci) { 20 } else { 0 }
$score += if (IsActive $sb) { 20 } else { 0 }
$score += if (IsActive $tpmStatus) { 15 } else { 0 }
$score += if (IsActive $dse) { 15 } else { 0 }
$score += if (IsActive $lsaStatus) { 10 } else { 0 }

Write-Host "`nINTEGRITY SCORE: $score / 100" -ForegroundColor Cyan
if ($score -ge 80) { Write-Host "STATUS: HARDENED" -ForegroundColor Green }
elseif ($score -ge 50) { Write-Host "STATUS: PARTIAL PROTECTION" -ForegroundColor Yellow }
else { Write-Host "STATUS: WEAK KERNEL POSTURE" -ForegroundColor Red }

Write-Host "============================================"
Write-Host "`nPress any key to exit..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")