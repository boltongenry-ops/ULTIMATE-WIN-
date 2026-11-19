param([Parameter(Mandatory)][string]$Archive)
$ErrorActionPreference='Stop'
$folder=Join-Path $env:RUNNER_TEMP ('ultimatewin-'+[guid]::NewGuid())
Expand-Archive -LiteralPath $Archive -DestinationPath $folder
$exe=Join-Path $folder 'UltimateWin.exe'
if ((Get-FileHash $exe).Hash -ne (Get-FileHash 'dist/UltimateWin.exe').Hash) {throw 'Packaged executable differs from release binary'}
. ([scriptblock]::Create([IO.File]::ReadAllText((Resolve-Path 'app/workers.ps1'))))
$name='UltimateWinSmoke-'+[guid]::NewGuid().ToString('N')
$runKey='HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$backupKey='HKCU:\Software\UltimateWin\DisabledRun'
if (!(Test-Path $runKey)) {New-Item -Path $runKey | Out-Null}
try {
    New-ItemProperty -Path $runKey -Name $name -PropertyType ExpandString -Value '%SystemRoot%\System32\notepad.exe' | Out-Null
    $row=Startup | Where-Object Название -eq $name
    SwitchStartup $row
    if ((Get-Item $runKey).GetValueNames() -contains $name) {throw 'Startup command still active'}
    $disabled=DisabledStartup | Where-Object Название -eq $name
    SwitchStartup $disabled
    $restored=Get-Item $runKey
    if ($restored.GetValueKind($name) -ne 'ExpandString' -or $restored.GetValue($name,$null,'DoNotExpandEnvironmentNames') -cne $row.Команда) {throw 'Startup round trip failed'}
} finally {
    foreach ($key in $runKey,$backupKey) {
        Remove-ItemProperty -LiteralPath $key -Name $name -ErrorAction SilentlyContinue
    }
}
# DiskPart selects only a newly created scratch VHD; no existing disk is selected.
$letter=@(82..90 | ForEach-Object {[char]$_} | Where-Object {![IO.Directory]::Exists("${_}:\")})[0]
if (!$letter) {throw 'No letter available for the scratch volume'}
$vhd=Join-Path $folder 'test-volume.vhd'
$diskScript=Join-Path $folder 'attach.txt'
@("create vdisk file=`"$vhd`" maximum=80 type=expandable","select vdisk file=`"$vhd`"",'attach vdisk','create partition primary','format fs=ntfs quick label=UltimateWinTest',"assign letter=$letter") | Set-Content $diskScript -Encoding ascii
try {
    & "$env:SystemRoot\System32\diskpart.exe" /s $diskScript | Out-Host
    if ($LASTEXITCODE -ne 0) {throw 'Could not prepare scratch volume'}
    $part=DiskPartitions | Where-Object { $_.Том -eq "${letter}:" -and $_.Метка -eq 'UltimateWinTest' }
    if (!$part) {throw 'Expected labelled partition not listed'}
    # Exercise the application command, answering only its final interactive pause.
    $outcome=& {
        function Start-Process($FilePath,$Verb,$ArgumentList,[switch]$PassThru,[switch]$Wait) {
            if ($Verb -ne 'RunAs' -or !$Wait -or $ArgumentList -notmatch '^-NoProfile -EncodedCommand ([a-z0-9+/=]+)$') {throw 'Unexpected CHKDSK launch'}
            $command=[Text.Encoding]::Unicode.GetString([Convert]::FromBase64String($Matches[1]))
            $command="function Read-Host { return '' }`n"+$command
            $encoded=[Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))
            & $FilePath -NoProfile -EncodedCommand $encoded | Out-Host
            [pscustomobject]@{ExitCode=$LASTEXITCODE}
        }
        CheckDisk $part.Том
    }
    if ($outcome -notlike '*Ошибок не обнаружено*') {throw "Unexpected CHKDSK result: $outcome"}
} finally {
    if (Test-Path $vhd) {
        @("select vdisk file=`"$vhd`"",'detach vdisk') | Set-Content $diskScript -Encoding ascii
        & "$env:SystemRoot\System32\diskpart.exe" /s $diskScript | Out-Host
    }
}
Add-Type -AssemblyName UIAutomationClient,UIAutomationTypes
function FindElement($root,$property,$value,$scope) {
    $condition=[Windows.Automation.PropertyCondition]::new($property,$value)
    $root.FindFirst($scope,$condition)
}
function WaitFor($probe,$what) {
    $time=[Diagnostics.Stopwatch]::StartNew()
    do {
        if ($process.HasExited) {throw "App exited before $what"}
        $result=& $probe
        if ($result) {return $result}
        Start-Sleep -Milliseconds 250
    } while ($time.Elapsed.TotalSeconds -lt 60)
    throw "Timed out waiting for $what"
}
$process=Start-Process $exe -PassThru
$child=$null
try {
    $child=WaitFor {Get-CimInstance Win32_Process -Filter "ParentProcessId=$($process.Id) AND Name='powershell.exe'"} 'GUI process'
    $window=WaitFor {
        FindElement ([Windows.Automation.AutomationElement]::RootElement) ([Windows.Automation.AutomationElement]::ProcessIdProperty) ([int]$child.ProcessId) 'Children'
    } 'window'
    if ($window.Current.Name -ne 'Ultimate Win') {throw "Unexpected window: $($window.Current.Name)"}
    $autoId=[Windows.Automation.AutomationElement]::AutomationIdProperty
    $status=WaitFor {FindElement $window $autoId 'Status' 'Descendants'} 'status'
    [void](WaitFor {$status.Current.Name -like 'Обновлено в *'} 'dashboard readings')
    foreach ($page in 'Процессы','Автозагрузка','Устройства','Драйверы','Программы','Диски','Память','Сеть','Файлы','Диагностика','ИИ-помощник') {
        $button=FindElement $window $autoId "Nav-$page" 'Descendants'
        $button.GetCurrentPattern([Windows.Automation.InvokePattern]::Pattern).Invoke()
        [void](WaitFor {(FindElement $window $autoId 'Heading' 'Descendants').Current.Name -eq $page -and $button.Current.IsEnabled} $page)
        if ($status.Current.Name -like 'Ошибка*') {throw $status.Current.Name}
        if ($page -in 'Процессы','Автозагрузка','Устройства','Драйверы','Программы','Диски','Память','Сеть' -and $status.Current.Name -notlike 'Строк:*') {throw "List did not load: $page"}
        if ($page -in 'Драйверы','Программы','Диски','Память' -and $status.Current.Name -notmatch '^Строк: [1-9]') {throw "Empty inventory: $page · $($status.Current.Name)"}
        if ($page -eq 'Программы') {
            $search=FindElement $window $autoId 'InventorySearch' 'Descendants'
            $pattern=$search.GetCurrentPattern([Windows.Automation.ValuePattern]::Pattern)
            $pattern.SetValue([guid]::NewGuid().ToString())
            [void](WaitFor {$status.Current.Name -eq 'Строк: 0'} 'filtered inventory')
            $pattern.SetValue('')
            [void](WaitFor {$status.Current.Name -match '^Строк: [1-9]'} 'restored inventory')
        }
        if ($page -eq 'Диагностика') {
            $start=FindElement $window ([Windows.Automation.AutomationElement]::NameProperty) 'Почему тормозит ПК?' 'Descendants'
            $start.GetCurrentPattern([Windows.Automation.InvokePattern]::Pattern).Invoke()
            $cancel=WaitFor {
                $control=FindElement $window $autoId 'CancelRead' 'Descendants'
                if ($control -and !$control.Current.IsOffscreen) {$control}
            } 'cancel button'
            $cancel.GetCurrentPattern([Windows.Automation.InvokePattern]::Pattern).Invoke()
            [void](WaitFor {$status.Current.Name -eq 'Проверка отменена' -and $start.Current.IsEnabled} 'sampling cancellation')
            $start.GetCurrentPattern([Windows.Automation.InvokePattern]::Pattern).Invoke()
            [void](WaitFor {$status.Current.Name -like 'Измерение завершено*'} 'completed load report')
        }
    }
    $window.GetCurrentPattern([Windows.Automation.WindowPattern]::Pattern).Close()
    if (!$process.WaitForExit(10000) -or $process.ExitCode -ne 0) {throw 'Application failed to close normally'}
} finally {
    if (!$process.HasExited) {
        if ($child) {Stop-Process -Id $child.ProcessId -ErrorAction SilentlyContinue}
        $process.Kill()
    }
    $process.Dispose()
}
