# =============================================================================
# sync_time.ps1
# FPGA Digital Alarm Clock — Time Sync over UART (No Python needed)
# Author: Rohan — E&TC Sem 4, PICT Pune
# -----------------------------------------------------------------------------
# Uses Windows system clock (already NTP-synced by Windows time service).
# Sends 4-byte packet [0xFF, HH, MM, SS] to FPGA over UART.
#
# Usage:
#   Right-click -> Run with PowerShell
#   Or from terminal: powershell -ExecutionPolicy Bypass -File sync_time.ps1
#
# Change COM_PORT below to match your Boolean Board's COM port.
# Check Device Manager -> Ports (COM & LPT) after plugging in USB.
# =============================================================================

param(
    [string]$COM_PORT  = "COM3",
    [int]   $BAUD_RATE = 9600
)

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  FPGA Clock - UART Time Sync (PowerShell)" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan

# Get current local time
$now = Get-Date
$hh  = [byte]$now.Hour
$mm  = [byte]$now.Minute
$ss  = [byte]$now.Second

Write-Host ""
Write-Host "[TIME] Current time : $($now.ToString('HH:mm:ss'))" -ForegroundColor Green
Write-Host "[UART] Port         : $COM_PORT" -ForegroundColor Yellow
Write-Host "[UART] Baud rate    : $BAUD_RATE" -ForegroundColor Yellow

# Build 4-byte packet: [0xFF, HH, MM, SS]
$packet = [byte[]](0xFF, $hh, $mm, $ss)
Write-Host "[UART] Packet       : [0xFF, $hh, $mm, $ss]" -ForegroundColor Yellow

# Open serial port and send
try {
    $port = New-Object System.IO.Ports.SerialPort $COM_PORT, $BAUD_RATE, "None", 8, "One"
    $port.Open()
    Start-Sleep -Milliseconds 150   # let port settle
    $port.Write($packet, 0, $packet.Length)
    $port.Close()
    Write-Host ""
    Write-Host "[OK] Time sent successfully to FPGA." -ForegroundColor Green
    Write-Host "     FPGA clock set to $($hh.ToString('D2')):$($mm.ToString('D2')):$($ss.ToString('D2'))"
}
catch {
    Write-Host ""
    Write-Host "[ERROR] Failed to open $COM_PORT" -ForegroundColor Red
    Write-Host "Check:" -ForegroundColor Red
    Write-Host "  1. COM port number (Device Manager -> Ports)" -ForegroundColor Red
    Write-Host "  2. Boolean Board connected via USB" -ForegroundColor Red
    Write-Host "  3. No other program using this port" -ForegroundColor Red
}

Write-Host ""
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
