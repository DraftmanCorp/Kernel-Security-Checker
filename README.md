# Kernel-Security-Checker
**A basic executable that checks key kernel-side security states in Windows 10 and 11

![Preview](https://github.com/DraftmanCorp/Kernel-Security-Checker/blob/main/Preview/0.0.1.jpg)

Kernel Security Checker is a lightweight PowerShell-based diagnostic tool that evaluates the **kernel-level security posture** of a Windows system.
It is designed for system administrators, security researchers, and advanced users who need to quickly verify whether core Windows kernel hardening features are enabled.

## 🎯 Purpose

The goal of this tool is to provide a clear view of:
- Kernel-level protection status
- Virtualization-based security configuration
- Boot chain integrity
- Code integrity enforcement
- System hardening state

## 🔍 Security Checks Performed

### 1. Virtualization-Based Security (VBS)
- Checks if VBS is enabled via Device Guard
- Indicates whether virtualization-based protection is active

### 2. Hypervisor-Protected Code Integrity (HVCI)
- Verifies enforcement of kernel-mode code integrity
- Ensures only signed drivers can execute in protected mode

### 3. Driver Signature Enforcement (DSE)
- Detects kernel driver signature enforcement state
- Identifies unsafe modes such as:
  - Test signing mode
  - No integrity checks

### 4. Credential Guard (Windows Security Services)
- Checks if Credential Guard-related security services are configured
- Indicates protection of LSASS secrets from credential theft

### 5. LSA Protection (RunAsPPL)
- Verifies if Local Security Authority is running as Protected Process Light (PPL)
- Prevents credential dumping from LSASS

### 6. Hypervisor Presence
- Detects whether a hypervisor is active in the system
- Required for VBS and HVCI enforcement

### 7. Secure Boot Status
- Checks UEFI Secure Boot state
- Validates boot chain integrity against unsigned bootloaders

## 📊 Kernel Integrity Score

The tool generates a **weighted security score (0–100)** based on:

- VBS → 25 points
- HVCI → 25 points
- Secure Boot → 20 points
- DSE → 15 points
- LSA Protection → 10 points
- Hypervisor → 5 points

### Score interpretation:

- 90–100 → Fully hardened system
- 80–89 → Hardened (partial boot trust or minor gaps)
- 50–79 → Partially protected system
- <50 → Weak kernel security posture

## ⚙️ Execution
- Download the archive from release page.
- Extract the "Kernel_Security_Checker.exe" file.
- Double click and and see the verdict.

## 🖥️ Compatibility

- Windows 10
- Windows 11

Requires:
- PowerShell 5+
- Administrative privileges (recommended for full accuracy)
