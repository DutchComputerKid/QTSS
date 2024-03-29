Add-Type -AssemblyName System.IO.Compression.FileSystem
# Gather command meta data from the original Cmdlet (in this case, Test-Path)
$TestPathCmd = Get-Command Test-Path
$TestPathCmdMetaData = New-Object System.Management.Automation.CommandMetadata $TestPathCmd

# Use the static ProxyCommand.GetParamBlock method to copy 
# Test-Path's param block and CmdletBinding attribute
$Binding = [System.Management.Automation.ProxyCommand]::GetCmdletBindingAttribute($TestPathCmdMetaData)
$Params = [System.Management.Automation.ProxyCommand]::GetParamBlock($TestPathCmdMetaData)

# Create wrapper for the command that proxies the parameters to Test-Path 
# using @PSBoundParameters, and negates any output with -not
$WrappedCommand = { 
    try { -not (Test-Path @PSBoundParameters) } catch { throw $_ }
}

# define your new function using the details above
$Function:notexists = '{0}param({1}) {2}' -f $Binding, $Params, $WrappedCommand
Clear-Host
Write-Host "Checking..." -ForegroundColor Yellow
if ($PSVersionTable.PSVersion.Major -ge 5) {
    Write-Host "PowerShell version:" $PSVersionTable.PSVersion
}
else {
    Write-Host "QTSS requires at least PowerShell 5. Please update!"
    pause
    Break
}

If ($(Get-WmiObject -class Win32_OperatingSystem).Caption -contains "Windows 10" -or "Server 2016") {
    Write-Host "Windows version:" (Get-WmiObject -class Win32_OperatingSystem).Caption
}

else {
    Write-Host "Your Windows version is not compatible, use Windows 10 or Server 2016 (or higher)"
    pause
    Break
}
#Setup
Set-Location $PSScriptRoot
Write-Host ""
If (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {    
    Write-Host "NOTICE: " -ForegroundColor Red -NoNewline
    Write-Host "This script needs to be run As Admin"
    pause
    if (-Not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')) {
        if ([int](Get-CimInstance -Class Win32_OperatingSystem | Select-Object -ExpandProperty BuildNumber) -ge 6000) {
            $CommandLine = "-File `"" + $MyInvocation.MyCommand.Path + "`" " + $MyInvocation.UnboundArguments
            Start-Process -FilePath PowerShell.exe -Verb Runas -ArgumentList "-ExecutionPolicy Bypass $CommandLine"
            Exit
        }
    }
}

function Unzip {
    param([string]$zipfile, [string]$outpath)

    [System.IO.Compression.ZipFile]::ExtractToDirectory($zipfile, $outpath)
}
#Set location to executed script's location
$RootPath = $PSScriptRoot
Set-Location $RootPath
#Show location to user
Write-host "Current location: " $RootPath -ForegroundColor Yellow
#Welcome user
$yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", ""
$no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", ""
$choices = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
$caption = "Welcome!"
Write-Host ""
Write-Host "Welcome to QTools System Setup or QTSS for short."
Write-Host "This script can help to set your system up automatically, unattended!"
Write-Host "You may select desired software and features from upcoming GUI."
$message = "Do you want to continue?"
$result = $Host.UI.PromptForChoice($caption, $message, $choices, 0)
if ($result -eq 0) { 
}
if ($result -eq 1) { 
    Write-Host "You answered NO, continuing script." 
    exit
}
write-host "" 
write-host "NOTICE: " -foregroundcolor Red -NoNewline
Write-Host "Due to some installers requiring to be executed as the current user, we will need your account's password."
Write-Host "Software like Spotify do not run on an administrator account, thus the script will need to run it as you, the user."
$Username = "$env:USERDOMAIN\$env:USERNAME"
$secure = Read-Host -Prompt "Enter your current account's password for $Username" -AsSecureString
function pause {
    Write-Host 'Press any key to continue...';
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
}
function IsInstalled( $program ) {
    $architecture = (Get-WmiObject win32_processor | Where-Object {$_.deviceID -eq "CPU0"}).AddressWidth
    If ($architecture -eq "64") {
        $x64 = ((Get-ChildItem "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall") |
        Where-Object { $_.GetValue( "DisplayName" ) -like "*$program*" } ).Length -gt 0;
    }
    else {
        $x86 = ((Get-ChildItem "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall") |
        Where-Object { $_.GetValue( "DisplayName" ) -like "*$program*" } ).Length -gt 0;
    }
    return $x86 -or $x64;
}

function FuncCheckService {
    # Service Name paramater
    param($ServiceName)

    $arrService = Get-Service -Name $ServiceName
    if ($arrService.Status -ne "Running") {
        Start-Service $ServiceName
        Write-Host "Starting " $ServiceName " service..." 
        " ---------------------- " 
        Start-Sleep 1
        $result = if (($_ | get-service).Status -eq "Running") {"success"} else {"failure"}
        Write-Host "Service $($_.Name) has been restarted with $result."
    }
    if ($arrService.Status -eq "running") { 
        Write-Host "$ServiceName service is already started"
        #$ServiceIsOK = $true
    }
}

function CheckSettings {
    Write-Host "System: "  -ForegroundColor Cyan -NoNewline
    Write-Host "Checking settings..." -Verbose
    if ($7ZipBox.checked -eq $true) {
        Write-Host "System: "  -ForegroundColor Cyan -NoNewline
        Write-Host "7Zip is checked for install..." -Verbose
        $SelectedAnything = $true
        7ZipInstaller
    }
    if ($NotePadPlusPLusBox.checked -eq $true) {
        Write-Host "System: "  -ForegroundColor Cyan -NoNewline
        Write-Host "NotePad++ is checked for install..." -Verbose
        $SelectedAnything = $true
        NotepadPLusPLusInstaller
    }
    if ($FireFoxBox.Checked -eq $true) {
        Write-Host "System: "  -ForegroundColor Cyan -NoNewline
        Write-Host "Firefox is checked for install..." -Verbose
        $SelectedAnything = $true
        InstallFirefox
    } 
    if ($ChromeBox.checked -eq $true) {
        Write-Host "System: "  -ForegroundColor Cyan -NoNewline
        Write-Host "Google Chrome is checked for install..." -Verbose
        $SelectedAnything = $true
        ChromeInstaller
    }
    if ($TBrowserBox.checked -eq $true) {
        Write-Host "System: "  -ForegroundColor Cyan -NoNewline
        Write-Host "Tor Browser is checked for install..." -Verbose
        $SelectedAnything = $true
        TorBrowserInstaller
    }
    if ($IMGBurnBox.Checked -eq $true) {
        Write-Host "System: "  -ForegroundColor Cyan -NoNewline
        Write-Host "IMGBurn is checked for install..." -Verbose
        $SelectedAnything = $true
        IMGBurnInstaller
    } 
    Write-Host ""
    if ($ShutUpBox.Checked -eq $true) {
        Write-Host "System: "  -ForegroundColor Cyan -NoNewline
        Write-Host "ShutUp10 is checked for install..." -Verbose
        $SelectedAnything = $true
        RunShutUp
    } 
    if ($SteamyBox.Checked -eq $true) {
        Write-Host "System: "  -ForegroundColor Cyan -NoNewline
        Write-Host "Running Steam installer process..." -Verbose
        $SelectedAnything = $true
        SteamInstaller
    } 
    if ($AvastFreeBox.checked -eq $true) {
        Write-Host "System: "  -ForegroundColor Cyan -NoNewline
        Write-Host "Avast is checked for install..." -Verbose
        $SelectedAnything = $true
        AvastInstaller
    }
    if ($TelegramBox.checked -eq $true) {
        Write-Host "System: "  -ForegroundColor Cyan -NoNewline
        Write-Host "Telegram is checked for install..." -Verbose
        $SelectedAnything = $true
        TelegramInstaller
    }
    if ($iTunesBox.checked -eq $true) {
        Write-Host "System: "  -ForegroundColor Cyan -NoNewline
        Write-Host "iTunes is checked for install..." -Verbose
        $SelectedAnything = $true
        iTunesInstaller
    }
    if ($Win32DiskImagerBox.checked -eq $true) {
        Write-Host "System: "  -ForegroundColor Cyan -NoNewline
        Write-Host "Win32DiskImager is checked for install..." -Verbose
        $SelectedAnything = $true
        Win32DDInstaller
    }
    if ($AvastPaidBox.Checked -eq $true) {
        if ($AvastFreeBox.Checked -eq $true) {
            Write-Host "System: "  -ForegroundColor Red -NoNewline
            Write-Host "Avast Free is already selected! Skipping paid version installer..."
        }
        else {
            Write-Host "System: "  -ForegroundColor Cyan -NoNewline
            Write-Host "Avast Pro is checked for install..." -Verbose
            $SelectedAnything = $true
            AvastProInstaller
        }
        if ($SelectedAnything -notmatch $true) {
            Write-Host "System: "  -ForegroundColor Red -NoNewline
            Write-Host "You didn't select any programs!"
        }

    }
    if ($gVimBox.checked -eq $true) {
        Write-Host "System: "  -ForegroundColor Cyan -NoNewline
        Write-Host "gVim is checked for install..." -Verbose
        $SelectedAnything = $true
        gVimInstaller
    }
    if ($EUSPMBox.checked -eq $true) {
        Write-Host "System: "  -ForegroundColor Cyan -NoNewline
        Write-Host "EaseUS PartitionMaster is checked for install..." -Verbose
        $SelectedAnything = $true
        EUSPMInstaller
    }
    if ($JavaJREBox.checked -eq $true) {
        Write-Host "System: "  -ForegroundColor Cyan -NoNewline
        Write-Host "Java Runtime Environment is checked for install..." -Verbose
        $SelectedAnything = $true
        JavaJREInstaller
    }
    if ($JSDKBox.checked -eq $true) {
        Write-Host "System: "  -ForegroundColor Cyan -NoNewline
        Write-Host "Java SDK is checked for install..." -Verbose
        $SelectedAnything = $true
        JavaSDKInstaller
    }
    if ($MSNET47Box.checked -eq $true) {
        Write-Host "System: "  -ForegroundColor Cyan -NoNewline
        Write-Host ".NET 4.7 is checked for install..." -Verbose
        $SelectedAnything = $true
        DotNET47Installer
    }
    if ($TransmissionBTBox.checked -eq $true) {
        Write-Host "System: "  -ForegroundColor Cyan -NoNewline
        Write-Host "Transmission BitTorrent Client is checked for install..." -Verbose
        $SelectedAnything = $true
        TransmissionBTInstaller
    }
    if ($AAIRBox.checked -eq $true) {
        Write-Host "System: "  -ForegroundColor Cyan -NoNewline
        Write-Host "Adobe AIR is checked for install..." -Verbose
        $SelectedAnything = $true
        AdobeAirInstaller
    }
    if ($Aida64Box.checked -eq $true) {
        Write-Host "System: "  -ForegroundColor Cyan -NoNewline
        Write-Host "Aida64 is checked for install..." -Verbose
        $SelectedAnything = $true
        Aida64Installer
    }
    if ($ShockwaveBox.checked -eq $true) {
        Write-Host "System: "  -ForegroundColor Cyan -NoNewline
        Write-Host "ShockWave is checked for install..." -Verbose
        $SelectedAnything = $true
        ShockWaveInstaller
    }
    if ($SilverLightBox.checked -eq $true) {
        Write-Host "System: "  -ForegroundColor Cyan -NoNewline
        Write-Host "SilverLIght is checked for install..." -Verbose
        $SelectedAnything = $true
        SilverLightInstaller
    }
    if ($SpotifyBox.checked -eq $true) {
        Write-Host "System: "  -ForegroundColor Cyan -NoNewline
        Write-Host "Spotify is checked for install..." -Verbose
        $SelectedAnything = $true
        SpotifyInstaller
    }
    if ($OriginBox.checked -eq $true) {
        Write-Host "System: "  -ForegroundColor Cyan -NoNewline
        Write-Host "EA Origin is checked for install..." -Verbose
        $SelectedAnything = $true
        OriginInstaller
    }
    if ($VLCBox.checked -eq $true) {
        Write-Host "System: "  -ForegroundColor Cyan -NoNewline
        Write-Host "VLC is checked for install..." -Verbose
        $SelectedAnything = $true
        VLCInstaller
    }
    if ($HWinfo64Box.checked -eq $true) {
        Write-Host "System: "  -ForegroundColor Cyan -NoNewline
        Write-Host "HWInfo64 is checked for install..." -Verbose
        $SelectedAnything = $true
        HWinfo64installer
    }
    if ($PowerISOBox.checked -eq $true) {
        Write-Host "System: "  -ForegroundColor Cyan -NoNewline
        Write-Host "PowerISO is checked for install..." -Verbose
        $SelectedAnything = $true
        PowerISOInstaller
    }
    if ($pycharmBox.checked -eq $true) {
        Write-Host "System: "  -ForegroundColor Cyan -NoNewline
        Write-Host "pycharm is checked for install..." -Verbose
        $SelectedAnything = $true
        pycharmInstaller
    }
    if ($BlenderBox.checked -eq $true) {
        Write-Host "System: "  -ForegroundColor Cyan -NoNewline
        Write-Host "Blender is checked for install..." -Verbose
        $SelectedAnything = $true
        BlenderInstaller
    }
    if ($Foobar2000Box.checked -eq $true) {
        Write-Host "System: "  -ForegroundColor Cyan -NoNewline
        Write-Host "Foobar2000 is checked for install..." -Verbose
        $SelectedAnything = $true
        Foobar2000Installer
    }
    if ($VivaldiBox.checked -eq $true) {
        Write-Host "System: "  -ForegroundColor Cyan -NoNewline
        Write-Host "Vivaldi is checked for install..." -Verbose
        $SelectedAnything = $true
        VivaldiInstaller
    }
    if ($CPythonBox.checked -eq $true) {
        Write-Host "System: "  -ForegroundColor Cyan -NoNewline
        Write-Host "Python is checked for install..." -Verbose
        $SelectedAnything = $true
        CPythonInstaller
    }
    if ($VuzeBox.checked -eq $true) {
        Write-Host "System: "  -ForegroundColor Cyan -NoNewline
        Write-Host "Vuze BitTorrent is checked for install..." -Verbose
        $SelectedAnything = $true
        VuzeInstaller
    }
    if ($MusicBeeBox.checked -eq $true) {
        Write-Host "System: "  -ForegroundColor Cyan -NoNewline
        Write-Host "MusicBee is checked for install..." -Verbose
        $SelectedAnything = $true
        MusicBeeInstaller
    }
    if ($TVBox.checked -eq $true) {
        Write-Host "System: "  -ForegroundColor Cyan -NoNewline
        Write-Host "TeamViewer is checked for install..." -Verbose
        $SelectedAnything = $true
        TeamViewerInstaller
    }
    if ($VSCodeBox.checked -eq $true) {
        Write-Host "System: "  -ForegroundColor Cyan -NoNewline
        Write-Host "Visual Studio Code is checked for install..." -Verbose
        $SelectedAnything = $true
        VSCodeInstaller
    }
    if ($MicroTorrentBox.checked -eq $true) {
        Write-Host "System: "  -ForegroundColor Cyan -NoNewline
        Write-Host "uTorrent is checked for install..." -Verbose
        $SelectedAnything = $true
        uTorrentInstaller
    }
    if ($PuTTYBox.checked -eq $true) {
        Write-Host "System: "  -ForegroundColor Cyan -NoNewline
        Write-Host "PuTTY is checked for install..." -Verbose
        $SelectedAnything = $true
        puTTYInstaller
    }
    if ($WinDirStatBox.checked -eq $true) {
        Write-Host "System: "  -ForegroundColor Cyan -NoNewline
        Write-Host "WinDirStat is checked for install..." -Verbose
        $SelectedAnything = $true
        WinDirStatInstaller
    }
    if ($EtcherBox.checked -eq $true) {
        Write-Host "System: "  -ForegroundColor Cyan -NoNewline
        Write-Host "Etcher is checked for install..." -Verbose
        $SelectedAnything = $true
        EtcherInstaller
    }
    if ($FileZillaBox.checked -eq $true) {
        Write-Host "System: "  -ForegroundColor Cyan -NoNewline
        Write-Host "FileZilla is checked for install..." -Verbose
        $SelectedAnything = $true
        FileZillaInstaller
    }
    if ($ClassicShellBox.checked -eq $true) {
        Write-Host "System: "  -ForegroundColor Cyan -NoNewline
        Write-Host "ClassicShell is checked for install..." -Verbose
        $SelectedAnything = $true
        ClassicShellInstaller
    }
    if ($WarThunderBox.checked -eq $true) {
        Write-Host "System: "  -ForegroundColor Cyan -NoNewline
        Write-Host "WarThunder is checked for install..." -Verbose
        $SelectedAnything = $true
        WarThunderInstaller
    }
    if ($MalwareBytesBox.checked -eq $true) {
        Write-Host "System: "  -ForegroundColor Cyan -NoNewline
        Write-Host "MalwareBytes is checked for install..." -Verbose
        $SelectedAnything = $true
        MalwareBytesInstaller
    }
    if ($MPCHCBox.checked -eq $true) {
        Write-Host "System: "  -ForegroundColor Cyan -NoNewline
        Write-Host "MPCHC is checked for install..." -Verbose
        $SelectedAnything = $true
        MPCHCInstaller
    }
    if ($HWMONITORBox.checked -eq $true) {
        Write-Host "System: "  -ForegroundColor Cyan -NoNewline
        Write-Host "HWMONITOR is checked for install..." -Verbose
        $SelectedAnything = $true
        HWMONITORInstaller
    }
    if ($SpeedFanBox.checked -eq $true) {
        Write-Host "System: "  -ForegroundColor Cyan -NoNewline
        Write-Host "SpeedFan is checked for install..." -Verbose
        $SelectedAnything = $true
        SpeedFanInstaller
    }
    if ($MPVBox.checked -eq $true) {
        Write-Host "System: "  -ForegroundColor Cyan -NoNewline
        Write-Host "MPV is checked for install..." -Verbose
        $SelectedAnything = $true
        MPVInstaller
    }
}

function InstallFirefox {
    $architecture = (Get-WmiObject win32_processor | Where-Object {$_.deviceID -eq "CPU0"}).AddressWidth
    If ($architecture -eq "64") {
        $url = "https://download.mozilla.org/?product=firefox-latest&os=win64&lang=en-US"
    }
    else {
        $url = "https://download.mozilla.org/?product=firefox-latest&os=win&lang=en-US"
    }

    Write-Host "FFSetup: "  -ForegroundColor Cyan -NoNewline
    write-host "Downloading the latest Firefox for x$architecture"
    
    $output = ".\Data\Setup\FireFox.exe"
    $start_time = Get-Date

    Import-Module BitsTransfer
    Start-BitsTransfer -Source $url -Destination $output
    Write-Host "PShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s)"
    Write-Host "PShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Looking for and removing TMP files..."
    get-childitem ".\" -recurse -force -include *.TMP| remove-item -force
    Write-Host "FFSetup: "  -ForegroundColor Cyan -NoNewline
    Write-Host "Launching Installer, please wait..."
    $start_time = Get-Date
    Start-Process -FilePath ".\Data\Setup\FireFox.exe" -ArgumentList "/INI .\Data\FFSettings.ini -ms" -WindowStyle Normal -Wait
    Write-Host "PShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s)"
    Write-Host "PShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Checking..."
    
    $program = "Mozilla Firefox *"
    if ((IsInstalled $program) -eq $true) {
        Write-Host "FFSetup: "  -ForegroundColor Cyan -NoNewline
        Write-Host "Firefox installation check successful."
    }

    if ($KeepDataBox.Checked -eq $false) {
        get-childitem ".\Data\Setup" -recurse -force -include FireFox.*| remove-item -force
    }
    Write-Host "FFSetup: "  -ForegroundColor Cyan -NoNewline
    Write-Host "FireFox installation runtime complete!" 
}

function WaitForProgram($AppName) {
    $ProcessActive = Get-Process $AppName -ErrorAction SilentlyContinue
    if ($ProcessActive -eq $null) {
        Start-Sleep 1
        WaitForProgram($AppName)
    }
    else {   
        $P = Get-Process -Name $AppName
        Stop-Process -InputObject $P -Force
        Write-Host "PSShell: "  -ForegroundColor Green -NoNewline
        Write-Host "Process detected and ended!"
    }
}

function ChromeInstaller {
    Write-Host "Chrome: "  -ForegroundColor Cyan -NoNewline
    write-host "Downloading Google Chrome ..."
    $url = "https://dl.google.com/tag/s/appguid%3D%7B8A69D345-D564-463C-AFF1-A69D9E530F96%7D%26iid%3D%7B3AEF2011-5AB7-58B9-ADB4-AC7452443914%7D%26lang%3Den%26browser%3D3%26usagestats%3D0%26appname%3DGoogle%2520Chrome%26needsadmin%3Dprefers%26ap%3Dx64-stable-statsdef_1%26installdataindex%3Dempty/update2/installers/ChromeSetup.exe"
    $output = ".\Data\Setup\Chrome.exe"
    Import-Module BitsTransfer
    $start_time = Get-Date
    Start-BitsTransfer -Source $url -Destination $output

    Write-Host "PShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s)"
    Write-Host "PShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Looking for and removing TMP files..."
    get-childitem ".\" -recurse -force -include *.TMP| remove-item -force
    Write-Host "Google Chrome: "  -ForegroundColor Cyan -NoNewline
    Write-Host "Installing, this can take a while depending on your PC..."
    $start_time = Get-Date
    Start-Process -FilePath ".\Data\Setup\Chrome.exe" -ArgumentList "/install" -WindowStyle Normal -Wait
    WaitForProgram("chrome")
    Write-Host "PShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s)"

    if ($KeepDataBox.Checked -eq $false) {
        get-childitem ".\Data\Setup" -recurse -force -include "Chrome.*"| remove-item -force
    }
    Write-Host "Google Chrome: "  -ForegroundColor Cyan -NoNewline
    Write-Host "Chrome install complete!" 
}
function RunShutUp {
    Write-Host "System: "  -ForegroundColor Cyan -NoNewline
    Write-Host "Please wait while ShutUp10 configures your system..."

    Write-host "Downloading O&O ShutUp10" -ForegroundColor Cyan
    $url = "https://dl5.oo-software.com/files/ooshutup10/OOSU10.exe"
    $output = ".\Data\Setup\ShutUp10.exe"
    $start_time = Get-Date
    Import-Module BitsTransfer
    Start-BitsTransfer -Source $url -Destination $output
    Write-Output "Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s)"
    Write-Host "Looking for and removing TMP files..."
    get-childitem ".\" -recurse -force -include *.TMP| remove-item -force

    Write-Host "ShutUp10: "  -ForegroundColor Cyan -NoNewline
    Write-Host "Launching & Setting up recommended mode..."
    Start-Process -FilePath ".\data\Setup\ShutUp10.exe" -ArgumentList ".\Data\SU10-Recommended.cfg /quiet /force" -WindowStyle Normal -Wait
    Write-Host "PSShell: "  -ForegroundColor Green -NoNewline
    Write-Host "ShutUp process ended." -ForegroundColor Green
    Write-Host "Attention: "  -ForegroundColor Red -NoNewline
    Write-Host "Remember! System reboot HIGHLY recommended to apply settings." -ForegroundColor Gray

    if ($KeepDataBox.Checked -eq $false) {
        Write-Host "PSShell: "  -ForegroundColor Green -NoNewline
        Write-Host "Cleaning up and removing temporary data..."
        Remove-Item -Recurse ".\Data\Setup\ShutUp10.exe" | Out-Null -ErrorAction SilentlyContinue
    }
    Remove-Item -Recurse ".\OOSU10.ini" | Out-Null -ErrorAction SilentlyContinue
    Write-Host "ShutUp10: "  -ForegroundColor Green -NoNewline
    Write-Host "Setup complete!"
    Write-Host ""
}

function TorBrowserInstaller {
    $architecture = (Get-WmiObject win32_processor | Where-Object {$_.deviceID -eq "CPU0"}).AddressWidth
    If ($architecture -eq "64") {
        $url = "https://mirror.oldsql.cc/tor/dist/torbrowser/8.0.8/torbrowser-install-win64-8.0.8_en-US.exe"
        Write-Host "Tor: "  -ForegroundColor Cyan -NoNewline
        write-host "Downloading the latest Tor Browser package for x64"
    }
    else {
        $url = "https://mirror.oldsql.cc/tor/dist/torbrowser/8.0.8/torbrowser-install-8.0.8_en-US.exe"
        Write-Host "Tor: "  -ForegroundColor Cyan -NoNewline
        write-host "Downloading the latest Tor Browser package for x86"
    }
    $output = ".\Data\Setup\TBB-Latest.exe"

    Import-Module BitsTransfer
    $start_time = Get-Date
    Start-BitsTransfer -Source $url -Destination $output
    Write-Host "PSShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s)"
    Write-Host "PSShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Looking for and removing TMP files..."
    get-childitem ".\" -recurse -force -include *.TMP| remove-item -force
    Write-Host "Tor: "  -ForegroundColor Cyan -NoNewline
    Write-Host "Installing to the desktop, this can take a while depending on your PC..."
    Start-Process ".\Data\Setup\TBB-Latest.exe" -ArgumentList "/S" -ErrorAction SilentlyContinue -Wait
    if ($KeepDataBox.Checked -eq $false) {
        get-childitem ".\Data\Setup" -recurse -force -include TBB-Latest.*| remove-item -force -ErrorAction SilentlyContinue
    }
    Write-Host "Tor: "  -ForegroundColor Cyan -NoNewline
    write-host "Installation process completed!"
}

function SteamInstaller {
    Write-Host "SteamSetup: "  -ForegroundColor Cyan -NoNewline
    Write-host "Downloading the Steam Bootstrapper..." -ForegroundColor Cyan
    $url = "https://steamcdn-a.akamaihd.net/client/installer/SteamSetup.exe"
    $output = ".\Data\Setup\SteamInstaller.exe"

    Import-Module BitsTransfer
    Start-BitsTransfer -Source $url -Destination $output
    #OR -Asynchronous
    Write-Host "PSShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Looking for and removing TMP files..."
    get-childitem ".\" -recurse -force -include *.TMP| remove-item -force
    Write-Host "SteamSetup: "  -ForegroundColor Cyan -NoNewline
    Write-Host "Installing, please wait..."
    Start-Process ".\Data\Setup\SteamInstaller.exe" -ArgumentList "/S" -Wait
    Write-Host "Steam is now updating and will minimize itself shortly, if it doesn't, close steam and wait..."
    Start-Process "${env:ProgramFiles}\Steam\steam.exe" -ArgumentList "-silent" -Wait
    WaitForProgram("Steam")
    Write-Host ""
    if ($KeepDataBox.Checked -eq $false) {
        get-childitem ".\Data\Setup" -recurse -force -include SteamInstaller.*| remove-item -force
    }
}
${env:ProgramFiles}
function AvastInstaller {
    Write-Host "AvastSetup: "  -ForegroundColor Cyan -NoNewline
    Write-host "Downloading the latest Avast Free - Offline installer..." 
    $url = "https://install.avcdn.net/iavs9x/avast_free_antivirus_setup_offline.exe"
    $output = ".\Data\Setup\AvastOffline.exe"

    Import-Module BitsTransfer
    $start_time = Get-Date
    Start-BitsTransfer -Source $url -Destination $output
    Write-Host "PSShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s)"
    Write-Host "PSShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Looking for and removing TMP files..."
    get-childitem ".\" -recurse -force -include *.TMP| remove-item -force
    Write-Host "AvastSetup: "  -ForegroundColor Cyan -NoNewline
    Write-Host "Installing, this can take a while depending on your PC..."
    Start-Process ".\Data\Setup\AvastOffline.exe" -ArgumentList "/silent" -Wait
    if ($KeepDataBox.Checked -eq $false) {
        get-childitem ".\Data\Setup" -recurse -force -include AvastOffline.*| remove-item -force
    }
    Write-Host "AvastSetup: "  -ForegroundColor Cyan -NoNewline
    Write-Host "Checking service..."
    Write-Host "PSShell: " -ForegroundColor Green -NoNewline | FuncCheckService -ServiceName "Avast Antivirus"
    Write-Host "AvastSetup: "  -ForegroundColor Cyan -NoNewline
    write-host "Installation process completed!"
}
function AvastProInstaller {
    Write-Host "AvastProSetup: "  -ForegroundColor Cyan -NoNewline
    Write-host "Downloading the latest Avast Free - Offline installer..." 
    $url = "https://install.avcdn.net/iavs9x/avast_pro_antivirus_setup_offline.exe"
    $output = ".\Data\Setup\AvastOfflinePro.exe"

    Import-Module BitsTransfer
    $start_time = Get-Date
    Start-BitsTransfer -Source $url -Destination $output
    Write-Host "PSShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s)"
    #OR -Asynchronous
    Write-Host "PSShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Looking for and removing TMP files..."
    get-childitem ".\" -recurse -force -include *.TMP| remove-item -force
    Write-Host "AvastProSetup: "  -ForegroundColor Cyan -NoNewline
    Write-Host "Installing, this can take a while depending on your PC..."
    Start-Process ".\Data\Setup\AvastOfflinePro.exe" -ArgumentList "/silent" -Wait
    if ($KeepDataBox.Checked -eq $false) {
        get-childitem ".\Data\Setup" -recurse -force -include AvastOfflinePro.*| remove-item -force
    }
    Write-Host "AvastProSetup: "  -ForegroundColor Cyan -NoNewline
    Write-Host "Checking service..."
    Write-Host "PSShell: " -ForegroundColor Green -NoNewline | FuncCheckService -ServiceName "Avast Antivirus"
    Write-Host "AvastProSetup: "  -ForegroundColor Cyan -NoNewline
    write-host "Installation process completed!"
}
function 7ZipInstaller {
    $architecture = (Get-WmiObject win32_processor | Where-Object {$_.deviceID -eq "CPU0"}).AddressWidth
    If ($architecture -eq "64") {
        $url = "https://www.7-zip.org/a/7z1805-x64.exe"
        Write-Host "7ZSetup: "  -ForegroundColor Cyan -NoNewline
    write-host "Downloading 7-Zip for x64"
    
    }
    else {
        $url = "https://www.7-zip.org/a/7z1805.exe"
        Write-Host "7ZSetup: "  -ForegroundColor Cyan -NoNewline
    write-host "Downloading 7-Zip for x86"
    
    }
    $output = ".\Data\Setup\7Zip.exe"
    $start_time = Get-Date

    Import-Module BitsTransfer
    Start-BitsTransfer -Source $url -Destination $output
    Write-Host "PShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s)"
    Write-Host "PShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Looking for and removing TMP files..."
    get-childitem ".\" -recurse -force -include *.TMP| remove-item -force
    Write-Host "7ZSetup: "  -ForegroundColor Cyan -NoNewline
    Write-Host "Launching Installer, please wait..."
    $start_time = Get-Date
    Start-Process -FilePath ".\Data\Setup\7Zip.exe" -ArgumentList "/S" -WindowStyle Normal -Wait
    Write-Host "PShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s)"

    if ($KeepDataBox.Checked -eq $false) {
        get-childitem ".\Data\Setup" -recurse -force -include "7zip.*"| remove-item -force
    }
    Write-Host "7ZSetup: "  -ForegroundColor Cyan -NoNewline
    Write-Host "7Zip install complete!" 
}

function NotepadPLusPLusInstaller {
    $architecture = (Get-WmiObject win32_processor | Where-Object {$_.deviceID -eq "CPU0"}).AddressWidth
    If ($architecture -eq "64") {
        $url = "https://notepad-plus-plus.org/repository/7.x/7.6.3/npp.7.6.3.Installer.x64.exe"
        Write-Host "NotePad++: "  -ForegroundColor Cyan -NoNewline
        write-host "Downloading NotePad++ for x64"
    }
    else {
        $url = "https://notepad-plus-plus.org/repository/7.x/7.6.3/npp.7.6.3.Installer.exe"
        Write-Host "NotePad++: "  -ForegroundColor Cyan -NoNewline
        write-host "Downloading NotePad++ for x86"
    }

    $output = ".\Data\Setup\NotePadPLusPLus.exe"
    $start_time = Get-Date
    Import-Module BitsTransfer
    Start-BitsTransfer -Source $url -Destination $output
    Write-Host "PShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s)"
    Write-Host "PShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Looking for and removing TMP files..."
    get-childitem ".\" -recurse -force -include *.TMP| remove-item -force
    Write-Host "NotePad++: "  -ForegroundColor Cyan -NoNewline
    Write-Host "Launching NotePad++, please wait..."
    $start_time = Get-Date
    Start-Process -FilePath ".\Data\Setup\NotePadPLusPLus.exe" -ArgumentList "/S" -WindowStyle Normal -Wait
    Write-Host "PShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s)"

    if ($KeepDataBox.Checked -eq $false) {
        get-childitem ".\Data\Setup" -recurse -force -include "NotePadPLusPLus.*"| remove-item -force
    }
    Write-Host "NotePad++: "  -ForegroundColor Cyan -NoNewline
    Write-Host "NotePad++ installation complete!" 
}

function Win32DDInstaller {
    Write-Host "Win32DD: "  -ForegroundColor Cyan -NoNewline
    Write-host "Downloading the Win32DiskImager installer..." 
    $url = "https://sourceforge.net/projects/win32diskimager/files/Archive/win32diskimager-1.0.0-install.exe/download"
    $output = ".\Data\Setup\Win32DD.exe"

    Import-Module BitsTransfer
    $start_time = Get-Date
    Start-BitsTransfer -Source $url -Destination $output
    Write-Host "PSShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s)"
    Write-Host "PSShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Looking for and removing TMP files..."
    get-childitem ".\" -recurse -force -include *.TMP| remove-item -force
    Write-Host "Win32DD: "  -ForegroundColor Cyan -NoNewline
    Write-Host "Installing, this can take a while depending on your PC..."
    Start-Process ".\Data\Setup\Win32DD.exe" -ArgumentList "/silent /LOADINF=win32DD.inf /NORESTART" -Wait -ErrorAction SilentlyContinue
    if ($KeepDataBox.Checked -eq $false) {
        get-childitem ".\Data\Setup" -recurse -force -include Win32DD.*| remove-item -force
    }
    Write-Host "Win32DD: "  -ForegroundColor Cyan -NoNewline
    write-host "Installation process completed!"
}
function IMGBurnInstaller {
    Write-Host "IMGBurn: "  -ForegroundColor Cyan -NoNewline
    Write-host "Downloading the IMGBurn installer..." 
    $url = "http://download.imgburn.com/SetupImgBurn_2.5.8.0.exe"
    $output = ".\Data\Setup\IMGBurn.exe"

    Import-Module BitsTransfer
    $start_time = Get-Date
    Start-BitsTransfer -Source $url -Destination $output
    Write-Host "PSShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s)"
    Write-Host "PSShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Looking for and removing TMP files..."
    get-childitem ".\" -recurse -force -include *.TMP| remove-item -force
    Write-Host "IMGBurn: "  -ForegroundColor Cyan -NoNewline
    Write-Host "Installing, this can take a while depending on your PC..."
    Start-Process ".\Data\Setup\IMGBurn.exe" -ArgumentList "/S" -Wait -ErrorAction SilentlyContinue
    if ($KeepDataBox.Checked -eq $false) {
        get-childitem ".\Data\Setup" -recurse -force -include IMGBurn.*| remove-item -force
    }
    Write-Host "IMGBurn: "  -ForegroundColor Cyan -NoNewline
    write-host "Installation process completed!"
}

function TelegramInstaller {
    Write-Host "Telegram: "  -ForegroundColor Cyan -NoNewline
    Write-host "Downloading the Telegram installer..." 
    $url = "https://updates.tdesktop.com/tsetup/tsetup.1.5.1.exe"
    $output = ".\Data\Setup\Telegram.exe"

    Import-Module BitsTransfer
    $start_time = Get-Date
    Start-BitsTransfer -Source $url -Destination $output
    Write-Host "PSShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s)"
    Write-Host "PSShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Looking for and removing TMP files..."
    get-childitem ".\" -recurse -force -include *.TMP| remove-item -force
    Write-Host "Telegram: "  -ForegroundColor Cyan -NoNewline
    Write-Host "Installing, this can take a while depending on your PC..."
    Start-Process ".\Data\Setup\Telegram.exe" -ArgumentList "/SP- /VERYSILENT" -Wait
    if ($KeepDataBox.Checked -eq $false) {
        get-childitem ".\Data\Setup" -recurse -force -include Telegram.*| remove-item -force
    }
    Write-Host "Telegram: "  -ForegroundColor Cyan -NoNewline
    write-host "Installation process completed!"
}
function iTunesInstaller {
    $architecture = (Get-WmiObject win32_processor | Where-Object {$_.deviceID -eq "CPU0"}).AddressWidth
    If ($architecture -eq "64") {
        $url = "https://www.apple.com/itunes/download/win64"
        Write-Host "iTunesSetup: "  -ForegroundColor Cyan -NoNewline
        write-host "Downloading iTunes for x64"
    }
    else {
        $url = "https://www.apple.com/itunes/download/win32"
        Write-Host "iTunesSetup: "  -ForegroundColor Cyan -NoNewline
        write-host "Downloading iTunes for x86"
    }
    
    $output = ".\Data\Setup\iTunes.exe"
    $start_time = Get-Date

    Import-Module BitsTransfer
    Start-BitsTransfer -Source $url -Destination $output
    Write-Host "PShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s)"
    Write-Host "PShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Looking for and removing TMP files..."
    get-childitem ".\" -recurse -force -include *.TMP| remove-item -force
    Write-Host "iTunesSetup: "  -ForegroundColor Cyan -NoNewline
    Write-Host "Launching Installer, please wait..."
    $start_time = Get-Date
    Start-Process -FilePath ".\Data\Setup\iTunes.exe" -ArgumentList "/passive /norestart" -WindowStyle Normal -Wait
    Write-Host "PShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s)"

    if ($KeepDataBox.Checked -eq $false) {
        get-childitem ".\Data\Setup" -recurse -force -include "iTunes.*"| remove-item -force
    }
    Write-Host "iTunesSetup: "  -ForegroundColor Cyan -NoNewline
    Write-Host "iTunes install complete!" 
}

function gVimInstaller {
    Write-Host "gVim: "  -ForegroundColor Cyan -NoNewline
    Write-host "Downloading the gVim installer..." 
    $url = "https://github.com/petrkle/vim-msi/releases/download/v8.1.55/vim-8.1.55.msi"
    $output = ".\Data\Setup\gVim.msi"

    $wc = New-Object System.Net.WebClient
    $start_time = Get-Date
    $wc.DownloadFile($url, $output)
    Write-Host "PSShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s)"
    Write-Host "PSShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Looking for and removing TMP files..."
    get-childitem ".\" -recurse -force -include *.TMP| remove-item -force
    Write-Host "gVim: "  -ForegroundColor Cyan -NoNewline
    Write-Host "Installing, this can take a while depending on your PC..."
    Start-Process ".\Data\Setup\gVim.msi" -ArgumentList "/passive" -Wait
    if ($KeepDataBox.Checked -eq $false) {
        get-childitem ".\Data\Setup" -recurse -force -include gVim.*| remove-item -force
    }
    Write-Host "gVim: "  -ForegroundColor Cyan -NoNewline
    write-host "Installation process completed!"
}

function EUSPMInstaller {
    Write-Host "EPM: "  -ForegroundColor Cyan -NoNewline
    Write-host "Downloading the EasuseUS Partition Master (EPM) installer..." 
    $url = "http://download.easeus.com/free/epm.exe"
    $output = ".\Data\Setup\epm.exe"

    Import-Module BitsTransfer
    $start_time = Get-Date
    Start-BitsTransfer -Source $url -Destination $output
    Write-Host "PSShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s)"
    Write-Host "PSShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Looking for and removing TMP files..."
    get-childitem ".\" -recurse -force -include *.TMP| remove-item -force
    Write-Host "EPM: "  -ForegroundColor Cyan -NoNewline
    Write-Host "Installing, this can take a while depending on your PC..."
    Start-Process ".\Data\Setup\epm.exe" -ArgumentList "/SP- /VERYSILENT /NORESTART /LOADINF=./Data/EPM.inf /NOCANDY" -ErrorAction SilentlyContinue
    Write-Host "PSShell: "  -ForegroundColor Green -NoNewline
    Write-host  "Waiting for the EPM0 process to start which indicates a finished installation..."
    # Because EPM starts itself after installation, there is a loop that only exits after the main program is detected, and it closes it afterwards.
    WaitForProgram("EPM0")
    if ($KeepDataBox.Checked -eq $false) {
        get-childitem ".\Data\Setup" -recurse -force -include epm.*| remove-item -force
    }
    Write-Host "EPM: "  -ForegroundColor Cyan -NoNewline
    write-host "Installation process completed!"
}

function JavaJREInstaller {
    Write-Host "Java JRE: "  -ForegroundColor Cyan -NoNewline
    Write-Host "Downloading appropiate installer:"  -ForegroundColor Cyan

    $architecture = (Get-WmiObject win32_processor | Where-Object {$_.deviceID -eq "CPU0"}).AddressWidth
    If ($architecture -eq "64") {
        $url = "https://javadl.oracle.com/webapps/download/AutoDL?BundleId=236888_42970487e3af4f5aa5bca3f542482c60"
        write-host "Downloading Java for x64"
    }
    else {
        $url = "https://sdlc-esd.oracle.com/ESD6/JSCDL/jdk/8u201-b09/42970487e3af4f5aa5bca3f542482c60/JavaSetup8u201.exe?GroupName=JSC&FilePath=/ESD6/JSCDL/jdk/8u201-b09/42970487e3af4f5aa5bca3f542482c60/JavaSetup8u201.exe&BHost=javadl.sun.com&File=JavaSetup8u201.exe&AuthParam=1553440163_d88f54033d7a65be56ae655b91dc91b7&ext=.exe"
        write-host "Downloading Java for x86"
    }
    $output = ".\Data\Setup\JRE8.exe"

    Import-Module BitsTransfer
    $start_time = Get-Date
    Start-BitsTransfer -Source $url -Destination $output

    Write-Host "PSShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s)"
    Write-Host "PSShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Looking for and removing TMP files..."
    get-childitem ".\" -recurse -force -include *.TMP| remove-item -force
    Write-Host "Java JRE: "  -ForegroundColor Cyan -NoNewline
    Write-Host "Installing, this can take a while depending on your PC..."
    Start-Process ".\Data\Setup\JRE8.exe" -ArgumentList "/s" -Wait
    if ($KeepDataBox.Checked -eq $false) {
        get-childitem ".\Data\Setup" -recurse -force -include JRE8.*| remove-item -force
    }
    Write-Host "Java JRE: "  -ForegroundColor Cyan -NoNewline
    write-host "Installation process completed!"
}

function JavaSDKInstaller {
    Write-Host "Java SDK: "  -ForegroundColor Cyan -NoNewline
    Write-host "Downloading the Java SE Development Kit 11 installer..." 
    $url = "quinsoft.nl/other/jdk-11.0.2_windows-x64_bin.exe"
    $output = ".\Data\Setup\JDK.exe"

    $wc = New-Object System.Net.WebClient
    $start_time = Get-Date
    $wc.DownloadFile($url, $output)

    Write-Host "PSShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s)"
    Write-Host "PSShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Looking for and removing TMP files..."
    get-childitem ".\" -recurse -force -include *.TMP| remove-item -force
    Write-Host "Java SDK: "  -ForegroundColor Cyan -NoNewline
    Write-Host "Installing, this can take a while depending on your PC..."
    Start-Process ".\Data\Setup\JDK.exe" -ArgumentList "/s" -Wait
    if ($KeepDataBox.Checked -eq $false) {
        get-childitem ".\Data\Setup" -recurse -force -include JDK.*| remove-item -force
    }
    Write-Host "Java SDK: "  -ForegroundColor Cyan -NoNewline
    write-host "Installation process completed!"
}

function DotNET47Installer {
    Write-Host "Microsoft .NET 4.7: "  -ForegroundColor Cyan -NoNewline
    Write-host "Downloading the .NET 4.7 installer..." 
    $url = "https://download.microsoft.com/download/A/E/A/AEAE0F3F-96E9-4711-AADA-5E35EF902306/NDP47-KB3186500-Web.exe"
    $output = ".\Data\Setup\DotNET47.exe"

    Import-Module BitsTransfer
    $start_time = Get-Date
    Start-BitsTransfer -Source $url -Destination $output
    
    Write-Host "PSShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s)"
    Write-Host "PSShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Looking for and removing TMP files..."
    get-childitem ".\" -recurse -force -include *.TMP| remove-item -force
    Write-Host "Microsoft .NET 4.7: "  -ForegroundColor Cyan -NoNewline
    Write-Host "Installing, this can take a while depending on your PC..."
    Start-Process ".\Data\Setup\DotNET47.exe" -ArgumentList "/norestart /passive" -Wait
    if ($KeepDataBox.Checked -eq $false) {
        get-childitem ".\Data\Setup" -recurse -force -include DotNET47.*| remove-item -force
    }
    Write-Host "Microsoft .NET 4.7: "  -ForegroundColor Cyan -NoNewline
    write-host "Installation process completed!"
}

function TransmissionBTInstaller {
    $architecture = (Get-WmiObject win32_processor | Where-Object {$_.deviceID -eq "CPU0"}).AddressWidth
    If ($architecture -eq "64") {
        $url = "https://github.com/transmission/transmission-releases/raw/master/transmission-2.94-x64.msi"
        Write-Host "TransmissionSetup: "  -ForegroundColor Cyan -NoNewline
        write-host "Downloading Transmission for x64"
    }
    else {
        $url = "https://github.com/transmission/transmission-releases/raw/master/transmission-2.94-x86.msi"
        Write-Host "TransmissionSetup: "  -ForegroundColor Cyan -NoNewline
        write-host "Downloading Transmission for x86"
    }
   
    $output = ".\Data\Setup\TBT.msi"
    
    Import-Module BitsTransfer
    $start_time = Get-Date
    Start-BitsTransfer -Source $url -Destination $output

    Write-Host "PShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s)"
    Write-Host "PShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Looking for and removing TMP files..."
    get-childitem ".\" -recurse -force -include *.TMP| remove-item -force
    Write-Host "TransmissionBT: "  -ForegroundColor Cyan -NoNewline
    Write-Host "Installing, this can take a while depending on your PC..."
    $start_time = Get-Date
    Start-Process -FilePath ".\Data\Setup\TBT.msi" -ArgumentList "/passive /norestart" -WindowStyle Normal -Wait
    Write-Host "PShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s)"

    if ($KeepDataBox.Checked -eq $false) {
        get-childitem ".\Data\Setup" -recurse -force -include "TBT.*"| remove-item -force
    }
    Write-Host "TransmissionBT: "  -ForegroundColor Cyan -NoNewline
    Write-Host "Transmssion install complete!" 
}
function Aida64Installer {
    Write-Host "Aida64: "  -ForegroundColor Cyan -NoNewline
    Write-host "Downloading the Aida64 Extreme installer..." 
    $url = "http://download.aida64.com/aida64extreme599.exe"
    $output = ".\Data\Setup\Aida64Extreme.exe"

    Import-Module BitsTransfer
    $start_time = Get-Date
    Start-BitsTransfer -Source $url -Destination $output
    
    Write-Host "PSShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s)"
    Write-Host "PSShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Looking for and removing TMP files..."
    get-childitem ".\" -recurse -force -include *.TMP| remove-item -force
    Write-Host "Aida64: "  -ForegroundColor Cyan -NoNewline
    Write-Host "Installing, this can take a while depending on your PC..."
    Start-Process ".\Data\Setup\Aida64Extreme.exe" -ArgumentList "/ACCEPTBG /SILENT /SAFE" -Wait
    if ($KeepDataBox.Checked -eq $false) {
        get-childitem ".\Data\Setup" -recurse -force -include Aida64Extreme.*| remove-item -force
    }
    Write-Host "Aida64: "  -ForegroundColor Cyan -NoNewline
    write-host "Installation process completed!"
}
function ShockWaveInstaller {
    Write-Host "ShockWave: "  -ForegroundColor Cyan -NoNewline
    Write-host "Downloading the ShockWave installer..." 
    $url = "http://fpdownload.macromedia.com/get/shockwave/default/english/win95nt/latest/sw_lic_full_installer.msi"
    $output = ".\Data\Setup\ShockWave.msi"

    Import-Module BitsTransfer
    $start_time = Get-Date
    Start-BitsTransfer -Source $url -Destination $output
    
    Write-Host "PSShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s)"
    Write-Host "PSShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Looking for and removing TMP files..."
    get-childitem ".\" -recurse -force -include *.TMP| remove-item -force
    Write-Host "ShockWave: "  -ForegroundColor Cyan -NoNewline
    Write-Host "Installing, this can take a while depending on your PC..."
    Start-Process ".\Data\Setup\ShockWave.msi" -ArgumentList "/qn" -Wait
    if ($KeepDataBox.Checked -eq $false) {
        get-childitem ".\Data\Setup" -recurse -force -include ShockWave.*| remove-item -force
    }
    Write-Host "ShockWave: "  -ForegroundColor Cyan -NoNewline
    write-host "Installation process completed!"
}

function SilverLightInstaller {
    $architecture = (Get-WmiObject win32_processor | Where-Object {$_.deviceID -eq "CPU0"}).AddressWidth
    If ($architecture -eq "64") {
        $url = "https://download.microsoft.com/download/D/D/F/DDF23DF4-0186-495D-AA35-C93569204409/50918.00/Silverlight_x64.exe"
    }
    else {
        $url = "https://download.microsoft.com/download/D/D/F/DDF23DF4-0186-495D-AA35-C93569204409/50918.00/Silverlight.exe"
    }

    Write-Host "Silverlight: "  -ForegroundColor Cyan -NoNewline
    write-host "Downloading Silverlight for x$architecture"
    $output = ".\Data\Setup\Silverlight.exe"
    
    Import-Module BitsTransfer
    $start_time = Get-Date
    Start-BitsTransfer -Source $url -Destination $output

    Write-Host "PShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s)"
    Write-Host "PShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Looking for and removing TMP files..."
    get-childitem ".\" -recurse -force -include *.TMP| remove-item -force
    Write-Host "Silverlight: "  -ForegroundColor Cyan -NoNewline
    Write-Host "Installing, this can take a while depending on your PC..."
    $start_time = Get-Date
    Start-Process -FilePath ".\Data\Setup\Silverlight.exe" -ArgumentList "/q /doNotRequireDRMPrompt /noupdate" -WindowStyle Normal -Wait
    Write-Host "PShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s)"

    if ($KeepDataBox.Checked -eq $false) {
        get-childitem ".\Data\Setup" -recurse -force -include "Silverlight.*"| remove-item -force
    }
    Write-Host "Silverlight: "  -ForegroundColor Cyan -NoNewline
    Write-Host "Silverlight install complete!" 
}

function SpotifyInstaller {
    Write-Host "Spotify: "  -ForegroundColor Cyan -NoNewline
    Write-host "Downloading the Spotify installer..." 
    $url = "https://download.spotify.com/SpotifyFullSetup.exe"
    $output = ".\Data\Setup\SpotifyInstaller.exe"

    Import-Module BitsTransfer
    $start_time = Get-Date
    Start-BitsTransfer -Source $url -Destination $output
    
    Write-Host "PSShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s)"
    Write-Host "PSShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Looking for and removing TMP files..."
    get-childitem ".\" -recurse -force -include *.TMP| remove-item -force
    Write-Host "Spotify: "  -ForegroundColor Cyan -NoNewline
    Write-Host "Installing, this can take a while depending on your PC..."
    $encrypted = ConvertFrom-SecureString -SecureString $secure
    $MySecureCreds = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $Username, (ConvertTo-SecureString -String $encrypted)
    Start-Process -Credential $MySecureCreds -FilePath ".\Data\Setup\SpotifyInstaller.exe" -WindowStyle Normal
    Write-host "Spotify will close when the installation is complete, because unattended!"
    WaitForProgram("Spotify")
    if ($KeepDataBox.Checked -eq $false) {
        get-childitem ".\Data\Setup" -recurse -force -include SpotifyInstaller.*| remove-item -force
    }
    Write-Host "Spotify: "  -ForegroundColor Cyan -NoNewline
    write-host "Installation process completed!"
}

function OriginInstaller {
    Write-Host "Origin: "  -ForegroundColor Cyan -NoNewline
    Write-host "Downloading the EA Origin installer..." 
    $url = "https://www.dm.origin.com/download"
    $output = ".\Data\Setup\OriginInstaller.exe"

    Import-Module BitsTransfer
    $start_time = Get-Date
    Start-BitsTransfer -Source $url -Destination $output
    Write-Host "PSShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s)"
    Write-Host "PSShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Looking for and removing TMP files..."
    get-childitem ".\" -recurse -force -include *.TMP| remove-item -force
    Write-Host "Origin: "  -ForegroundColor Cyan -NoNewline
    Write-Host "Installing, this can take a while depending on your PC..."
    Start-Process ".\Data\Setup\OriginInstaller.exe" -ArgumentList "/silent" -ErrorAction SilentlyContinue
    Write-Host "PSShell: "  -ForegroundColor Green -NoNewline
    Write-host  "Waiting for the Origin process to start..."
    # Because Origin starts itself after installation, there is a loop that only exits after the main program is detected, and it closes it afterwards.
    WaitForProgram("Origin")
    if ($KeepDataBox.Checked -eq $false) {
        get-childitem ".\Data\Setup" -recurse -force -include OriginInstaller.*| remove-item -force -ErrorAction SilentlyContinue
    }
    Write-Host "Origin: "  -ForegroundColor Cyan -NoNewline
    write-host "Installation process completed!"
}

function VLCInstaller {
    $architecture = (Get-WmiObject win32_processor | Where-Object {$_.deviceID -eq "CPU0"}).AddressWidth
    If ($architecture -eq "64") {
        $url = "https://download.videolan.org/vlc/3.0.6/win64/vlc-3.0.6-win64.msi"
        Write-Host "VLC: "  -ForegroundColor Cyan -NoNewline
        write-host "Downloading VLC for x64"
    }
    else {
        $url = "https://download.videolan.org/vlc/3.0.6/win32/vlc-3.0.6-win32.msi"
        Write-Host "VLC: "  -ForegroundColor Cyan -NoNewline
        write-host "Downloading VLC for x86"
    }

    $output = ".\Data\Setup\VLC.msi"

    Import-Module BitsTransfer
    $start_time = Get-Date
    Start-BitsTransfer -Source $url -Destination $output
    
    Write-Host "PSShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s)"
    Write-Host "PSShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Looking for and removing TMP files..."
    get-childitem ".\" -recurse -force -include *.TMP| remove-item -force
    Write-Host "VLC: "  -ForegroundColor Cyan -NoNewline
    Write-Host "Installing, this can take a while depending on your PC..."
    Start-Process ".\Data\Setup\VLC.msi" -ArgumentList "/passive /norestart" -Wait
    if ($KeepDataBox.Checked -eq $false) {
        get-childitem ".\Data\Setup" -recurse -force -include VLC.*| remove-item -force
    }
    Write-Host "VLC: "  -ForegroundColor Cyan -NoNewline
    write-host "Installation process completed!"
}

function HWinfo64installer {
    Write-Host "HWInfo64: "  -ForegroundColor Cyan -NoNewline
    Write-host "Downloading the HWInfo64/32 installer..." 
    $url = "https://www.sac.sk/download/utildiag/hwi_600.exe"
    $output = ".\Data\Setup\HWInfo64Installer.exe"

    Import-Module BitsTransfer
    $start_time = Get-Date
    Start-BitsTransfer -Source $url -Destination $output
    Write-Host "PSShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s)"
    Write-Host "PSShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Looking for and removing TMP files..."
    get-childitem ".\" -recurse -force -include *.TMP| remove-item -force
    Write-Host "HWInfo64: "  -ForegroundColor Cyan -NoNewline
    Write-Host "Installing, this can take a while depending on your PC..."
    Start-Process ".\Data\Setup\HWInfo64Installer.exe" -ArgumentList "/VERYSILENT /NORESTART /SUPPRESSMSGBOXES" -ErrorAction SilentlyContinue
    Write-Host "PSShell: "  -ForegroundColor Green -NoNewline
    Write-host  "Waiting for the program process to start..."
    WaitForProgram("HWInfo64")
    if ($KeepDataBox.Checked -eq $false) {
        get-childitem ".\Data\Setup" -recurse -force -include HWInfo64Installer.*| remove-item -force -ErrorAction SilentlyContinue
    }
    Write-Host "HWInfo64: "  -ForegroundColor Cyan -NoNewline
    write-host "Installation process completed!"
}
function PowerISOInstaller {
    $architecture = (Get-WmiObject win32_processor | Where-Object {$_.deviceID -eq "CPU0"}).AddressWidth
    If ($architecture -eq "64") {
        $url = "http://dur9kfu3x1ijp.cloudfront.net/g421d_jxp6z1h/PowerISO7-x64.exe"
    }
    Write-Host "PowerISO: "  -ForegroundColor Cyan -NoNewline
    write-host "Downloading the latest PowerISO package for x64"
    else {
        $url = "http://d22ftg6r1s8s90.cloudfront.net/3!ol6x1kzmmu5/PowerISO7.exe"
        Write-Host "PowerISO: "  -ForegroundColor Cyan -NoNewline
        write-host "Downloading the latest PowerISO package for x86"
    }
    $output = "$RootPath\Data\Setup\PowerISO.exe"
    $wc = New-Object System.Net.WebClient
    $start_time = Get-Date
    $wc.DownloadFile($url, $output)

    Write-Host "PSShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s)"
    Write-Host "PSShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Looking for and removing TMP files..."
    get-childitem ".\" -recurse -force -include *.TMP| remove-item -force
    Write-Host "PowerISO: "  -ForegroundColor Cyan -NoNewline
    Write-Host "Installing, this can take a while depending on your PC..."
    Start-Process ".\Data\Setup\PowerISO.exe" -ArgumentList "/S" -ErrorAction SilentlyContinue -Wait
    if ($KeepDataBox.Checked -eq $false) {
        get-childitem ".\Data\Setup" -recurse -force -include PowerISO.exe.*| remove-item -force -ErrorAction SilentlyContinue
    }
    Write-Host "NOTICE: " -ForegroundColor Red -NoNewline
    Write-Host "You need to restart your computer before you can use the Virtual Drive Manager!"
    Write-Host "PowerISO: "  -ForegroundColor Cyan -NoNewline
    write-host "Installation process completed!"
}

function pycharmInstaller {
    Write-Host "pycharm: "  -ForegroundColor Cyan -NoNewline
    Write-host "Downloading the pycharm (Community Edition) installer..." 
    $url = "https://download-cf.jetbrains.com/python/pycharm-community-2018.3.4.exe"
    $output = ".\Data\Setup\pycharm.exe"

    Import-Module BitsTransfer
    $start_time = Get-Date
    Start-BitsTransfer -Source $url -Destination $output
    Write-Host "PSShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s)"
    Write-Host "PSShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Looking for and removing TMP files..."
    get-childitem ".\" -recurse -force -include *.TMP| remove-item -force
    Write-Host "pycharm: "  -ForegroundColor Cyan -NoNewline
    Write-Host "Installing, this can take a while depending on your PC..."
    Start-Process ".\Data\Setup\pycharm.exe" -ArgumentList "/S /CONFIG=$RootPath\Data\pycharm.config /D=$env:ProgramFiles\JetBrains\PyCharm Community Edition 2018.3.4" -ErrorAction SilentlyContinue -Wait
    if ($KeepDataBox.Checked -eq $false) {
        get-childitem ".\Data\Setup" -recurse -force -include pycharm.*| remove-item -force -ErrorAction SilentlyContinue
    }
    Write-Host "pycharm: "  -ForegroundColor Cyan -NoNewline
    write-host "Installation process completed!"
}

function BlenderInstaller {
    $architecture = (Get-WmiObject win32_processor | Where-Object {$_.deviceID -eq "CPU0"}).AddressWidth
    If ($architecture -eq "64") {
        $url = "https://ftp.nluug.nl/pub/graphics/blender/release/Blender2.79/blender-2.79b-windows64.msi"
        Write-Host "Blender: "  -ForegroundColor Cyan -NoNewline
        write-host "Downloading the latest Blender installer for x64"
    }
    else {
        $url = "https://ftp.nluug.nl/pub/graphics/blender/release/Blender2.79/blender-2.79b-windows32.msi"
        Write-Host "Blender: "  -ForegroundColor Cyan -NoNewline
        write-host "Downloading the latest Blender installer for x86"
    }

    $output = ".\Data\Setup\Blender.msi"
    Import-Module BitsTransfer
    $start_time = Get-Date
    Start-BitsTransfer -Source $url -Destination $output

    Write-Host "PSShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s)"
    Write-Host "PSShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Looking for and removing TMP files..."
    get-childitem ".\" -recurse -force -include *.TMP| remove-item -force
    Write-Host "Blender: "  -ForegroundColor Cyan -NoNewline
    Write-Host "Installing, this can take a while depending on your PC..."
    Start-Process ".\Data\Setup\Blender.msi" -ArgumentList "/norestart /passive" -ErrorAction SilentlyContinue -Wait
    if ($KeepDataBox.Checked -eq $false) {
        get-childitem ".\Data\Setup" -recurse -force -include Blender.exe.*| remove-item -force -ErrorAction SilentlyContinue
    }
    Write-Host "Blender: "  -ForegroundColor Cyan -NoNewline
    write-host "Installation process completed!"
}
function Foobar2000Installer {
    Write-Host "Foobar2000: "  -ForegroundColor Cyan -NoNewline
    Write-host "Downloading the Foobar2000 installer..." 
    $url = "http://files1.majorgeeks.com/c7e9c7545fe84025f5aa6dd945c474e3c988300c/multimedia/foobar2000_v1.4.3.exe"
    $output = ".\Data\Setup\Foobar2000.exe"
    
    Import-Module BitsTransfer
    $start_time = Get-Date
    Start-BitsTransfer -Source $url -Destination $output
    Write-Host "PSShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s)"
    Write-Host "PSShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Looking for and removing TMP files..."
    get-childitem ".\" -recurse -force -include *.TMP| remove-item -force
    Write-Host "Foobar2000: "  -ForegroundColor Cyan -NoNewline
    Write-Host "Installing, this can take a while depending on your PC..."
    Start-Process ".\Data\Setup\Foobar2000.exe" -ArgumentList "/S" -ErrorAction SilentlyContinue -Wait
    if ($KeepDataBox.Checked -eq $false) {
        get-childitem ".\Data\Setup" -recurse -force -include Foobar2000.*| remove-item -force -ErrorAction SilentlyContinue
    }
    Write-Host "Foobar2000: "  -ForegroundColor Cyan -NoNewline
    write-host "Installation process completed!"
}
function VivaldiInstaller {
    Write-Host "Vivaldi: "  -ForegroundColor Cyan -NoNewline
    Write-host "Downloading the Vivaldi installer..." 
    $architecture = (Get-WmiObject win32_processor | Where-Object {$_.deviceID -eq "CPU0"}).AddressWidth
    If ($architecture -eq "64") {
        $url = "https://downloads.vivaldi.com/stable/Vivaldi.2.3.1440.61.x64.exe"
    }
    else {
        $url = "https://downloads.vivaldi.com/stable/Vivaldi.2.3.1440.61.exe"
    }
    $output = ".\Data\Setup\Vivaldi.exe"
    
    Import-Module BitsTransfer
    $start_time = Get-Date
    Start-BitsTransfer -Source $url -Destination $output
    Write-Host "PSShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s)"
    Write-Host "PSShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Looking for and removing TMP files..."
    get-childitem ".\" -recurse -force -include *.TMP| remove-item -force
    Write-Host "Vivaldi: "  -ForegroundColor Cyan -NoNewline
    Write-Host "Installing, this can take a while depending on your PC..."
    Start-Process ".\Data\Setup\Vivaldi.exe" -ArgumentList "--vivaldi-silent --do-not-launch-chrome --vivaldi-update" -ErrorAction SilentlyContinue -Wait
    if ($KeepDataBox.Checked -eq $false) {
        get-childitem ".\Data\Setup" -recurse -force -include Vivaldi.*| remove-item -force -ErrorAction SilentlyContinue
    }
    Write-Host "Vivaldi: "  -ForegroundColor Cyan -NoNewline
    write-host "Installation process completed!"
}
function CPythonInstaller {
    Write-Host "Python: "  -ForegroundColor Cyan -NoNewline
    Write-host "Downloading the Python installer..." 
    $url = "https://www.python.org/ftp/python/3.7.2/python-3.7.2.exe"
    $output = ".\Data\Setup\Python.exe"
    
    Import-Module BitsTransfer
    $start_time = Get-Date
    Start-BitsTransfer -Source $url -Destination $output
    Write-Host "PSShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s)"
    Write-Host "PSShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Looking for and removing TMP files..."
    get-childitem ".\" -recurse -force -include *.TMP| remove-item -force
    Write-Host "Python: "  -ForegroundColor Cyan -NoNewline
    Write-Host "Installing, this can take a while depending on your PC..."
    Start-Process ".\Data\Setup\Python.exe" -ArgumentList "/quiet InstallAllUsers=1 PrependPath=1 Include_test=0 TargetDir=c:\Python372 Shortcuts=1" -ErrorAction SilentlyContinue -Wait
    if ($KeepDataBox.Checked -eq $false) {
        get-childitem ".\Data\Setup" -recurse -force -include Python.*| remove-item -force -ErrorAction SilentlyContinue
    }
    Write-Host "Python: "  -ForegroundColor Cyan -NoNewline
    write-host "Installation process completed!"
}
function MusicBeeInstaller {
    Write-Host "MusicBee: "  -ForegroundColor Cyan -NoNewline
    write-host "Downloading the latest MusicBee installer for x$architecture"
    $url = "https://www.mediafire.com/file/013558ft0oyuf3b/MusicBeeSetup_3_2_Update3.zip/file"
    $output = ".\Data\Setup\MusicBee.zip"
    Import-Module BitsTransfer
    $start_time = Get-Date
    #Download zip
    Start-BitsTransfer -Source $url -Destination $output
    #Check for and unpack the ZIP
    $workdir = $RootPath + "\Data\Setup\MusicBee"
    If (Test-Path -Path $workdir -PathType Container){
         Write-Host "$workdir already exists" -ForegroundColor Green
         Expand-Archive ".\Data\Setup\MusicBee.zip" -DestinationPath ".\Data\Setup\MusicBee" -Force} 
    else{ New-Item -Path $workdir  -ItemType directory -Force
       Expand-Archive ".\Data\Setup\MusicBee.zip" -DestinationPath ".\Data\Setup\MusicBee" -Force
    }
    Write-Host "PSShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s)"
    Write-Host "PSShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Looking for and removing TMP files..."
    get-childitem ".\" -recurse -force -include *.TMP| remove-item -force
    #See if the EXE exists, if so run it, if not, inform the user.
    if (Test-Path -Path ".\Data\Setup\MusicBee\MusicBeeSetup_3_2_Update3.exe"){
        Write-Host "MusicBee: "  -ForegroundColor Cyan -NoNewline
        Write-Host "Installing, this can take a while depending on your PC..."
        Start-Process ".\Data\Setup\MusicBee\MusicBeeSetup_3_2_Update3.exe" -ArgumentList "/S /NCRC" -ErrorAction SilentlyContinue -Wait
    }
    else {
        Write-Host "NOTICE: " -ForegroundColor Red -NoNewline
        Write-Host "File was not found, something might have gone wrong!"
    }
    if ($KeepDataBox.Checked -eq $false) {
        remove-item ".\Data\Setup\MusicBee" -force -ErrorAction SilentlyContinue -recurse   
        remove-item ".\Data\Setup\MusicBee.zip" -force -ErrorAction SilentlyContinue -Recurse
    }   
    Write-Host "MusicBee: "  -ForegroundColor Cyan -NoNewline
    write-host "Installation process completed!"
}

function TeamViewerInstaller {
    Write-Host "TeamViewer: "  -ForegroundColor Cyan -NoNewline
    Write-host "Downloading the TeamViewer installer..." 
    $url = "https://dl.tvcdn.de/download/TeamViewer_Setup.exe"
    $output = ".\Data\Setup\TeamViewer.exe"
    
    Import-Module BitsTransfer
    $start_time = Get-Date
    Start-BitsTransfer -Source $url -Destination $output
    Write-Host "PSShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s)"
    Write-Host "PSShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Looking for and removing TMP files..."
    get-childitem ".\" -recurse -force -include *.TMP| remove-item -force
    Write-Host "TeamViewer: "  -ForegroundColor Cyan -NoNewline
    Write-Host "Installing, this can take a while depending on your PC..."
    Start-Process ".\Data\Setup\TeamViewer.exe" -ArgumentList "/S" -ErrorAction SilentlyContinue -Wait
    if ($KeepDataBox.Checked -eq $false) {
        get-childitem ".\Data\Setup" -recurse -force -include Python.*| remove-item -force -ErrorAction SilentlyContinue
    }
    Write-Host "TeamViewer: "  -ForegroundColor Cyan -NoNewline
    write-host "Installation process completed!"
}

function VSCodeInstaller {
    $architecture = (Get-WmiObject win32_processor | Where-Object {$_.deviceID -eq "CPU0"}).AddressWidth
    If ($architecture -eq "64") {
        $url = "https://aka.ms/win32-x64-user-stable"
        Write-Host "VSCode: "  -ForegroundColor Cyan -NoNewline
    write-host "Downloading the latest Visual Studio Code installer for x64"
    }
    else {
        $url = "https://go.microsoft.com/fwlink/?LinkID=623230"
        Write-Host "VSCode: "  -ForegroundColor Cyan -NoNewline
        write-host "Downloading the latest Visual Studio Code installer for x86"
    }
    
    $output = ".\Data\Setup\VSCode.exe"
    Import-Module BitsTransfer
    $start_time = Get-Date
    Start-BitsTransfer -Source $url -Destination $output

    Write-Host "PSShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s)"
    Write-Host "PSShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Looking for and removing TMP files..."
    get-childitem ".\" -recurse -force -include *.TMP| remove-item -force
    Write-Host "VSCode: "  -ForegroundColor Cyan -NoNewline
    Write-Host "Installing, this can take a while depending on your PC..."
    Start-Process ".\Data\Setup\VSCode-x$architecture.exe" -ArgumentList "/SP- /SILENT /NORESTART /SUPPRESSMSGBOXES /LOADINF=VSCode.inf" -ErrorAction SilentlyContinue
    Write-Host "PSShell: "  -ForegroundColor Green -NoNewline
    Write-host  "Waiting for the program process to start..."
    WaitForProgram("Code")
    if ($KeepDataBox.Checked -eq $false) {
        get-childitem ".\Data\Setup" -recurse -force -include VSCode-x$architecture.exe.*| remove-item -force -ErrorAction SilentlyContinue
    }
    Write-Host "VSCode: "  -ForegroundColor Cyan -NoNewline
    write-host "Installation process completed!"
}
function uTorrentInstaller {
    Write-Host "uTorrent: "  -ForegroundColor Cyan -NoNewline
    Write-host "Downloading the uTorrent installer..." 
    #Source: https://rubenalamina.mx/custom-installers/downloads/
    #Non-official installer.
    $url = "https://downloads.rubenalamina.mx/custom-installers/uTorrent%203.5.0.44090.msi"
    $output = ".\Data\Setup\uTorrent.msi"
    
    Import-Module BitsTransfer
    $start_time = Get-Date
    Start-BitsTransfer -Source $url -Destination $output
    Write-Host "PSShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s)"
    Write-Host "PSShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Looking for and removing TMP files..."
    get-childitem ".\" -recurse -force -include *.TMP| remove-item -force
    Write-Host "uTorrent: "  -ForegroundColor Cyan -NoNewline
    Write-Host "Installing, this can take a while depending on your PC..."
    Start-Process ".\Data\Setup\uTorrent.msi" -ArgumentList "/passive" -ErrorAction SilentlyContinue -Wait
    if ($KeepDataBox.Checked -eq $false) {
        get-childitem ".\Data\Setup" -recurse -force -include uTorrent.*| remove-item -force -ErrorAction SilentlyContinue
    }
    Write-Host "uTorrent: "  -ForegroundColor Cyan -NoNewline
    write-host "Installation process completed!"
}
function puTTYInstaller {
    $architecture = (Get-WmiObject win32_processor | Where-Object {$_.deviceID -eq "CPU0"}).AddressWidth
    If ($architecture -eq "64") {
        $url = "https://the.earth.li/~sgtatham/putty/0.70/w64/putty-64bit-0.70-installer.msi"
        Write-Host "puTTY: "  -ForegroundColor Cyan -NoNewline
        write-host "Downloading the latest puTTY installer for x64"
    }
    else {
        $url = "https://the.earth.li/~sgtatham/putty/0.70/w32/putty-0.70-installer.msi"
        Write-Host "puTTY: "  -ForegroundColor Cyan -NoNewline
        write-host "Downloading the latest puTTY installer for x86"
    }
    $output = ".\Data\Setup\puTTY.msi"
    
    Import-Module BitsTransfer
    $start_time = Get-Date
    Start-BitsTransfer -Source $url -Destination $output
    Write-Host "PSShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s)"
    Write-Host "PSShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Looking for and removing TMP files..."
    get-childitem ".\" -recurse -force -include *.TMP| remove-item -force
    Write-Host "puTTY: "  -ForegroundColor Cyan -NoNewline
    Write-Host "Installing, this can take a while depending on your PC..."
    Start-Process ".\Data\Setup\puTTY-$architecture.msi" -ArgumentList "/passive" -ErrorAction SilentlyContinue -Wait
    if ($KeepDataBox.Checked -eq $false) {
        get-childitem ".\Data\Setup" -recurse -force -include puTTY-$architecture.*| remove-item -force -ErrorAction SilentlyContinue
    }
    Write-Host "puTTY: "  -ForegroundColor Cyan -NoNewline
    write-host "Installation process completed!"
}
function MPVInstaller {
    #Sources used:
    #https://github.com/rossy/mpv-install/blob/master/README.md
    #https://mpv.srsfckn.biz/
    Write-Host "QTSS: "  -ForegroundColor Green -NoNewline
    Write-Host "This installer is a bit more complicated and will take longer. Please hang on tight!"
    #Check for 7-zip for unpacking
    if(IsInstalled "7-zip *"){
        Write-Host "MPV: " -ForegroundColor Cyan -NoNewline
        Write-Host "7-zip detected, moving on!"
    }
    else{
        Write-Host "MPV did not detect 7-zip! Installing now..."
        7ZipInstaller
        if(IsInstalled "7-zip *"){
            Write-Host "MPV: " -ForegroundColor Cyan -NoNewline
            Write-Host "7-zip detected, moving on!"}
        else{
            Write-Host "NOTICE:" -ForegroundColor Red -NoNewline
            Write-host "Something might have gone wrong!"
        }
    }
    #Check for and create folders:
    $architecture = (Get-WmiObject win32_processor | Where-Object {$_.deviceID -eq "CPU0"}).AddressWidth
    If ($architecture -eq "64") {
        $workdir="$env:ProgramFiles\MPV"
        Write-Host "MPV: "  -ForegroundColor Cyan -NoNewline
        Write-Host "We will install in: $workdir"
        $url = "https://mpv.srsfckn.biz/mpv-x86_64-20181002.7z"
        if (Test-Path -Path $workdir){
            Write-Host "MPV: "  -ForegroundColor Cyan -NoNewline
            Write-Host "Program Files folder already exists"
        }
        else{
            New-Item -Path $workdir -ItemType directory -Force -ErrorAction SilentlyContinue | Out-Null
            if (Test-Path -Path $workdir){
                Write-Host "MPV: "  -ForegroundColor Cyan -NoNewline
                Write-Host "Program Files folder created."
            }
        }
    }
    else {
        $workdir="${env:ProgramFiles}\MPV"
        Write-Host "MPV: "  -ForegroundColor Cyan -NoNewline
        Write-Host "We will install in: $workdir"
        $url = "https://mpv.srsfckn.biz/mpv-i686-20181002.7z"
        if (Test-Path -Path $workdir){
            Write-Host "MPV: "  -ForegroundColor Cyan -NoNewline
            Write-Host "Program Files folder already exists"
        }
        else{
            New-Item -Path $workdir -ItemType directory -Force -ErrorAction SilentlyContinue | Out-Null
            if (Test-Path -Path "$env:ProgramFiles\MPV"){
                Write-Host "MPV: "  -ForegroundColor Cyan -NoNewline
                Write-Host "Program Files folder created."
            }}
    }
    #Download main programs
    Write-Host "MPV: "  -ForegroundColor Cyan -NoNewline
    write-host "Downloading the latest packages..."
    Import-Module BitsTransfer
    $output = $workdir
    $start_time = Get-Date
    Start-BitsTransfer -Source $url -Destination $output
   
    #Load other programs
    $url="http://files1.majorgeeks.com/25dcebea83db17fa4a0c564d830ff19d8c4c3d81/internet/youtube-dl.exe"
    Start-BitsTransfer -Source $url -Destination $output
    if (Test-Path -Path "$output\youtube-dl.exe"){
        Write-Host "MPV: "  -ForegroundColor Cyan -NoNewline
        Write-Host "youtube-dl downloaded."
    }
    $url="http://quinsoft.nl/NL/Data/Other/install.zip"
    $output="./install.zip"
    Start-BitsTransfer -Source $url -Destination $output
    if (Test-Path -Path $output){
        Write-Host "MPV: "  -ForegroundColor Cyan -NoNewline
        Write-Host "Unpacking installation script..."
        Expand-Archive -Path $output -DestinationPath "$workdir" -Force
        Move-Item  -Path "$workdir\mpv-install-master\*.*" -Destination $workdir -Force
        if (Test-Path -Path "$workdir\mpv-install-master"){
        Remove-Item  -Path "$workdir\mpv-install-master" -Force -Recurse
        }
        if (Test-Path -Path "$workdir\install.zip"){
            Remove-Item  -Path "$workdir\install.zip" -Force -Recurse
        }
        if (Test-Path -Path "$workdir\mpv-install.bat"){
            Write-Host "MPV: "  -ForegroundColor Cyan -NoNewline
            Write-Host "Installer unpacked."
        }
        else{
            Write-Host "NOTICE: " -ForegroundColor Red -NoNewline
            Write-host "File not found, something might have gone wrong!"
        }
    }
     Write-Host "PSShell: "  -ForegroundColor Green -NoNewline
     Write-Host "Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s)"
     #Unpack main application's package
    Start-Process "$env:ProgramFiles\7-Zip\7z.exe" -ArgumentList "e .\mpv-x86_64-20181002.7z -aoa" -Wait -PassThru
    if (Test-Path -Path ".\mpv.exe"){
        Write-Host "MPV: "  -ForegroundColor Cyan -NoNewline
        Write-Host "Main application unpacked, setting up file associations..."
        Write-host "Please Wait!" -ForegroundColor Green
        Start-Process ".\mpv-install.bat" -ArgumentList "/u" -Wait
    }
    Write-Host "MPV: "  -ForegroundColor Cyan -NoNewline
    Write-Host "Process complete, if there were no errors, you should now be able to set MPV as your default media player via the control panel."

}

function WinDirStatInstaller {
    Write-Host "WinDirStat: "  -ForegroundColor Cyan -NoNewline
    Write-host "Downloading the WinDirStat installer..." 
    $url = "https://windirstat.mirror.wearetriple.com/wds_current_setup.exe"
    $output = ".\Data\Setup\WinDirStat.exe"
    
    Import-Module BitsTransfer
    $start_time = Get-Date
    Start-BitsTransfer -Source $url -Destination $output
    Write-Host "PSShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s)"
    Write-Host "PSShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Looking for and removing TMP files..."
    get-childitem ".\" -recurse -force -include *.TMP| remove-item -force
    Write-Host "WinDirStat: "  -ForegroundColor Cyan -NoNewline
    Write-Host "Installing, this can take a while depending on your PC..."
    Start-Process ".\Data\Setup\WinDirStat.exe" -ArgumentList "/S" -ErrorAction SilentlyContinue -Wait
    if ($KeepDataBox.Checked -eq $false) {
        get-childitem ".\Data\Setup" -recurse -force -include WinDirStat.*| remove-item -force -ErrorAction SilentlyContinue
    }
    Write-Host "WinDirStat: "  -ForegroundColor Cyan -NoNewline
    write-host "Installation process completed!"
}
function EtcherInstaller {
    $architecture = (Get-WmiObject win32_processor | Where-Object {$_.deviceID -eq "CPU0"}).AddressWidth
    If ($architecture -eq "64") {
        $url = "https://files01.tchspt.com/temp/Etcher-Setup-1.4.9-x64.exe"
        Write-Host "Etcher: "  -ForegroundColor Cyan -NoNewline
        write-host "Downloading the latest Etcher installer for x64"
    }
    else {
        $url = "https://files01.tchspt.com/temp/Etcher-Setup-1.4.9-x86.exe"
        Write-Host "Etcher: "  -ForegroundColor Cyan -NoNewline
        write-host "Downloading the latest Etcher installer for x86"
    }

    $output = ".\Data\Setup\Etcher.exe"
    
    Import-Module BitsTransfer
    $start_time = Get-Date
    Start-BitsTransfer -Source $url -Destination $output
    Write-Host "PSShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s)"
    Write-Host "PSShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Looking for and removing TMP files..."
    get-childitem ".\" -recurse -force -include *.TMP| remove-item -force
    Write-Host "Etcher: "  -ForegroundColor Cyan -NoNewline
    Write-Host "Installing, this can take a while depending on your PC..."
    Start-Process ".\Data\Setup\Etcher-$architecture.exe" -ArgumentList "/S /NCRC" -ErrorAction SilentlyContinue -Wait
    if ($KeepDataBox.Checked -eq $false) {
        get-childitem ".\Data\Setup" -recurse -force -include Etcher.*| remove-item -force -ErrorAction SilentlyContinue
    }
    Write-Host "Etcher: "  -ForegroundColor Cyan -NoNewline
    write-host "Installation process completed!"
}
function FileZillaInstaller {
    $architecture = (Get-WmiObject win32_processor | Where-Object {$_.deviceID -eq "CPU0"}).AddressWidth
    If ($architecture -eq "64") {
        $url = "https://dl4.cdn.filezilla-project.org/client/FileZilla_3.41.2_win64-setup.exe?h=fKJZemAfE6zXhjggUtAjAQ&x=1553449810"
        Write-Host "FileZilla: "  -ForegroundColor Cyan -NoNewline
        write-host "Downloading the latest FileZilla installer for x64"
    }
    else {
        $url = "https://dl4.cdn.filezilla-project.org/client/FileZilla_3.41.2_win32-setup.exe?h=j1FbaD6BthcGo5RTA5IeBw&x=1553449810"
        Write-Host "FileZilla: "  -ForegroundColor Cyan -NoNewline
        write-host "Downloading the latest FileZilla installer for x86"
    }
    $output = ".\Data\Setup\FileZilla.exe"
    
    Import-Module BitsTransfer
    $start_time = Get-Date
    Start-BitsTransfer -Source $url -Destination $output
    Write-Host "PSShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s)"
    Write-Host "PSShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Looking for and removing TMP files..."
    get-childitem ".\" -recurse -force -include *.TMP| remove-item -force
    Write-Host "FileZilla: "  -ForegroundColor Cyan -NoNewline
    Write-Host "Installing, this can take a while depending on your PC..."
    Start-Process ".\Data\Setup\FileZilla-$architecture.exe" -ArgumentList "/S /NOCANDY" -ErrorAction SilentlyContinue -Wait
    if ($KeepDataBox.Checked -eq $false) {
        get-childitem ".\Data\Setup" -recurse -force -include FileZilla.*| remove-item -force -ErrorAction SilentlyContinue
    }
    Write-Host "FileZilla: "  -ForegroundColor Cyan -NoNewline
    write-host "Installation process completed!"
}

function ClassicShellInstaller {
    Write-Host "ClassicShell: "  -ForegroundColor Cyan -NoNewline
    Write-host "Downloading the ClassicShell installer..." 
    $url = "http://classicshell.mediafire.com/file/d5llbbm8wu92jg8/ClassicShellSetup_4_3_1.exe"
    $output = ".\Data\Setup\ClassicShell.exe"
    
    Import-Module BitsTransfer
    $start_time = Get-Date
    Start-BitsTransfer -Source $url -Destination $output
    Write-Host "PSShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s)"
    Write-Host "PSShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Looking for and removing TMP files..."
    get-childitem ".\" -recurse -force -include *.TMP| remove-item -force
    Write-Host "ClassicShell: "  -ForegroundColor Cyan -NoNewline
    Write-Host "Installing, this can take a while depending on your PC..."
    Start-Process ".\Data\Setup\ClassicShell.exe" -ArgumentList "/qn" -ErrorAction SilentlyContinue -Wait
    if ($KeepDataBox.Checked -eq $false) {
        get-childitem ".\Data\Setup" -recurse -force -include ClassicShell.*| remove-item -force -ErrorAction SilentlyContinue
    }
    Write-Host "ClassicShell: "  -ForegroundColor Cyan -NoNewline
    write-host "Installation process completed!"
}

function WarThunderInstaller {
    Write-Host "WarThunder: "  -ForegroundColor Cyan -NoNewline
    Write-host "Downloading the WarThunder installer..." 
    $url = "https://cdnnow-distr.gaijinent.com/wt_launcher_1.0.3.148.exe?distr=xn6yzb556"
    $output = ".\Data\Setup\WarThunder.exe"
    
    Import-Module BitsTransfer
    $start_time = Get-Date
    Start-BitsTransfer -Source $url -Destination $output
    Write-Host "PSShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s)"
    Write-Host "PSShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Looking for and removing TMP files..."
    get-childitem ".\" -recurse -force -include *.TMP| remove-item -force
    Write-Host "WarThunder: "  -ForegroundColor Cyan -NoNewline
    Write-Host "Installing, this can take a while depending on your PC..."
    Start-Process ".\Data\Setup\WarThunder.exe" -ArgumentList "/SP- /NORESTART /VERYSILENT" -ErrorAction SilentlyContinue -Wait
    if ($KeepDataBox.Checked -eq $false) {
        get-childitem ".\Data\Setup" -recurse -force -include WarThunder.*| remove-item -force -ErrorAction SilentlyContinue
    }
    Write-Host "WarThunder: "  -ForegroundColor Cyan -NoNewline
    write-host "Installation process completed!"
}
function MalwareBytesInstaller {
    Write-Host "MalwareBytes: "  -ForegroundColor Cyan -NoNewline
    Write-host "Downloading the  latest MalwareBytes installer..." 
    $url = "https://downloads.malwarebytes.com/file/mb3"
    $output = ".\Data\Setup\MalwareBytes.exe"
    
    Import-Module BitsTransfer
    $start_time = Get-Date
    Start-BitsTransfer -Source $url -Destination $output
    Write-Host "PSShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s)"
    Write-Host "PSShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Looking for and removing TMP files..."
    get-childitem ".\" -recurse -force -include *.TMP| remove-item -force
    Write-Host "MalwareBytes: "  -ForegroundColor Cyan -NoNewline
    Write-Host "Installing, this can take a while depending on your PC..."
    Start-Process ".\Data\Setup\MalwareBytes.exe" -ArgumentList "/SP- /NORESTART /VERYSILENT" -ErrorAction SilentlyContinue -Wait
    if ($KeepDataBox.Checked -eq $false) {
        get-childitem ".\Data\Setup" -recurse -force -include MalwareBytes.*| remove-item -force -ErrorAction SilentlyContinue
    }
    Write-Host "MalwareBytes: "  -ForegroundColor Cyan -NoNewline
    write-host "Installation process completed!"
}

function MPCHCInstaller {
    $architecture = (Get-WmiObject win32_processor | Where-Object {$_.deviceID -eq "CPU0"}).AddressWidth
    If ($architecture -eq "64") {
        $url = "https://binaries.mpc-hc.org/MPC%20HomeCinema%20-%20x64/MPC-HC_v1.7.13_x64/MPC-HC.1.7.13.x64.exe"
        Write-Host "MPCHC: "  -ForegroundColor Cyan -NoNewline
        write-host "Downloading the latest MPC-HC installer for x64"
    }
    else {
        $url = "https://binaries.mpc-hc.org/MPC%20HomeCinema%20-%20Win32/MPC-HC_v1.7.13_x86/MPC-HC.1.7.13.x86.exe"
        Write-Host "MPCHC: "  -ForegroundColor Cyan -NoNewline
        write-host "Downloading the latest MPC-HC installer for x86"
    }
    Write-Host "MPCHC: "  -ForegroundColor Cyan -NoNewline
    write-host "Downloading the latest MPC-HC installer for x$architecture"
    $output = ".\Data\Setup\MPCHC.exe"
    
    Import-Module BitsTransfer
    $start_time = Get-Date
    Start-BitsTransfer -Source $url -Destination $output
    Write-Host "PSShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s)"
    Write-Host "PSShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Looking for and removing TMP files..."
    get-childitem ".\" -recurse -force -include *.TMP| remove-item -force
    Write-Host "MPCHC: "  -ForegroundColor Cyan -NoNewline
    Write-Host "Installing, this can take a while depending on your PC..."
    Start-Process ".\Data\Setup\MPCHC-$architecture.exe" -ArgumentList "/SP- /VERYSILENT /NORESTART" -ErrorAction SilentlyContinue -Wait
    if ($KeepDataBox.Checked -eq $false) {
        get-childitem ".\Data\Setup" -recurse -force -include MPCHC-$architecture.*| remove-item -force -ErrorAction SilentlyContinue
    }
    Write-Host "MPCHC: "  -ForegroundColor Cyan -NoNewline
    write-host "Installation process completed!"
}

function AdobeAirInstaller {
    Write-Host "Adobe Air: "  -ForegroundColor Cyan -NoNewline
    Write-host "Downloading the Adobe Air installer..." 
    $url = "https://airdownload.adobe.com/air/win/download/32.0/AdobeAIRInstaller.exe"
    $output = ".\Data\Setup\AAIR.exe"
    
    Import-Module BitsTransfer
    $start_time = Get-Date
    Start-BitsTransfer -Source $url -Destination $output
    Write-Host "PSShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s)"
    Write-Host "PSShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Looking for and removing TMP files..."
    get-childitem ".\" -recurse -force -include *.TMP| remove-item -force
    Write-Host "Adobe Air: "  -ForegroundColor Cyan -NoNewline
    Write-Host "Installing, this can take a while depending on your PC..."
    Start-Process ".\Data\Setup\AAIR.exe" -ArgumentList "-silent" -ErrorAction SilentlyContinue -Wait
    if ($KeepDataBox.Checked -eq $false) {
        get-childitem ".\Data\Setup" -recurse -force -include AAIR.*| remove-item -force -ErrorAction SilentlyContinue
    }
    Write-Host "Adobe Air: "  -ForegroundColor Cyan -NoNewline
    write-host "Installation process completed!"
}

function HWMONITORInstaller {
    Write-Host "HWMONITOR: "  -ForegroundColor Cyan -NoNewline
    Write-host "Downloading the latest HWMONITOR installer..." 
    $url = "http://download.cpuid.com/hwmonitor/hwmonitor_1.40.exe"
    $output = ".\Data\Setup\HWMONITOR.exe"
    
    Import-Module BitsTransfer
    $start_time = Get-Date
    Start-BitsTransfer -Source $url -Destination $output
    Write-Host "PSShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s)"
    Write-Host "PSShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Looking for and removing TMP files..."
    get-childitem ".\" -recurse -force -include *.TMP| remove-item -force
    Write-Host "HWMONITOR: "  -ForegroundColor Cyan -NoNewline
    Write-Host "Installing, this can take a while depending on your PC..."
    Start-Process ".\Data\Setup\HWMONITOR.exe" -ArgumentList "/NORESTART /SILENT /SP-" -ErrorAction SilentlyContinue -Wait
    if ($KeepDataBox.Checked -eq $false) {
        get-childitem ".\Data\Setup" -recurse -force -include HWMONITOR.*| remove-item -force -ErrorAction SilentlyContinue
    }
    Write-Host "HWMONITOR: "  -ForegroundColor Cyan -NoNewline
    write-host "Installation process completed!"
}

function SpeedFanInstaller {
    Write-Host "SpeedFan: "  -ForegroundColor Cyan -NoNewline
    Write-host "Downloading the latest SpeedFan installer..." 
    $url = "http://files1.majorgeeks.com/c7e9c7545fe84025f5aa6dd945c474e3c988300c/diagnostics/instspeedfan452.exe"
    $output = ".\Data\Setup\SpeedFan.exe"
    
    Import-Module BitsTransfer
    $start_time = Get-Date
    Start-BitsTransfer -Source $url -Destination $output
    Write-Host "PSShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s)"
    Write-Host "PSShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Looking for and removing TMP files..."
    get-childitem ".\" -recurse -force -include *.TMP| remove-item -force
    Write-Host "SpeedFan: "  -ForegroundColor Cyan -NoNewline
    Write-Host "Installing, this can take a while depending on your PC..."
    Start-Process ".\Data\Setup\SpeedFan.exe" -ArgumentList "/S" -ErrorAction SilentlyContinue -Wait
    if ($KeepDataBox.Checked -eq $false) {
        get-childitem ".\Data\Setup" -recurse -force -include SpeedFan.*| remove-item -force -ErrorAction SilentlyContinue
    }
    Write-Host "SpeedFan: "  -ForegroundColor Cyan -NoNewline
    write-host "Installation process completed!"
}

function VuzeInstaller {
    $architecture = (Get-WmiObject win32_processor | Where-Object {$_.deviceID -eq "CPU0"}).AddressWidth
    If ($architecture -eq "64") {
        $url = " https://sourceforge.net/projects/azureus/files/vuze/Vuze_5760/Vuze_5760_Installer64.exe/download"
        Write-Host "Vuze: "  -ForegroundColor Cyan -NoNewline
        write-host "Downloading the latest Vuze installer for x64"
    }
    else {
        $url = "https://sourceforge.net/projects/azureus/files/vuze/Vuze_5760/Vuze_5760_Installer32.exe/download"
        Write-Host "MPCHC: "  -ForegroundColor Cyan -NoNewline
        write-host "Downloading the latest Vuze installer for x86"
    }
    Write-Host "Vuze: "  -ForegroundColor Cyan -NoNewline
    write-host "Downloading the latest Vuze installer..."
    $output = ".\Data\Setup\Vuze.exe"
    Import-Module BitsTransfer
    $start_time = Get-Date
    Start-BitsTransfer -Source $url -Destination $output
    Write-Host "PSShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s)"
    Write-Host "PSShell: "  -ForegroundColor Green -NoNewline
    Write-Host "Looking for and removing TMP files..."
    get-childitem ".\" -recurse -force -include *.TMP| remove-item -force
    Write-Host "Vuze: "  -ForegroundColor Cyan -NoNewline
    Write-Host "Installing, this can take a while depending on your PC..."
    Start-Process ".\Data\Setup\Vuze.exe" -ArgumentList " -q -splash 'Please wait...' -console" -ErrorAction SilentlyContinue 
    WaitForProgram("Azureus")
    if ($KeepDataBox.Checked -eq $false) {
        get-childitem ".\Data\Setup" -recurse -force -include Vuze.*| remove-item -force -ErrorAction SilentlyContinue
    }
    Write-Host "Vuze: "  -ForegroundColor Cyan -NoNewline
    write-host "Installation process completed!"
}
#Form data
function GenerateForm {
    
    #region Import the Assemblies
    [reflection.assembly]::loadwithpartialname("System.Windows.Forms") | Out-Null
    [reflection.assembly]::loadwithpartialname("System.Drawing") | Out-Null
    #endregion
    
    #region Generated Form Objects
    $form1 = New-Object System.Windows.Forms.Form
    $ExecutionBox = New-Object System.Windows.Forms.Button
    $KeepDataBox = New-Object System.Windows.Forms.CheckBox
    $tabControl1 = New-Object System.Windows.Forms.TabControl
    $InternetPage = New-Object System.Windows.Forms.TabPage
    $TVBox = New-Object System.Windows.Forms.CheckBox
    $TransmissionBTBox = New-Object System.Windows.Forms.CheckBox
    $VuzeBox = New-Object System.Windows.Forms.CheckBox
    $TBrowserBox = New-Object System.Windows.Forms.CheckBox
    $VivaldiBox = New-Object System.Windows.Forms.CheckBox
    $PuTTYBox = New-Object System.Windows.Forms.CheckBox
    $MicroTorrentBox = New-Object System.Windows.Forms.CheckBox
    $FileZillaBox = New-Object System.Windows.Forms.CheckBox
    $FireFoxBox = New-Object System.Windows.Forms.CheckBox
    $ChromeBox = New-Object System.Windows.Forms.CheckBox
    $TelegramBox = New-Object System.Windows.Forms.CheckBox
    $SystemPage = New-Object System.Windows.Forms.TabPage
    $7ZipBox = New-Object System.Windows.Forms.CheckBox
    $ShutUpBox = New-Object System.Windows.Forms.CheckBox
    $WinDirStatBox = New-Object System.Windows.Forms.CheckBox
    $EUSPMBox = New-Object System.Windows.Forms.CheckBox
    $MalwareBytesBox = New-Object System.Windows.Forms.CheckBox
    $AvastPaidBox = New-Object System.Windows.Forms.CheckBox
    $AvastFreeBox = New-Object System.Windows.Forms.CheckBox
    $PowerISOBox = New-Object System.Windows.Forms.CheckBox
    $IMGBurnBox = New-Object System.Windows.Forms.CheckBox
    $Aida64Box = New-Object System.Windows.Forms.CheckBox
    $ClassicShelltBox = New-Object System.Windows.Forms.CheckBox
    $HWMONITORBox = New-Object System.Windows.Forms.CheckBox
    $SpeedFanBox = New-Object System.Windows.Forms.CheckBox
    $HWinfo64Box = New-Object System.Windows.Forms.CheckBox
    $ProgrammingPage = New-Object System.Windows.Forms.TabPage
    $gVimBox = New-Object System.Windows.Forms.CheckBox
    $CPythonBox = New-Object System.Windows.Forms.CheckBox
    $pycharmBox = New-Object System.Windows.Forms.CheckBox
    $VSCodeBox = New-Object System.Windows.Forms.CheckBox
    $NotePadPlusPlusBox = New-Object System.Windows.Forms.CheckBox
    $MultimediaPage = New-Object System.Windows.Forms.TabPage
    $MusicBeeBox = New-Object System.Windows.Forms.CheckBox
    $SpotifyBox = New-Object System.Windows.Forms.CheckBox
    $iTunesBox = New-Object System.Windows.Forms.CheckBox
    $BlenderBox = New-Object System.Windows.Forms.CheckBox
    $MPCHCBox = New-Object System.Windows.Forms.CheckBox
    $MPVBox = New-Object System.Windows.Forms.CheckBox
    $Foobar2000Box = New-Object System.Windows.Forms.CheckBox
    $VLCBox = New-Object System.Windows.Forms.CheckBox
    $RuntimePage = New-Object System.Windows.Forms.TabPage
    $ShockwaveBox = New-Object System.Windows.Forms.CheckBox
    $AAIRBox = New-Object System.Windows.Forms.CheckBox
    $SilverLightBox = New-Object System.Windows.Forms.CheckBox
    $MSNET47Box = New-Object System.Windows.Forms.CheckBox
    $JSDKBox = New-Object System.Windows.Forms.CheckBox
    $JavaJREBox = New-Object System.Windows.Forms.CheckBox
    $OtherPage = New-Object System.Windows.Forms.TabPage
    $Win32DiskImagerBox = New-Object System.Windows.Forms.CheckBox
    $EtcherBox = New-Object System.Windows.Forms.CheckBox
    $GamesPage = New-Object System.Windows.Forms.TabPage
    $WarThunderBox = New-Object System.Windows.Forms.CheckBox
    $SteamyBox = New-Object System.Windows.Forms.CheckBox
    $OriginBox = New-Object System.Windows.Forms.CheckBox
    $InitialFormWindowState = New-Object System.Windows.Forms.FormWindowState
    #endregion Generated Form Objects
    
    #----------------------------------------------
    #Generated Event Script Blocks
    #----------------------------------------------
    #Provide Custom Code for events specified in PrimalForms.
    $handler_checkBox47_CheckedChanged= 
    {
    #TODO: Place custom script here
    
    }
    
    $ExecutionBox_OnClick={
        $ExecutionBox.Enabled = $False
        $ExecutionBox.Text = "Please wait..."
        Write-Host "QTSS Console Log: " -ForegroundColor Green
            $workdir = $RootPath + "\Data\Setup"
            If (Test-Path -Path $workdir -PathType Container)
            { Write-Host "$workdir already exists" -ForegroundColor Green}
            ELSE
            { New-Item -Path $workdir  -ItemType directory }
        CheckSettings
        Write-Host "" 
        Write-Host "System: "  -ForegroundColor Cyan -NoNewline
        Write-Host "Script complete; return to the GUI for control!"
        $ExecutionBox.Text = "Execute!"
        $ExecutionBox.Enabled = $True
        }
    
    $OnLoadForm_StateCorrection=
    {#Correct the initial state of the form to prevent the .Net maximized form issue
        $form1.WindowState = $InitialFormWindowState
    }
    
    #----------------------------------------------
    #region Generated Form Code
    $System_Drawing_Size = New-Object System.Drawing.Size
    $System_Drawing_Size.Height = 182
    $System_Drawing_Size.Width = 434
    $form1.ClientSize = $System_Drawing_Size
    $form1.DataBindings.DefaultDataSourceUpdateMode = 0
    $form1.Name = "form1"
    $form1.Text = "QTools System Setup Alpha"
    
    
    $ExecutionBox.DataBindings.DefaultDataSourceUpdateMode = 0
    
    $System_Drawing_Point = New-Object System.Drawing.Point
    $System_Drawing_Point.X = 320
    $System_Drawing_Point.Y = 152
    $ExecutionBox.Location = $System_Drawing_Point
    $ExecutionBox.Name = "ExecutionBox"
    $System_Drawing_Size = New-Object System.Drawing.Size
    $System_Drawing_Size.Height = 23
    $System_Drawing_Size.Width = 102
    $ExecutionBox.Size = $System_Drawing_Size
    $ExecutionBox.TabIndex = 2
    $ExecutionBox.Text = "Execute!"
    $ExecutionBox.UseVisualStyleBackColor = $True
    $ExecutionBox.add_Click($ExecutionBox_OnClick)
    
    $form1.Controls.Add($ExecutionBox)
    
    
    $KeepDataBox.DataBindings.DefaultDataSourceUpdateMode = 0
    
    $System_Drawing_Point = New-Object System.Drawing.Point
    $System_Drawing_Point.X = 5
    $System_Drawing_Point.Y = 151
    $KeepDataBox.Location = $System_Drawing_Point
    $KeepDataBox.Name = "KeepDataBox"
    $System_Drawing_Size = New-Object System.Drawing.Size
    $System_Drawing_Size.Height = 24
    $System_Drawing_Size.Width = 149
    $KeepDataBox.Size = $System_Drawing_Size
    $KeepDataBox.TabIndex = 1
    $KeepDataBox.Text = "Keep Downloaded Data"
    $KeepDataBox.UseVisualStyleBackColor = $True
    
    $form1.Controls.Add($KeepDataBox)
    
    $tabControl1.DataBindings.DefaultDataSourceUpdateMode = 0
    $System_Drawing_Point = New-Object System.Drawing.Point
    $System_Drawing_Point.X = 1
    $System_Drawing_Point.Y = 1
    $tabControl1.Location = $System_Drawing_Point
    $tabControl1.Name = "tabControl1"
    $tabControl1.SelectedIndex = 0
    $System_Drawing_Size = New-Object System.Drawing.Size
    $System_Drawing_Size.Height = 148
    $System_Drawing_Size.Width = 434
    $tabControl1.Size = $System_Drawing_Size
    $tabControl1.TabIndex = 0
    
    $form1.Controls.Add($tabControl1)
    $InternetPage.DataBindings.DefaultDataSourceUpdateMode = 0
    $System_Drawing_Point = New-Object System.Drawing.Point
    $System_Drawing_Point.X = 4
    $System_Drawing_Point.Y = 22
    $InternetPage.Location = $System_Drawing_Point
    $InternetPage.Name = "InternetPage"
    $System_Windows_Forms_Padding = New-Object System.Windows.Forms.Padding
    $System_Windows_Forms_Padding.All = 3
    $System_Windows_Forms_Padding.Bottom = 3
    $System_Windows_Forms_Padding.Left = 3
    $System_Windows_Forms_Padding.Right = 3
    $System_Windows_Forms_Padding.Top = 3
    $InternetPage.Padding = $System_Windows_Forms_Padding
    $System_Drawing_Size = New-Object System.Drawing.Size
    $System_Drawing_Size.Height = 122
    $System_Drawing_Size.Width = 426
    $InternetPage.Size = $System_Drawing_Size
    $InternetPage.TabIndex = 0
    $InternetPage.Text = "Internet"
    $InternetPage.UseVisualStyleBackColor = $True
    
    $tabControl1.Controls.Add($InternetPage)
    
    $TVBox.DataBindings.DefaultDataSourceUpdateMode = 0
    
    $System_Drawing_Point = New-Object System.Drawing.Point
    $System_Drawing_Point.X = 229
    $System_Drawing_Point.Y = 6
    $TVBox.Location = $System_Drawing_Point
    $TVBox.Name = "TVBox"
    $System_Drawing_Size = New-Object System.Drawing.Size
    $System_Drawing_Size.Height = 24
    $System_Drawing_Size.Width = 104
    $TVBox.Size = $System_Drawing_Size
    $TVBox.TabIndex = 10
    $TVBox.Text = "TeamViewer"
    $TVBox.UseVisualStyleBackColor = $True
    
    $InternetPage.Controls.Add($TVBox)
    
    
    $TransmissionBTBox.DataBindings.DefaultDataSourceUpdateMode = 0
    
    $System_Drawing_Point = New-Object System.Drawing.Point
    $System_Drawing_Point.X = 119
    $System_Drawing_Point.Y = 89
    $TransmissionBTBox.Location = $System_Drawing_Point
    $TransmissionBTBox.Name = "TransmissionBTBox"
    $System_Drawing_Size = New-Object System.Drawing.Size
    $System_Drawing_Size.Height = 24
    $System_Drawing_Size.Width = 110
    $TransmissionBTBox.Size = $System_Drawing_Size
    $TransmissionBTBox.TabIndex = 9
    $TransmissionBTBox.Text = "TransmissionBT"
    $TransmissionBTBox.UseVisualStyleBackColor = $True
    
    $InternetPage.Controls.Add($TransmissionBTBox)
    
    
    $VuzeBox.DataBindings.DefaultDataSourceUpdateMode = 0
    
    $System_Drawing_Point = New-Object System.Drawing.Point
    $System_Drawing_Point.X = 119
    $System_Drawing_Point.Y = 69
    $VuzeBox.Location = $System_Drawing_Point
    $VuzeBox.Name = "VuzeBox"
    $System_Drawing_Size = New-Object System.Drawing.Size
    $System_Drawing_Size.Height = 24
    $System_Drawing_Size.Width = 104
    $VuzeBox.Size = $System_Drawing_Size
    $VuzeBox.TabIndex = 8
    $VuzeBox.Text = "Vuze Client"
    $VuzeBox.UseVisualStyleBackColor = $True
    
    $InternetPage.Controls.Add($VuzeBox)
    
    
    $TBrowserBox.DataBindings.DefaultDataSourceUpdateMode = 0
    
    $System_Drawing_Point = New-Object System.Drawing.Point
    $System_Drawing_Point.X = 119
    $System_Drawing_Point.Y = 49
    $TBrowserBox.Location = $System_Drawing_Point
    $TBrowserBox.Name = "TBrowserBox"
    $System_Drawing_Size = New-Object System.Drawing.Size
    $System_Drawing_Size.Height = 24
    $System_Drawing_Size.Width = 104
    $TBrowserBox.Size = $System_Drawing_Size
    $TBrowserBox.TabIndex = 7
    $TBrowserBox.Text = "Tor Browser"
    $TBrowserBox.UseVisualStyleBackColor = $True
    
    $InternetPage.Controls.Add($TBrowserBox)
    
    
    $VivaldiBox.DataBindings.DefaultDataSourceUpdateMode = 0
    
    $System_Drawing_Point = New-Object System.Drawing.Point
    $System_Drawing_Point.X = 119
    $System_Drawing_Point.Y = 28
    $VivaldiBox.Location = $System_Drawing_Point
    $VivaldiBox.Name = "VivaldiBox"
    $System_Drawing_Size = New-Object System.Drawing.Size
    $System_Drawing_Size.Height = 24
    $System_Drawing_Size.Width = 104
    $VivaldiBox.Size = $System_Drawing_Size
    $VivaldiBox.TabIndex = 6
    $VivaldiBox.Text = "Vivaldi"
    $VivaldiBox.UseVisualStyleBackColor = $True
    
    $InternetPage.Controls.Add($VivaldiBox)
    
    
    $PuTTYBox.DataBindings.DefaultDataSourceUpdateMode = 0
    
    $System_Drawing_Point = New-Object System.Drawing.Point
    $System_Drawing_Point.X = 119
    $System_Drawing_Point.Y = 6
    $PuTTYBox.Location = $System_Drawing_Point
    $PuTTYBox.Name = "PuTTYBox"
    $System_Drawing_Size = New-Object System.Drawing.Size
    $System_Drawing_Size.Height = 24
    $System_Drawing_Size.Width = 104
    $PuTTYBox.Size = $System_Drawing_Size
    $PuTTYBox.TabIndex = 5
    $PuTTYBox.Text = "puTTY"
    $PuTTYBox.UseVisualStyleBackColor = $True
    
    $InternetPage.Controls.Add($PuTTYBox)
    
    
    $MicroTorrentBox.DataBindings.DefaultDataSourceUpdateMode = 0
    
    $System_Drawing_Point = New-Object System.Drawing.Point
    $System_Drawing_Point.X = 8
    $System_Drawing_Point.Y = 89
    $MicroTorrentBox.Location = $System_Drawing_Point
    $MicroTorrentBox.Name = "MicroTorrentBox"
    $System_Drawing_Size = New-Object System.Drawing.Size
    $System_Drawing_Size.Height = 24
    $System_Drawing_Size.Width = 104
    $MicroTorrentBox.Size = $System_Drawing_Size
    $MicroTorrentBox.TabIndex = 4
    $MicroTorrentBox.Text = "uTorrent"
    $MicroTorrentBox.UseVisualStyleBackColor = $True
    
    $InternetPage.Controls.Add($MicroTorrentBox)
    
    
    $FileZillaBox.DataBindings.DefaultDataSourceUpdateMode = 0
    
    $System_Drawing_Point = New-Object System.Drawing.Point
    $System_Drawing_Point.X = 8
    $System_Drawing_Point.Y = 69
    $FileZillaBox.Location = $System_Drawing_Point
    $FileZillaBox.Name = "FileZillaBox"
    $System_Drawing_Size = New-Object System.Drawing.Size
    $System_Drawing_Size.Height = 24
    $System_Drawing_Size.Width = 104
    $FileZillaBox.Size = $System_Drawing_Size
    $FileZillaBox.TabIndex = 3
    $FileZillaBox.Text = "FileZilla"
    $FileZillaBox.UseVisualStyleBackColor = $True
    
    $InternetPage.Controls.Add($FileZillaBox)
    
    
    $FireFoxBox.DataBindings.DefaultDataSourceUpdateMode = 0
    
    $System_Drawing_Point = New-Object System.Drawing.Point
    $System_Drawing_Point.X = 8
    $System_Drawing_Point.Y = 49
    $FireFoxBox.Location = $System_Drawing_Point
    $FireFoxBox.Name = "FireFoxBox"
    $System_Drawing_Size = New-Object System.Drawing.Size
    $System_Drawing_Size.Height = 24
    $System_Drawing_Size.Width = 104
    $FireFoxBox.Size = $System_Drawing_Size
    $FireFoxBox.TabIndex = 2
    $FireFoxBox.Text = "FireFox"
    $FireFoxBox.UseVisualStyleBackColor = $True
    
    $InternetPage.Controls.Add($FireFoxBox)
    
    
    $ChromeBox.DataBindings.DefaultDataSourceUpdateMode = 0
    
    $System_Drawing_Point = New-Object System.Drawing.Point
    $System_Drawing_Point.X = 8
    $System_Drawing_Point.Y = 28
    $ChromeBox.Location = $System_Drawing_Point
    $ChromeBox.Name = "ChromeBox"
    $System_Drawing_Size = New-Object System.Drawing.Size
    $System_Drawing_Size.Height = 24
    $System_Drawing_Size.Width = 104
    $ChromeBox.Size = $System_Drawing_Size
    $ChromeBox.TabIndex = 1
    $ChromeBox.Text = "Chrome"
    $ChromeBox.UseVisualStyleBackColor = $True
    
    $InternetPage.Controls.Add($ChromeBox)
    
    
    $TelegramBox.DataBindings.DefaultDataSourceUpdateMode = 0
    
    $System_Drawing_Point = New-Object System.Drawing.Point
    $System_Drawing_Point.X = 8
    $System_Drawing_Point.Y = 7
    $TelegramBox.Location = $System_Drawing_Point
    $TelegramBox.Name = "TelegramBox"
    $System_Drawing_Size = New-Object System.Drawing.Size
    $System_Drawing_Size.Height = 24
    $System_Drawing_Size.Width = 104
    $TelegramBox.Size = $System_Drawing_Size
    $TelegramBox.TabIndex = 0
    $TelegramBox.Text = "Telegram"
    $TelegramBox.UseVisualStyleBackColor = $True
    
    $InternetPage.Controls.Add($TelegramBox)
    
    
    $SystemPage.DataBindings.DefaultDataSourceUpdateMode = 0
    $System_Drawing_Point = New-Object System.Drawing.Point
    $System_Drawing_Point.X = 4
    $System_Drawing_Point.Y = 22
    $SystemPage.Location = $System_Drawing_Point
    $SystemPage.Name = "SystemPage"
    $System_Windows_Forms_Padding = New-Object System.Windows.Forms.Padding
    $System_Windows_Forms_Padding.All = 3
    $System_Windows_Forms_Padding.Bottom = 3
    $System_Windows_Forms_Padding.Left = 3
    $System_Windows_Forms_Padding.Right = 3
    $System_Windows_Forms_Padding.Top = 3
    $SystemPage.Padding = $System_Windows_Forms_Padding
    $System_Drawing_Size = New-Object System.Drawing.Size
    $System_Drawing_Size.Height = 122
    $System_Drawing_Size.Width = 426
    $SystemPage.Size = $System_Drawing_Size
    $SystemPage.TabIndex = 1
    $SystemPage.Text = "System"
    $SystemPage.UseVisualStyleBackColor = $True
    
    $tabControl1.Controls.Add($SystemPage)
    
    $7ZipBox.DataBindings.DefaultDataSourceUpdateMode = 0
    
    $System_Drawing_Point = New-Object System.Drawing.Point
    $System_Drawing_Point.X = 228
    $System_Drawing_Point.Y = 47
    $7ZipBox.Location = $System_Drawing_Point
    $7ZipBox.Name = "7ZipBox"
    $System_Drawing_Size = New-Object System.Drawing.Size
    $System_Drawing_Size.Height = 24
    $System_Drawing_Size.Width = 104
    $7ZipBox.Size = $System_Drawing_Size
    $7ZipBox.TabIndex = 13
    $7ZipBox.Text = "7-Zip"
    $7ZipBox.UseVisualStyleBackColor = $True
    
    $SystemPage.Controls.Add($7ZipBox)
    
    
    $ShutUpBox.DataBindings.DefaultDataSourceUpdateMode = 0
    
    $System_Drawing_Point = New-Object System.Drawing.Point
    $System_Drawing_Point.X = 228
    $System_Drawing_Point.Y = 90
    $ShutUpBox.Location = $System_Drawing_Point
    $ShutUpBox.Name = "ShutUpBox"
    $System_Drawing_Size = New-Object System.Drawing.Size
    $System_Drawing_Size.Height = 24
    $System_Drawing_Size.Width = 104
    $ShutUpBox.Size = $System_Drawing_Size
    $ShutUpBox.TabIndex = 12
    $ShutUpBox.Text = "ShutUp10"
    $ShutUpBox.UseVisualStyleBackColor = $True
    
    $SystemPage.Controls.Add($ShutUpBox)
    
    
    $WinDirStatBox.DataBindings.DefaultDataSourceUpdateMode = 0
    
    $System_Drawing_Point = New-Object System.Drawing.Point
    $System_Drawing_Point.X = 228
    $System_Drawing_Point.Y = 68
    $WinDirStatBox.Location = $System_Drawing_Point
    $WinDirStatBox.Name = "WinDirStatBox"
    $System_Drawing_Size = New-Object System.Drawing.Size
    $System_Drawing_Size.Height = 24
    $System_Drawing_Size.Width = 104
    $WinDirStatBox.Size = $System_Drawing_Size
    $WinDirStatBox.TabIndex = 11
    $WinDirStatBox.Text = "WinDirStat"
    $WinDirStatBox.UseVisualStyleBackColor = $True
    
    $SystemPage.Controls.Add($WinDirStatBox)
    
    
    $EUSPMBox.DataBindings.DefaultDataSourceUpdateMode = 0
    
    $System_Drawing_Point = New-Object System.Drawing.Point
    $System_Drawing_Point.X = 228
    $System_Drawing_Point.Y = 3
    $EUSPMBox.Location = $System_Drawing_Point
    $EUSPMBox.Name = "EUSPMBox"
    $System_Drawing_Size = New-Object System.Drawing.Size
    $System_Drawing_Size.Height = 44
    $System_Drawing_Size.Width = 111
    $EUSPMBox.Size = $System_Drawing_Size
    $EUSPMBox.TabIndex = 10
    $EUSPMBox.Text = "EaseUS Partition Master"
    $EUSPMBox.UseVisualStyleBackColor = $True
    
    $SystemPage.Controls.Add($EUSPMBox)
    
    
    $MalwareBytesBox.DataBindings.DefaultDataSourceUpdateMode = 0
    
    $System_Drawing_Point = New-Object System.Drawing.Point
    $System_Drawing_Point.X = 118
    $System_Drawing_Point.Y = 90
    $MalwareBytesBox.Location = $System_Drawing_Point
    $MalwareBytesBox.Name = "MalwareBytesBox"
    $System_Drawing_Size = New-Object System.Drawing.Size
    $System_Drawing_Size.Height = 24
    $System_Drawing_Size.Width = 104
    $MalwareBytesBox.Size = $System_Drawing_Size
    $MalwareBytesBox.TabIndex = 9
    $MalwareBytesBox.Text = "MalwareBytes"
    $MalwareBytesBox.UseVisualStyleBackColor = $True
    
    $SystemPage.Controls.Add($MalwareBytesBox)
    
    
    $AvastPaidBox.DataBindings.DefaultDataSourceUpdateMode = 0
    
    $System_Drawing_Point = New-Object System.Drawing.Point
    $System_Drawing_Point.X = 118
    $System_Drawing_Point.Y = 68
    $AvastPaidBox.Location = $System_Drawing_Point
    $AvastPaidBox.Name = "AvastPaidBox"
    $System_Drawing_Size = New-Object System.Drawing.Size
    $System_Drawing_Size.Height = 24
    $System_Drawing_Size.Width = 104
    $AvastPaidBox.Size = $System_Drawing_Size
    $AvastPaidBox.TabIndex = 8
    $AvastPaidBox.Text = "Avast Paid"
    $AvastPaidBox.UseVisualStyleBackColor = $True
    
    $SystemPage.Controls.Add($AvastPaidBox)
    
    
    $AvastFreeBox.DataBindings.DefaultDataSourceUpdateMode = 0
    
    $System_Drawing_Point = New-Object System.Drawing.Point
    $System_Drawing_Point.X = 118
    $System_Drawing_Point.Y = 47
    $AvastFreeBox.Location = $System_Drawing_Point
    $AvastFreeBox.Name = "AvastFreeBox"
    $System_Drawing_Size = New-Object System.Drawing.Size
    $System_Drawing_Size.Height = 24
    $System_Drawing_Size.Width = 104
    $AvastFreeBox.Size = $System_Drawing_Size
    $AvastFreeBox.TabIndex = 7
    $AvastFreeBox.Text = "Avast Free"
    $AvastFreeBox.UseVisualStyleBackColor = $True
    
    $SystemPage.Controls.Add($AvastFreeBox)
    
    
    $PowerISOBox.DataBindings.DefaultDataSourceUpdateMode = 0
    
    $System_Drawing_Point = New-Object System.Drawing.Point
    $System_Drawing_Point.X = 118
    $System_Drawing_Point.Y = 27
    $PowerISOBox.Location = $System_Drawing_Point
    $PowerISOBox.Name = "PowerISOBox"
    $System_Drawing_Size = New-Object System.Drawing.Size
    $System_Drawing_Size.Height = 24
    $System_Drawing_Size.Width = 104
    $PowerISOBox.Size = $System_Drawing_Size
    $PowerISOBox.TabIndex = 6
    $PowerISOBox.Text = "PowerISO"
    $PowerISOBox.UseVisualStyleBackColor = $True
    
    $SystemPage.Controls.Add($PowerISOBox)
    
    
    $IMGBurnBox.DataBindings.DefaultDataSourceUpdateMode = 0
    
    $System_Drawing_Point = New-Object System.Drawing.Point
    $System_Drawing_Point.X = 118
    $System_Drawing_Point.Y = 7
    $IMGBurnBox.Location = $System_Drawing_Point
    $IMGBurnBox.Name = "IMGBurnBox"
    $System_Drawing_Size = New-Object System.Drawing.Size
    $System_Drawing_Size.Height = 24
    $System_Drawing_Size.Width = 104
    $IMGBurnBox.Size = $System_Drawing_Size
    $IMGBurnBox.TabIndex = 5
    $IMGBurnBox.Text = "IMGBurn"
    $IMGBurnBox.UseVisualStyleBackColor = $True
    
    $SystemPage.Controls.Add($IMGBurnBox)
    
    
    $Aida64Box.DataBindings.DefaultDataSourceUpdateMode = 0
    
    $System_Drawing_Point = New-Object System.Drawing.Point
    $System_Drawing_Point.X = 8
    $System_Drawing_Point.Y = 68
    $Aida64Box.Location = $System_Drawing_Point
    $Aida64Box.Name = "Aida64Box"
    $System_Drawing_Size = New-Object System.Drawing.Size
    $System_Drawing_Size.Height = 24
    $System_Drawing_Size.Width = 104
    $Aida64Box.Size = $System_Drawing_Size
    $Aida64Box.TabIndex = 4
    $Aida64Box.Text = "Aida64"
    $Aida64Box.UseVisualStyleBackColor = $True
    
    $SystemPage.Controls.Add($Aida64Box)
    
    
    $ClassicShelltBox.DataBindings.DefaultDataSourceUpdateMode = 0
    
    $System_Drawing_Point = New-Object System.Drawing.Point
    $System_Drawing_Point.X = 8
    $System_Drawing_Point.Y = 90
    $ClassicShelltBox.Location = $System_Drawing_Point
    $ClassicShelltBox.Name = "ClassicShelltBox"
    $System_Drawing_Size = New-Object System.Drawing.Size
    $System_Drawing_Size.Height = 24
    $System_Drawing_Size.Width = 104
    $ClassicShelltBox.Size = $System_Drawing_Size
    $ClassicShelltBox.TabIndex = 3
    $ClassicShelltBox.Text = "ClassicShell"
    $ClassicShelltBox.UseVisualStyleBackColor = $True
    
    $SystemPage.Controls.Add($ClassicShelltBox)
    
    
    $HWMONITORBox.DataBindings.DefaultDataSourceUpdateMode = 0
    
    $System_Drawing_Point = New-Object System.Drawing.Point
    $System_Drawing_Point.X = 8
    $System_Drawing_Point.Y = 48
    $HWMONITORBox.Location = $System_Drawing_Point
    $HWMONITORBox.Name = "HWMONITORBox"
    $System_Drawing_Size = New-Object System.Drawing.Size
    $System_Drawing_Size.Height = 24
    $System_Drawing_Size.Width = 104
    $HWMONITORBox.Size = $System_Drawing_Size
    $HWMONITORBox.TabIndex = 2
    $HWMONITORBox.Text = "HWMONITOR"
    $HWMONITORBox.UseVisualStyleBackColor = $True
    
    $SystemPage.Controls.Add($HWMONITORBox)
    
    
    $SpeedFanBox.DataBindings.DefaultDataSourceUpdateMode = 0
    
    $System_Drawing_Point = New-Object System.Drawing.Point
    $System_Drawing_Point.X = 8
    $System_Drawing_Point.Y = 27
    $SpeedFanBox.Location = $System_Drawing_Point
    $SpeedFanBox.Name = "SpeedFanBox"
    $System_Drawing_Size = New-Object System.Drawing.Size
    $System_Drawing_Size.Height = 24
    $System_Drawing_Size.Width = 104
    $SpeedFanBox.Size = $System_Drawing_Size
    $SpeedFanBox.TabIndex = 1
    $SpeedFanBox.Text = "SpeedFan"
    $SpeedFanBox.UseVisualStyleBackColor = $True
    
    $SystemPage.Controls.Add($SpeedFanBox)
    
    
    $HWinfo64Box.DataBindings.DefaultDataSourceUpdateMode = 0
    
    $System_Drawing_Point = New-Object System.Drawing.Point
    $System_Drawing_Point.X = 8
    $System_Drawing_Point.Y = 7
    $HWinfo64Box.Location = $System_Drawing_Point
    $HWinfo64Box.Name = "HWinfo64Box"
    $System_Drawing_Size = New-Object System.Drawing.Size
    $System_Drawing_Size.Height = 24
    $System_Drawing_Size.Width = 104
    $HWinfo64Box.Size = $System_Drawing_Size
    $HWinfo64Box.TabIndex = 0
    $HWinfo64Box.Text = "HWinfo64"
    $HWinfo64Box.UseVisualStyleBackColor = $True
    
    $SystemPage.Controls.Add($HWinfo64Box)
    
    
    $ProgrammingPage.DataBindings.DefaultDataSourceUpdateMode = 0
    $System_Drawing_Point = New-Object System.Drawing.Point
    $System_Drawing_Point.X = 4
    $System_Drawing_Point.Y = 22
    $ProgrammingPage.Location = $System_Drawing_Point
    $ProgrammingPage.Name = "ProgrammingPage"
    $System_Windows_Forms_Padding = New-Object System.Windows.Forms.Padding
    $System_Windows_Forms_Padding.All = 3
    $System_Windows_Forms_Padding.Bottom = 3
    $System_Windows_Forms_Padding.Left = 3
    $System_Windows_Forms_Padding.Right = 3
    $System_Windows_Forms_Padding.Top = 3
    $ProgrammingPage.Padding = $System_Windows_Forms_Padding
    $System_Drawing_Size = New-Object System.Drawing.Size
    $System_Drawing_Size.Height = 122
    $System_Drawing_Size.Width = 426
    $ProgrammingPage.Size = $System_Drawing_Size
    $ProgrammingPage.TabIndex = 2
    $ProgrammingPage.Text = "Programming"
    $ProgrammingPage.UseVisualStyleBackColor = $True
    
    $tabControl1.Controls.Add($ProgrammingPage)
    
    $gVimBox.DataBindings.DefaultDataSourceUpdateMode = 0
    
    $System_Drawing_Point = New-Object System.Drawing.Point
    $System_Drawing_Point.X = 8
    $System_Drawing_Point.Y = 90
    $gVimBox.Location = $System_Drawing_Point
    $gVimBox.Name = "gVimBox"
    $System_Drawing_Size = New-Object System.Drawing.Size
    $System_Drawing_Size.Height = 24
    $System_Drawing_Size.Width = 104
    $gVimBox.Size = $System_Drawing_Size
    $gVimBox.TabIndex = 4
    $gVimBox.Text = "gVim"
    $gVimBox.UseVisualStyleBackColor = $True
    
    $ProgrammingPage.Controls.Add($gVimBox)
    
    
    $CPythonBox.DataBindings.DefaultDataSourceUpdateMode = 0
    
    $System_Drawing_Point = New-Object System.Drawing.Point
    $System_Drawing_Point.X = 8
    $System_Drawing_Point.Y = 68
    $CPythonBox.Location = $System_Drawing_Point
    $CPythonBox.Name = "CPythonBox"
    $System_Drawing_Size = New-Object System.Drawing.Size
    $System_Drawing_Size.Height = 24
    $System_Drawing_Size.Width = 104
    $CPythonBox.Size = $System_Drawing_Size
    $CPythonBox.TabIndex = 3
    $CPythonBox.Text = "CPython"
    $CPythonBox.UseVisualStyleBackColor = $True
    
    $ProgrammingPage.Controls.Add($CPythonBox)
    
    
    $pycharmBox.DataBindings.DefaultDataSourceUpdateMode = 0
    
    $System_Drawing_Point = New-Object System.Drawing.Point
    $System_Drawing_Point.X = 8
    $System_Drawing_Point.Y = 48
    $pycharmBox.Location = $System_Drawing_Point
    $pycharmBox.Name = "pycharmBox"
    $System_Drawing_Size = New-Object System.Drawing.Size
    $System_Drawing_Size.Height = 24
    $System_Drawing_Size.Width = 104
    $pycharmBox.Size = $System_Drawing_Size
    $pycharmBox.TabIndex = 2
    $pycharmBox.Text = "pycharm"
    $pycharmBox.UseVisualStyleBackColor = $True
    
    $ProgrammingPage.Controls.Add($pycharmBox)
    
    
    $VSCodeBox.DataBindings.DefaultDataSourceUpdateMode = 0
    
    $System_Drawing_Point = New-Object System.Drawing.Point
    $System_Drawing_Point.X = 8
    $System_Drawing_Point.Y = 28
    $VSCodeBox.Location = $System_Drawing_Point
    $VSCodeBox.Name = "VSCodeBox"
    $System_Drawing_Size = New-Object System.Drawing.Size
    $System_Drawing_Size.Height = 24
    $System_Drawing_Size.Width = 120
    $VSCodeBox.Size = $System_Drawing_Size
    $VSCodeBox.TabIndex = 1
    $VSCodeBox.Text = "Visual Studio Code"
    $VSCodeBox.UseVisualStyleBackColor = $True
    
    $ProgrammingPage.Controls.Add($VSCodeBox)
    
    
    $NotePadPlusPlusBox.DataBindings.DefaultDataSourceUpdateMode = 0
    
    $System_Drawing_Point = New-Object System.Drawing.Point
    $System_Drawing_Point.X = 8
    $System_Drawing_Point.Y = 7
    $NotePadPlusPlusBox.Location = $System_Drawing_Point
    $NotePadPlusPlusBox.Name = "NotePadPlusPlusBox"
    $System_Drawing_Size = New-Object System.Drawing.Size
    $System_Drawing_Size.Height = 24
    $System_Drawing_Size.Width = 104
    $NotePadPlusPlusBox.Size = $System_Drawing_Size
    $NotePadPlusPlusBox.TabIndex = 0
    $NotePadPlusPlusBox.Text = "Notepad++"
    $NotePadPlusPlusBox.UseVisualStyleBackColor = $True
    
    $ProgrammingPage.Controls.Add($NotePadPlusPlusBox)
    
    
    $MultimediaPage.DataBindings.DefaultDataSourceUpdateMode = 0
    $System_Drawing_Point = New-Object System.Drawing.Point
    $System_Drawing_Point.X = 4
    $System_Drawing_Point.Y = 22
    $MultimediaPage.Location = $System_Drawing_Point
    $MultimediaPage.Name = "MultimediaPage"
    $System_Windows_Forms_Padding = New-Object System.Windows.Forms.Padding
    $System_Windows_Forms_Padding.All = 3
    $System_Windows_Forms_Padding.Bottom = 3
    $System_Windows_Forms_Padding.Left = 3
    $System_Windows_Forms_Padding.Right = 3
    $System_Windows_Forms_Padding.Top = 3
    $MultimediaPage.Padding = $System_Windows_Forms_Padding
    $System_Drawing_Size = New-Object System.Drawing.Size
    $System_Drawing_Size.Height = 122
    $System_Drawing_Size.Width = 426
    $MultimediaPage.Size = $System_Drawing_Size
    $MultimediaPage.TabIndex = 3
    $MultimediaPage.Text = "Multimedia"
    $MultimediaPage.UseVisualStyleBackColor = $True
    
    $tabControl1.Controls.Add($MultimediaPage)
    
    $MusicBeeBox.DataBindings.DefaultDataSourceUpdateMode = 0
    
    $System_Drawing_Point = New-Object System.Drawing.Point
    $System_Drawing_Point.X = 143
    $System_Drawing_Point.Y = 26
    $MusicBeeBox.Location = $System_Drawing_Point
    $MusicBeeBox.Name = "MusicBeeBox"
    $System_Drawing_Size = New-Object System.Drawing.Size
    $System_Drawing_Size.Height = 24
    $System_Drawing_Size.Width = 104
    $MusicBeeBox.Size = $System_Drawing_Size
    $MusicBeeBox.TabIndex = 11
    $MusicBeeBox.Text = "MusicBee"
    $MusicBeeBox.UseVisualStyleBackColor = $True
    
    $MultimediaPage.Controls.Add($MusicBeeBox)
    
    
    $SpotifyBox.DataBindings.DefaultDataSourceUpdateMode = 0
    
    $System_Drawing_Point = New-Object System.Drawing.Point
    $System_Drawing_Point.X = 8
    $System_Drawing_Point.Y = 47
    $SpotifyBox.Location = $System_Drawing_Point
    $SpotifyBox.Name = "SpotifyBox"
    $System_Drawing_Size = New-Object System.Drawing.Size
    $System_Drawing_Size.Height = 24
    $System_Drawing_Size.Width = 104
    $SpotifyBox.Size = $System_Drawing_Size
    $SpotifyBox.TabIndex = 10
    $SpotifyBox.Text = "Spotify"
    $SpotifyBox.UseVisualStyleBackColor = $True
    
    $MultimediaPage.Controls.Add($SpotifyBox)
    
    
    $iTunesBox.DataBindings.DefaultDataSourceUpdateMode = 0
    
    $System_Drawing_Point = New-Object System.Drawing.Point
    $System_Drawing_Point.X = 8
    $System_Drawing_Point.Y = 6
    $iTunesBox.Location = $System_Drawing_Point
    $iTunesBox.Name = "iTunesBox"
    $System_Drawing_Size = New-Object System.Drawing.Size
    $System_Drawing_Size.Height = 24
    $System_Drawing_Size.Width = 104
    $iTunesBox.Size = $System_Drawing_Size
    $iTunesBox.TabIndex = 8
    $iTunesBox.Text = "iTunes"
    $iTunesBox.UseVisualStyleBackColor = $True
    
    $MultimediaPage.Controls.Add($iTunesBox)
    
    
    $BlenderBox.DataBindings.DefaultDataSourceUpdateMode = 0
    
    $System_Drawing_Point = New-Object System.Drawing.Point
    $System_Drawing_Point.X = 143
    $System_Drawing_Point.Y = 47
    $BlenderBox.Location = $System_Drawing_Point
    $BlenderBox.Name = "BlenderBox"
    $System_Drawing_Size = New-Object System.Drawing.Size
    $System_Drawing_Size.Height = 24
    $System_Drawing_Size.Width = 104
    $BlenderBox.Size = $System_Drawing_Size
    $BlenderBox.TabIndex = 7
    $BlenderBox.Text = "Blender"
    $BlenderBox.UseVisualStyleBackColor = $True
    
    $MultimediaPage.Controls.Add($BlenderBox)
    
    
    $MPCHCBox.DataBindings.DefaultDataSourceUpdateMode = 0
    
    $System_Drawing_Point = New-Object System.Drawing.Point
    $System_Drawing_Point.X = 143
    $System_Drawing_Point.Y = 6
    $MPCHCBox.Location = $System_Drawing_Point
    $MPCHCBox.Name = "MPCHCBox"
    $System_Drawing_Size = New-Object System.Drawing.Size
    $System_Drawing_Size.Height = 24
    $System_Drawing_Size.Width = 104
    $MPCHCBox.Size = $System_Drawing_Size
    $MPCHCBox.TabIndex = 5
    $MPCHCBox.Text = "MPCHC"
    $MPCHCBox.UseVisualStyleBackColor = $True
    
    $MultimediaPage.Controls.Add($MPCHCBox)
    
    
    $MPVBox.DataBindings.DefaultDataSourceUpdateMode = 0
    
    $System_Drawing_Point = New-Object System.Drawing.Point
    $System_Drawing_Point.X = 8
    $System_Drawing_Point.Y = 88
    $MPVBox.Location = $System_Drawing_Point
    $MPVBox.Name = "MPVBox"
    $System_Drawing_Size = New-Object System.Drawing.Size
    $System_Drawing_Size.Height = 24
    $System_Drawing_Size.Width = 104
    $MPVBox.Size = $System_Drawing_Size
    $MPVBox.TabIndex = 4
    $MPVBox.Text = "MPV"
    $MPVBox.UseVisualStyleBackColor = $True
    
    $MultimediaPage.Controls.Add($MPVBox)
    
    
    $Foobar2000Box.DataBindings.DefaultDataSourceUpdateMode = 0
    
    $System_Drawing_Point = New-Object System.Drawing.Point
    $System_Drawing_Point.X = 8
    $System_Drawing_Point.Y = 66
    $Foobar2000Box.Location = $System_Drawing_Point
    $Foobar2000Box.Name = "Foobar2000Box"
    $System_Drawing_Size = New-Object System.Drawing.Size
    $System_Drawing_Size.Height = 24
    $System_Drawing_Size.Width = 104
    $Foobar2000Box.Size = $System_Drawing_Size
    $Foobar2000Box.TabIndex = 3
    $Foobar2000Box.Text = "Foobar2000"
    $Foobar2000Box.UseVisualStyleBackColor = $True
    
    $MultimediaPage.Controls.Add($Foobar2000Box)
    
    
    $VLCBox.DataBindings.DefaultDataSourceUpdateMode = 0
    
    $System_Drawing_Point = New-Object System.Drawing.Point
    $System_Drawing_Point.X = 8
    $System_Drawing_Point.Y = 26
    $VLCBox.Location = $System_Drawing_Point
    $VLCBox.Name = "VLCBox"
    $System_Drawing_Size = New-Object System.Drawing.Size
    $System_Drawing_Size.Height = 24
    $System_Drawing_Size.Width = 104
    $VLCBox.Size = $System_Drawing_Size
    $VLCBox.TabIndex = 1
    $VLCBox.Text = "VLC"
    $VLCBox.UseVisualStyleBackColor = $True
    
    $MultimediaPage.Controls.Add($VLCBox)
    
    
    $RuntimePage.DataBindings.DefaultDataSourceUpdateMode = 0
    $System_Drawing_Point = New-Object System.Drawing.Point
    $System_Drawing_Point.X = 4
    $System_Drawing_Point.Y = 22
    $RuntimePage.Location = $System_Drawing_Point
    $RuntimePage.Name = "RuntimePage"
    $System_Windows_Forms_Padding = New-Object System.Windows.Forms.Padding
    $System_Windows_Forms_Padding.All = 3
    $System_Windows_Forms_Padding.Bottom = 3
    $System_Windows_Forms_Padding.Left = 3
    $System_Windows_Forms_Padding.Right = 3
    $System_Windows_Forms_Padding.Top = 3
    $RuntimePage.Padding = $System_Windows_Forms_Padding
    $System_Drawing_Size = New-Object System.Drawing.Size
    $System_Drawing_Size.Height = 122
    $System_Drawing_Size.Width = 426
    $RuntimePage.Size = $System_Drawing_Size
    $RuntimePage.TabIndex = 4
    $RuntimePage.Text = "Runtime"
    $RuntimePage.UseVisualStyleBackColor = $True
    
    $tabControl1.Controls.Add($RuntimePage)
    
    $ShockwaveBox.DataBindings.DefaultDataSourceUpdateMode = 0
    
    $System_Drawing_Point = New-Object System.Drawing.Point
    $System_Drawing_Point.X = 118
    $System_Drawing_Point.Y = 26
    $ShockwaveBox.Location = $System_Drawing_Point
    $ShockwaveBox.Name = "ShockwaveBox"
    $System_Drawing_Size = New-Object System.Drawing.Size
    $System_Drawing_Size.Height = 24
    $System_Drawing_Size.Width = 104
    $ShockwaveBox.Size = $System_Drawing_Size
    $ShockwaveBox.TabIndex = 5
    $ShockwaveBox.Text = "Shockwave"
    $ShockwaveBox.UseVisualStyleBackColor = $True
    
    $RuntimePage.Controls.Add($ShockwaveBox)
    
    
    $AAIRBox.DataBindings.DefaultDataSourceUpdateMode = 0
    
    $System_Drawing_Point = New-Object System.Drawing.Point
    $System_Drawing_Point.X = 118
    $System_Drawing_Point.Y = 6
    $AAIRBox.Location = $System_Drawing_Point
    $AAIRBox.Name = "AAIRBox"
    $System_Drawing_Size = New-Object System.Drawing.Size
    $System_Drawing_Size.Height = 24
    $System_Drawing_Size.Width = 104
    $AAIRBox.Size = $System_Drawing_Size
    $AAIRBox.TabIndex = 4
    $AAIRBox.Text = "Adobe AIR"
    $AAIRBox.UseVisualStyleBackColor = $True
    $AAIRBox.add_CheckedChanged($handler_checkBox47_CheckedChanged)
    
    $RuntimePage.Controls.Add($AAIRBox)
    
    
    $SilverLightBox.DataBindings.DefaultDataSourceUpdateMode = 0
    
    $System_Drawing_Point = New-Object System.Drawing.Point
    $System_Drawing_Point.X = 8
    $System_Drawing_Point.Y = 70
    $SilverLightBox.Location = $System_Drawing_Point
    $SilverLightBox.Name = "SilverLightBox"
    $System_Drawing_Size = New-Object System.Drawing.Size
    $System_Drawing_Size.Height = 31
    $System_Drawing_Size.Width = 104
    $SilverLightBox.Size = $System_Drawing_Size
    $SilverLightBox.TabIndex = 3
    $SilverLightBox.Text = "Microsoft SilverLight"
    $SilverLightBox.UseVisualStyleBackColor = $True
    
    $RuntimePage.Controls.Add($SilverLightBox)
    
    
    $MSNET47Box.DataBindings.DefaultDataSourceUpdateMode = 0
    
    $System_Drawing_Point = New-Object System.Drawing.Point
    $System_Drawing_Point.X = 8
    $System_Drawing_Point.Y = 47
    $MSNET47Box.Location = $System_Drawing_Point
    $MSNET47Box.Name = "MSNET47Box"
    $System_Drawing_Size = New-Object System.Drawing.Size
    $System_Drawing_Size.Height = 24
    $System_Drawing_Size.Width = 104
    $MSNET47Box.Size = $System_Drawing_Size
    $MSNET47Box.TabIndex = 2
    $MSNET47Box.Text = "MS .NET 4.7"
    $MSNET47Box.UseVisualStyleBackColor = $True
    
    $RuntimePage.Controls.Add($MSNET47Box)
    
    
    $JSDKBox.DataBindings.DefaultDataSourceUpdateMode = 0
    
    $System_Drawing_Point = New-Object System.Drawing.Point
    $System_Drawing_Point.X = 8
    $System_Drawing_Point.Y = 26
    $JSDKBox.Location = $System_Drawing_Point
    $JSDKBox.Name = "JSDKBox"
    $System_Drawing_Size = New-Object System.Drawing.Size
    $System_Drawing_Size.Height = 24
    $System_Drawing_Size.Width = 104
    $JSDKBox.Size = $System_Drawing_Size
    $JSDKBox.TabIndex = 1
    $JSDKBox.Text = "Java SDK"
    $JSDKBox.UseVisualStyleBackColor = $True
    
    $RuntimePage.Controls.Add($JSDKBox)
    
    
    $JavaJREBox.DataBindings.DefaultDataSourceUpdateMode = 0
    
    $System_Drawing_Point = New-Object System.Drawing.Point
    $System_Drawing_Point.X = 8
    $System_Drawing_Point.Y = 6
    $JavaJREBox.Location = $System_Drawing_Point
    $JavaJREBox.Name = "JavaJREBox"
    $System_Drawing_Size = New-Object System.Drawing.Size
    $System_Drawing_Size.Height = 24
    $System_Drawing_Size.Width = 104
    $JavaJREBox.Size = $System_Drawing_Size
    $JavaJREBox.TabIndex = 0
    $JavaJREBox.Text = "Java Runtime"
    $JavaJREBox.UseVisualStyleBackColor = $True
    
    $RuntimePage.Controls.Add($JavaJREBox)
    
    
    $OtherPage.DataBindings.DefaultDataSourceUpdateMode = 0
    $System_Drawing_Point = New-Object System.Drawing.Point
    $System_Drawing_Point.X = 4
    $System_Drawing_Point.Y = 22
    $OtherPage.Location = $System_Drawing_Point
    $OtherPage.Name = "OtherPage"
    $System_Windows_Forms_Padding = New-Object System.Windows.Forms.Padding
    $System_Windows_Forms_Padding.All = 3
    $System_Windows_Forms_Padding.Bottom = 3
    $System_Windows_Forms_Padding.Left = 3
    $System_Windows_Forms_Padding.Right = 3
    $System_Windows_Forms_Padding.Top = 3
    $OtherPage.Padding = $System_Windows_Forms_Padding
    $System_Drawing_Size = New-Object System.Drawing.Size
    $System_Drawing_Size.Height = 122
    $System_Drawing_Size.Width = 426
    $OtherPage.Size = $System_Drawing_Size
    $OtherPage.TabIndex = 5
    $OtherPage.Text = "Other"
    $OtherPage.UseVisualStyleBackColor = $True
    
    $tabControl1.Controls.Add($OtherPage)
    
    $Win32DiskImagerBox.DataBindings.DefaultDataSourceUpdateMode = 0
    
    $System_Drawing_Point = New-Object System.Drawing.Point
    $System_Drawing_Point.X = 7
    $System_Drawing_Point.Y = 26
    $Win32DiskImagerBox.Location = $System_Drawing_Point
    $Win32DiskImagerBox.Name = "Win32DiskImagerBox"
    $System_Drawing_Size = New-Object System.Drawing.Size
    $System_Drawing_Size.Height = 24
    $System_Drawing_Size.Width = 120
    $Win32DiskImagerBox.Size = $System_Drawing_Size
    $Win32DiskImagerBox.TabIndex = 1
    $Win32DiskImagerBox.Text = "Win32DiskImager"
    $Win32DiskImagerBox.UseVisualStyleBackColor = $True
    
    $OtherPage.Controls.Add($Win32DiskImagerBox)
    
    
    $EtcherBox.DataBindings.DefaultDataSourceUpdateMode = 0
    
    $System_Drawing_Point = New-Object System.Drawing.Point
    $System_Drawing_Point.X = 7
    $System_Drawing_Point.Y = 6
    $EtcherBox.Location = $System_Drawing_Point
    $EtcherBox.Name = "EtcherBox"
    $System_Drawing_Size = New-Object System.Drawing.Size
    $System_Drawing_Size.Height = 24
    $System_Drawing_Size.Width = 104
    $EtcherBox.Size = $System_Drawing_Size
    $EtcherBox.TabIndex = 0
    $EtcherBox.Text = "Etcher"
    $EtcherBox.UseVisualStyleBackColor = $True
    
    $OtherPage.Controls.Add($EtcherBox)
    
    
    $GamesPage.DataBindings.DefaultDataSourceUpdateMode = 0
    $System_Drawing_Point = New-Object System.Drawing.Point
    $System_Drawing_Point.X = 4
    $System_Drawing_Point.Y = 22
    $GamesPage.Location = $System_Drawing_Point
    $GamesPage.Name = "GamesPage"
    $System_Windows_Forms_Padding = New-Object System.Windows.Forms.Padding
    $System_Windows_Forms_Padding.All = 3
    $System_Windows_Forms_Padding.Bottom = 3
    $System_Windows_Forms_Padding.Left = 3
    $System_Windows_Forms_Padding.Right = 3
    $System_Windows_Forms_Padding.Top = 3
    $GamesPage.Padding = $System_Windows_Forms_Padding
    $System_Drawing_Size = New-Object System.Drawing.Size
    $System_Drawing_Size.Height = 122
    $System_Drawing_Size.Width = 426
    $GamesPage.Size = $System_Drawing_Size
    $GamesPage.TabIndex = 6
    $GamesPage.Text = "Games"
    $GamesPage.UseVisualStyleBackColor = $True
    
    $tabControl1.Controls.Add($GamesPage)
    
    $WarThunderBox.DataBindings.DefaultDataSourceUpdateMode = 0
    
    $System_Drawing_Point = New-Object System.Drawing.Point
    $System_Drawing_Point.X = 8
    $System_Drawing_Point.Y = 54
    $WarThunderBox.Location = $System_Drawing_Point
    $WarThunderBox.Name = "WarThunderBox"
    $System_Drawing_Size = New-Object System.Drawing.Size
    $System_Drawing_Size.Height = 24
    $System_Drawing_Size.Width = 104
    $WarThunderBox.Size = $System_Drawing_Size
    $WarThunderBox.TabIndex = 2
    $WarThunderBox.Text = "WarThunder"
    $WarThunderBox.UseVisualStyleBackColor = $True
    
    $GamesPage.Controls.Add($WarThunderBox)
    
    
    $SteamyBox.DataBindings.DefaultDataSourceUpdateMode = 0
    
    $System_Drawing_Point = New-Object System.Drawing.Point
    $System_Drawing_Point.X = 8
    $System_Drawing_Point.Y = 30
    $SteamyBox.Location = $System_Drawing_Point
    $SteamyBox.Name = "SteamyBox"
    $System_Drawing_Size = New-Object System.Drawing.Size
    $System_Drawing_Size.Height = 24
    $System_Drawing_Size.Width = 104
    $SteamyBox.Size = $System_Drawing_Size
    $SteamyBox.TabIndex = 1
    $SteamyBox.Text = "Steam"
    $SteamyBox.UseVisualStyleBackColor = $True
    
    $GamesPage.Controls.Add($SteamyBox)
    
    
    $OriginBox.DataBindings.DefaultDataSourceUpdateMode = 0
    
    $System_Drawing_Point = New-Object System.Drawing.Point
    $System_Drawing_Point.X = 8
    $System_Drawing_Point.Y = 7
    $OriginBox.Location = $System_Drawing_Point
    $OriginBox.Name = "OriginBox"
    $System_Drawing_Size = New-Object System.Drawing.Size
    $System_Drawing_Size.Height = 24
    $System_Drawing_Size.Width = 104
    $OriginBox.Size = $System_Drawing_Size
    $OriginBox.TabIndex = 0
    $OriginBox.Text = "Origin"
    $OriginBox.UseVisualStyleBackColor = $True
    
    $GamesPage.Controls.Add($OriginBox)
    
    
    
    #endregion Generated Form Code
    
    #Save the initial state of the form
    $InitialFormWindowState = $form1.WindowState
    #Init the OnLoad event to correct the initial state of the form
    $form1.add_Load($OnLoadForm_StateCorrection)
    #Show the Form
    $form1.ShowDialog()| Out-Null
    
    } #End Function
    
    #Call the Function
    GenerateForm
    