$ErrorActionPreference='Stop'

function Metrics {
    $os = Get-CimInstance Win32_OperatingSystem
    $cpu = @(Get-CimInstance Win32_PerfFormattedData_PerfOS_Processor | Where-Object Name -eq '_Total')[0]
    $gpu = @(Get-CimInstance Win32_PerfFormattedData_GPUPerformanceCounters_GPUAdapterMemory -ErrorAction SilentlyContinue)
    $ram = ($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / 1MB
    $vram = 'Нет данных драйвера'
    if ($gpu.Count) { $vram = '{0:N2} ГиБ' -f (($gpu | Measure-Object DedicatedUsage -Sum).Sum / 1GB) }
    [pscustomobject]@{
        CPU = ('{0} %' -f $cpu.PercentProcessorTime)
        RAM = ('{0:N1} / {1:N1} ГиБ' -f $ram, ($os.TotalVisibleMemorySize / 1MB))
        VRAM = $vram
        OS = "$($os.Caption) · $($os.Version)"
        Uptime = ((Get-Date) - $os.LastBootUpTime).ToString('d\д\ hh\ч\ mm\м')
    }
}
function Processes {
    $currentSession = (Get-Process -Id $PID).SessionId
    foreach ($p in Get-Process) {
        try {
            $background = !$p.MainWindowHandle.ToInt64()
            $description = $p.Description
            if (!$description) {
                $description = if ($p.SessionId -eq 0) {'Служебный процесс Windows или установленной службы'} elseif ($background) {'Программа работает без видимого главного окна'} else {'Приложение с окном рабочего стола'}
            }
            $start = try { $p.StartTime.ToUniversalTime().Ticks } catch { 0 }
            [pscustomobject]@{Имя=$p.ProcessName; PID=$p.Id; 'Память, МиБ'=[math]::Round($p.WorkingSet64/1MB); Вид=if($background){'Фоновый'}else{'Окно'}; Описание=$description; Stamp=$start}
        } catch {} finally { $p.Dispose() }
    }
}
function Startup {
    Get-CimInstance Win32_StartupCommand | Select-Object @{n='Название';e={$_.Name}},@{n='Команда';e={$_.Command}},@{n='Источник';e={$_.Location}},@{n='Пользователь';e={$_.User}}
}
function Devices {
    Get-CimInstance Win32_PnPEntity -Filter 'Present = TRUE' | Select-Object @{n='Устройство';e={$_.Name}},@{n='Класс';e={$_.PNPClass}},@{n='Статус';e={$_.Status}},@{n='Код ошибки';e={$_.ConfigManagerErrorCode}}
}
function Network {
    $first = @{}
    foreach ($n in [Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces()) {
        $first[$n.Id] = $n.GetIPv4Statistics()
    }
    $clock = [Diagnostics.Stopwatch]::StartNew()
    Start-Sleep -Milliseconds 800
    foreach ($n in [Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces()) {
        if ($n.OperationalStatus -ne 'Up' -or !$first.ContainsKey($n.Id)) {continue}
        $now=$n.GetIPv4Statistics()
        $dt=$clock.Elapsed.TotalSeconds
        [pscustomobject]@{Адаптер=$n.Name; 'Приём, Кбит/с'=[math]::Round(8*($now.BytesReceived-$first[$n.Id].BytesReceived)/1000/$dt,1); 'Передача, Кбит/с'=[math]::Round(8*($now.BytesSent-$first[$n.Id].BytesSent)/1000/$dt,1); 'Канал, Мбит/с'=[math]::Round($n.Speed/1e6); Guid=$n.Id}
    }
}
function SafePath($itemPath) {
    $item=Get-Item -LiteralPath $itemPath -Force
    $node=$item
    while ($node) {
        if ($node.Attributes -band [IO.FileAttributes]::ReparsePoint) {throw "Пропущена ссылка: $($node.FullName)"}
        if ($node -is [IO.FileInfo]) {$node=$node.Directory} else {$node=$node.Parent}
    }
    $item
}
function Scan($root,$mode) {
    $base=SafePath $root
    $stack=New-Object 'Collections.Generic.Stack[string]'
    $stack.Push($base.FullName)
    $groups=@{}
    $results=New-Object Collections.ArrayList
    while ($stack.Count) {
        $dir=$stack.Pop()
        foreach ($item in Get-ChildItem -LiteralPath $dir -Force -ErrorAction SilentlyContinue) {
            if ($item.Attributes -band ([IO.FileAttributes]::ReparsePoint -bor [IO.FileAttributes]::System)) {continue}
            if ($item.PSIsContainer) {
                $stack.Push($item.FullName)
                if ($mode -eq 'empty' -and !@(Get-ChildItem -LiteralPath $item.FullName -Force -ErrorAction SilentlyContinue -ErrorVariable listingErrors).Count -and !$listingErrors) {
                    [void]$results.Add([pscustomobject]@{Путь=$item.FullName; Байт=0; Тип='Пустая папка'})
                }
                continue
            }
            if ($mode -eq 'dup') {
                $k=[string]$item.Length
                if (!$groups.ContainsKey($k)) {$groups[$k]=New-Object Collections.ArrayList}
                [void]$groups[$k].Add($item)
                continue
            }
            if ($mode -eq 'empty' -and $item.Length -ne 0) {continue}
            [void]$results.Add([pscustomobject]@{Путь=$item.FullName; Байт=$item.Length; Тип=if($item.Length){'Файл'}else{'Пустой файл'}})
        }
    }
    if ($mode -eq 'dup') {
        foreach ($group in $groups.Values) {
            if ($group.Count -lt 2) {continue}
            $seen=@{}
            foreach ($f in $group) {
                try {$hash=(Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash} catch {continue}
                if (!$seen.ContainsKey($hash)) {$seen[$hash]=$f.FullName; continue}
                [void]$results.Add([pscustomobject]@{Путь=$f.FullName; Байт=$f.Length; Оригинал=$seen[$hash]})
            }
        }
    }
    $results | Sort-Object Байт -Descending
}
function Recycle($row,$root,$mode) {
    Add-Type -AssemblyName Microsoft.VisualBasic
    $folder=(SafePath $root).FullName.TrimEnd('\')+'\'
    $item=SafePath $row.Путь
    if (!$item.FullName.StartsWith($folder,[StringComparison]::OrdinalIgnoreCase)) {throw 'Путь вне выбранной папки'}
    if ($mode -eq 'dup') {
        $keep=SafePath $row.Оригинал
        if ($keep.FullName -eq $item.FullName -or (Get-FileHash -LiteralPath $keep.FullName).Hash -ne (Get-FileHash -LiteralPath $item.FullName).Hash) {throw 'Содержимое изменилось. Повторите поиск.'}
    } elseif ($mode -eq 'temp') {
        if ($folder.TrimEnd('\') -ne [IO.Path]::GetTempPath().TrimEnd('\')) {throw 'Изменилась папка TEMP'}
    } elseif ($mode -ne 'empty') {throw 'Выберите режим очистки'}
    if ($item.PSIsContainer) {
        if ($mode -ne 'empty' -or @(Get-ChildItem -LiteralPath $item.FullName -Force).Count) {throw 'Папка уже содержит файлы'}
        # Nonrecursive deletion fails atomically if a file appeared since enumeration.
        [IO.Directory]::Delete($item.FullName,$false)
    } else {
        if ($mode -eq 'empty' -and $item.Length) {throw 'Файл перестал быть пустым'}
        [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($item.FullName,'OnlyErrorDialogs','SendToRecycleBin','ThrowException')
    }
}
function Api($endpoint,$key,$model,$history,$list,$sessionId) {
    [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
    $uri=[uri]$endpoint
    if (!$uri.IsAbsoluteUri -or $uri.Scheme -ne 'https' -or $uri.UserInfo -or $uri.Query -or $uri.Fragment) {throw 'Укажите базовый HTTPS-адрес API'}
    $base=$uri.AbsoluteUri.TrimEnd('/')
    $headers=@{Authorization="Bearer $key"}
    $modelsUrl="$base/models"
    $requestOptions=@{}
    if ($base -eq 'https://opencode.ai/inference/go/openai/v1') {
        $modelsUrl='https://opencode.ai/inference/go/v1/models'
        $headers['x-opencode-session']=$sessionId
        $requestOptions.UserAgent='UltimateWin/1.0'
    }
    if ($list) {
        (Invoke-RestMethod @requestOptions $modelsUrl -Headers $headers -MaximumRedirection 0 -TimeoutSec 30).data | ForEach-Object id
    } else {
        $json=@{model=$model;messages=$history;stream=$false}|ConvertTo-Json -Depth 8 -Compress
        $answer=Invoke-RestMethod @requestOptions "$base/chat/completions" -Method Post -Headers $headers -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($json)) -MaximumRedirection 0 -TimeoutSec 90
        if (!$answer.choices[0].message.content) {throw 'Провайдер вернул пустой ответ'}
        $answer.choices[0].message.content
    }
}
