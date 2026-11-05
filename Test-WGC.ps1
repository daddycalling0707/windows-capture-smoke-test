#Requires -Version 7.0
# Synthetic Windows validation harness. Not a released application.
# Run only in a disposable authorized Windows desktop, with the exact pinned
# ffmpeg.exe. Captures that test desktop, not any private user's desktop.
param([Parameter(Mandatory=$true)][string]$FFmpeg,[string]$OutDir="$PSScriptRoot\wgc-results")
$ErrorActionPreference='Stop'
$expected='3256173f3f8bffd7df12227c68adf68025edb1832273a9530688a7bb1ed8edec'
if((Get-FileHash $FFmpeg -Algorithm SHA256).Hash.ToLower() -ne $expected){throw 'Wrong FFmpeg binary'}
New-Item -ItemType Directory -Force $OutDir | Out-Null
# Read-only environment preflight. Do not change service accounts, create an
# interactive session or bypass a locked desktop merely to make capture pass.
$session=[Diagnostics.Process]::GetCurrentProcess().SessionId
$preflight=[ordered]@{OS=[Environment]::OSVersion.VersionString;SessionId=$session;UserInteractive=[Environment]::UserInteractive;CaptureServices=@(Get-Service 'CaptureService*' -ErrorAction SilentlyContinue | Select-Object Name,Status,StartType)}
$preflight | ConvertTo-Json -Depth 4 | Set-Content "$OutDir\preflight.json"
if($session -eq 0 -or -not [Environment]::UserInteractive){throw 'No interactive user session: WGC runner route not viable in this job'}
Add-Type @'
using System;using System.Runtime.InteropServices;
public static class InputDesktopProbe {
 [DllImport("user32.dll",SetLastError=true)]public static extern IntPtr OpenInputDesktop(uint flags,bool inherit,uint access);
 [DllImport("user32.dll")]public static extern bool CloseDesktop(IntPtr desktop);
}
'@
$desk=[InputDesktopProbe]::OpenInputDesktop(0,$false,1)
if($desk -eq [IntPtr]::Zero){throw 'Input desktop unavailable; no capture validation possible'}
[void][InputDesktopProbe]::CloseDesktop($desk)
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type @'
using System;using System.Runtime.InteropServices;
public static class MonitorLookup {
 [StructLayout(LayoutKind.Sequential)]public struct Point {public int X;public int Y;}
 [DllImport("user32.dll")]public static extern IntPtr MonitorFromPoint(Point p,uint flags);
}
'@
$screen=[Windows.Forms.Screen]::PrimaryScreen
$point=New-Object MonitorLookup+Point
$point.X=$screen.Bounds.X+1;$point.Y=$screen.Bounds.Y+1
$monitor=[MonitorLookup]::MonitorFromPoint($point,2).ToInt64()
if($monitor -eq 0){throw 'No primary monitor resolved'}
$height=[Math]::Min(720,$screen.Bounds.Height)
$graph="gfxcapture=hmonitor=${monitor}:max_framerate=30:capture_cursor=1:display_border=0:output_fmt=bgra,hwdownload,format=bgra"
# Moving color/clock form creates measurable changing content. User must inspect
# the resulting pixels as well as frame counts, not trust exit status alone.
$form=New-Object Windows.Forms.Form
$form.Text='WGC disposable validation marker';$form.Width=640;$form.Height=480
$form.StartPosition='CenterScreen';$form.TopMost=$true
$label=New-Object Windows.Forms.Label;$label.Dock='Fill';$label.Font=New-Object Drawing.Font('Arial',32)
$form.Controls.Add($label)
$timer=New-Object Windows.Forms.Timer;$timer.Interval=100
$timer.Add_Tick({$label.Text=[DateTime]::Now.ToString('HH:mm:ss.fff');$form.BackColor=if([DateTime]::Now.Second%2){[Drawing.Color]::White}else{[Drawing.Color]::SkyBlue}})
$form.Show();$timer.Start()
$args=@('-hide_banner','-y','-loglevel','info','-filter_threads','1','-f','lavfi','-i',$graph,'-t','12','-vf',"setpts=PTS-STARTPTS,scale=-2:${height}:flags=fast_bilinear,format=yuv420p",'-fps_mode','cfr','-r','30','-c:v','libx264','-preset','ultrafast','-crf','24','-maxrate','8M','-bufsize','8M','-threads','2',"$OutDir\wgc-marker.mp4")
# Use ArgumentList on .NET ProcessStartInfo so spaces and filter punctuation
# are passed as exact argv, not PowerShell command-string interpolation.
$si=New-Object Diagnostics.ProcessStartInfo
$si.FileName=$FFmpeg;$si.UseShellExecute=$false;$si.RedirectStandardError=$true
foreach($arg in $args){$si.ArgumentList.Add($arg)}
$p=[Diagnostics.Process]::Start($si)
$read=$p.StandardError.ReadToEndAsync();$deadline=[DateTime]::Now.AddSeconds(25)
try {
 while(-not $p.HasExited -and [DateTime]::Now -lt $deadline){[Windows.Forms.Application]::DoEvents();Start-Sleep -Milliseconds 20}
 if(-not $p.HasExited){$p.Kill();throw 'WGC probe exceeded bounded timeout'}
 $read.Result | Set-Content "$OutDir\wgc-ffmpeg-log.txt"
 if($p.ExitCode -ne 0){throw "WGC returned $($p.ExitCode); inspect log"}
} finally {$timer.Stop();$form.Close();$form.Dispose();$timer.Dispose()}
& $FFmpeg -v error -i "$OutDir\wgc-marker.mp4" -f null -
if($LASTEXITCODE -ne 0){throw 'Full-file decode failed'}
& $FFmpeg -v error -ss 2 -i "$OutDir\wgc-marker.mp4" -frames:v 1 -y "$OutDir\marker-2s.png"
& $FFmpeg -v error -ss 8 -i "$OutDir\wgc-marker.mp4" -frames:v 1 -y "$OutDir\marker-8s.png"
Write-Output 'Decode passed. Inspect both PNGs and video for changing marker, correct monitor, color and aspect. This is NOT game-capture or GT730 validation.'
