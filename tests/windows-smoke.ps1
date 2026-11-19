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
    foreach ($page in 'Процессы','Автозагрузка','Устройства','Сеть','Файлы','Диагностика','ИИ-помощник') {
        $button=FindElement $window $autoId "Nav-$page" 'Descendants'
        $button.GetCurrentPattern([Windows.Automation.InvokePattern]::Pattern).Invoke()
        [void](WaitFor {(FindElement $window $autoId 'Heading' 'Descendants').Current.Name -eq $page -and $button.Current.IsEnabled} $page)
        if ($status.Current.Name -like 'Ошибка*') {throw $status.Current.Name}
        if ($page -in 'Процессы','Автозагрузка','Устройства','Сеть' -and $status.Current.Name -notlike 'Строк:*') {throw "List did not load: $page"}
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
