$ErrorActionPreference='Stop'

function Metrics {
    $os = Get-CimInstance Win32_OperatingSystem -OperationTimeoutSec 8
    $cpu = @(Get-CimInstance Win32_PerfFormattedData_PerfOS_Processor -Filter "Name='_Total'" -OperationTimeoutSec 8 -ErrorAction SilentlyContinue)[0]
    $gpu = @(Get-CimInstance Win32_PerfFormattedData_GPUPerformanceCounters_GPUAdapterMemory -OperationTimeoutSec 8 -ErrorAction SilentlyContinue)
    $ram = ($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / 1MB
    $vram = 'Нет данных драйвера'
    if ($gpu.Count) { $vram = '{0:N2} ГиБ' -f (($gpu | Measure-Object DedicatedUsage -Sum).Sum / 1GB) }
    [pscustomobject]@{
        CPU = if ($null -ne $cpu.PercentProcessorTime) {'{0} %' -f $cpu.PercentProcessorTime} else {'Нет данных'}
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
    DisabledStartup
    $views = if ([Environment]::Is64BitOperatingSystem) {'Registry64','Registry32'} else {'Registry32'}
    foreach ($hive in 'CurrentUser','LocalMachine') {
        $owner = if ($hive -eq 'CurrentUser') {'Текущий пользователь'} else {'Все пользователи'}
        foreach ($view in $views) {
            # HKCU Run is shared between registry views.
            if ($hive -eq 'CurrentUser' -and $view -ne @($views)[0]) {continue}
            $base = [Microsoft.Win32.RegistryKey]::OpenBaseKey($hive,$view)
            try {
                foreach ($leaf in 'Run','RunOnce') {
                    $key=$base.OpenSubKey("Software\Microsoft\Windows\CurrentVersion\$leaf")
                    if (!$key) {continue}
                    try {
                        foreach ($name in $key.GetValueNames()) {
                            if (!$name -or $key.GetValueKind($name) -notin 'String','ExpandString') {continue}
                            $command=$key.GetValue($name,$null,'DoNotExpandEnvironmentNames')
                            [pscustomobject]@{Название=$name;Команда=$command;Источник="$leaf · $view";Пользователь=$owner;Target=@{Hive=$hive;View=$view;Leaf=$leaf}}
                        }
                    } finally {$key.Dispose()}
                }
            } finally {$base.Dispose()}
        }
    }
    foreach ($special in 'Startup','CommonStartup') {
        $folder=[Environment]::GetFolderPath($special)
        if (!$folder -or !(Test-Path -LiteralPath $folder)) {continue}
        foreach ($f in Get-ChildItem -LiteralPath $folder -File -Force) {
            if ($f.Name -eq 'desktop.ini' -or ($f.Attributes -band [IO.FileAttributes]::ReparsePoint)) {continue}
            [pscustomobject]@{Название=$f.Name;Команда=$f.FullName;Источник='Папка автозагрузки';Пользователь=if($special -eq 'Startup'){'Текущий пользователь'}else{'Все пользователи'};Target=@{Folder=$special;Stamp=$f.LastWriteTimeUtc.Ticks;Length=$f.Length}}
        }
    }
}
function RemoveStartup($row) {
    $t=$row.Target
    if ($t.Folder -in 'Startup','CommonStartup') {
        $folder=SafePath ([Environment]::GetFolderPath($t.Folder))
        if ([IO.Path]::GetFileName($row.Название) -cne $row.Название) {throw 'Недопустимое имя файла'}
        $file=SafePath ([IO.Path]::Combine($folder.FullName,$row.Название))
        if ($file -isnot [IO.FileInfo] -or $file.FullName -ne $row.Команда -or $file.DirectoryName -ne $folder.FullName -or $file.LastWriteTimeUtc.Ticks -ne $t.Stamp -or $file.Length -ne $t.Length) {throw 'Запись изменилась. Обновите список.'}
        Add-Type -AssemblyName Microsoft.VisualBasic
        [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($file.FullName,'OnlyErrorDialogs','SendToRecycleBin','ThrowException')
        return
    }
    if ($t.Hive -notin 'CurrentUser','LocalMachine' -or $t.View -notin 'Registry32','Registry64' -or $t.Leaf -notin 'Run','RunOnce') {throw 'Неизвестный источник'}
    $base=[Microsoft.Win32.RegistryKey]::OpenBaseKey($t.Hive,$t.View)
    try {
        $key=$base.OpenSubKey("Software\Microsoft\Windows\CurrentVersion\$($t.Leaf)",$true)
        if (!$key) {throw 'Раздел автозагрузки недоступен'}
        try {
            if ($key.GetValue($row.Название,$null,'DoNotExpandEnvironmentNames') -cne $row.Команда) {throw 'Запись изменилась. Обновите список.'}
            $key.DeleteValue($row.Название)
        } finally {$key.Dispose()}
    } finally {$base.Dispose()}
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
    $sizes=@{}
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
            if ($mode -eq 'folders') {
                $relative=$item.FullName.Substring($base.FullName.TrimEnd([IO.Path]::DirectorySeparatorChar).Length+1)
                $parts=$relative.Split([char[]]@([IO.Path]::DirectorySeparatorChar),2)
                $bucket=if ($parts.Length -gt 1){$parts[0]}else{'(файлы в корне)'}
                $sizes[$bucket]+=[long]$item.Length
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
    if ($mode -eq 'folders') {
        foreach ($key in $sizes.Keys) {
            [void]$results.Add([pscustomobject]@{Размещение=$key;Байт=$sizes[$key];'МиБ'=[math]::Round($sizes[$key]/1MB,2)})
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

function LoadSample {
    $samples=@()
    $clock=[Diagnostics.Stopwatch]::StartNew()
    do {
        $cpu=Get-CimInstance Win32_PerfFormattedData_PerfOS_Processor -Filter "Name='_Total'" -OperationTimeoutSec 4 -ErrorAction SilentlyContinue
        $disk=Get-CimInstance Win32_PerfFormattedData_PerfDisk_PhysicalDisk -Filter "Name='_Total'" -OperationTimeoutSec 4 -ErrorAction SilentlyContinue
        $os=Get-CimInstance Win32_OperatingSystem -OperationTimeoutSec 4
        $samples += [pscustomobject]@{
            CPU=$cpu.PercentProcessorTime
            Disk=if ($null -ne $disk.PercentIdleTime) {100-[math]::Min(100,$disk.PercentIdleTime)}
            RAM=100*(1-$os.FreePhysicalMemory/$os.TotalVisibleMemorySize)
        }
        if ($clock.Elapsed.TotalSeconds -lt 30) {Start-Sleep -Milliseconds 1500}
    } while ($clock.Elapsed.TotalSeconds -lt 30)
    foreach ($metric in @(@('CPU','Процессор',85),@('Disk','Активность диска',90),@('RAM','Занятая память',90))) {
        $values=@($samples | ForEach-Object {$_.$($metric[0])} | Where-Object {$null -ne $_})
        $avg=($values | Measure-Object -Average).Average
        [pscustomobject]@{Ресурс=$metric[1];'Среднее, %'=if ($values.Count){[math]::Round($avg,1)};Замеров=$values.Count;Оценка=if (!$values.Count){'Нет показаний'} elseif ($avg -ge $metric[2]){'Высокая нагрузка во время проверки'}else{'Среднее в пределах порога'}}
    }
}
function NetworkChecks {
    $routes=@([Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces() | Where-Object {$_.OperationalStatus -eq 'Up' -and $_.GetIPProperties().GatewayAddresses.Count})
    [pscustomobject]@{Проверка='Маршрут';Результат=if ($routes.Count){($routes.Name -join ', ')}else{'Активный интерфейс со шлюзом не найден'}}
    if ($routes.Count) {
        $gateway=$routes[0].GetIPProperties().GatewayAddresses[0].Address
        $ping=[Net.NetworkInformation.Ping]::new()
        try {$state=$ping.Send($gateway,1500).Status.ToString()} catch {$state=$_.Exception.GetBaseException().Message} finally {$ping.Dispose()}
        [pscustomobject]@{Проверка="Шлюз $gateway (ICMP)";Результат=$state}
    }
    $site='www.microsoft.com'
    try {
        $lookup=[Net.Dns]::GetHostAddressesAsync($site)
        if (!$lookup.Wait(5000)) {throw 'Истекло время ожидания'}
        $dns=($lookup.Result.IPAddressToString -join ', ')
    } catch {$dns=$_.Exception.GetBaseException().Message}
    [pscustomobject]@{Проверка="DNS · $site";Результат=$dns}
    try {
        $res=Invoke-WebRequest "https://$site/" -UseBasicParsing -Method Head -TimeoutSec 8
        $https="HTTP $([int]$res.StatusCode)"
    } catch {$https=$_.Exception.GetBaseException().Message}
    [pscustomobject]@{Проверка="HTTPS · $site";Результат=$https}
}

function DisabledStartup {
    $key=[Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Software\UltimateWin\DisabledRun')
    if (!$key) {return}
    try {
        foreach ($name in $key.GetValueNames()) {
            [pscustomobject]@{Название=$name;Команда=$key.GetValue($name,$null,'DoNotExpandEnvironmentNames');Источник='Отключено в Ultimate Win';Пользователь='Текущий пользователь';Target=@{Disabled=$true}}
        }
    } finally {$key.Dispose()}
}
function SwitchStartup($row) {
    $t=$row.Target
    if (!$t.Disabled -and ($t.Hive -ne 'CurrentUser' -or $t.Leaf -ne 'Run')) {throw 'Переключатель доступен для постоянных команд текущего пользователя. Другими приложениями можно управлять в параметрах Windows.'}
    # Both locations belong to the same user. Never restore user data into HKLM.
    $mutex=[Threading.Mutex]::new($false,'Local\UltimateWin-StartupSwitch')
    try {
        try {$locked=$mutex.WaitOne(3000)} catch [Threading.AbandonedMutexException] {$locked=$true}
        if (!$locked) {throw 'Автозагрузка занята другим экземпляром приложения'}
        $live=[Microsoft.Win32.Registry]::CurrentUser.CreateSubKey('Software\Microsoft\Windows\CurrentVersion\Run')
        try {
            $backup=[Microsoft.Win32.Registry]::CurrentUser.CreateSubKey('Software\UltimateWin\DisabledRun')
            try {
                $from=$live;$to=$backup
                if ($t.Disabled) {$from=$backup;$to=$live}
                $name=$row.Название
                $value=$from.GetValue($name,$null,'DoNotExpandEnvironmentNames')
                if ($null -eq $value -or $value -cne $row.Команда) {throw 'Запись изменилась. Обновите список.'}
                $kind=$from.GetValueKind($name)
                if ($kind -notin 'String','ExpandString') {throw 'Неизвестный тип команды'}
                $existing=$to.GetValue($name,$null,'DoNotExpandEnvironmentNames')
                if ($null -ne $existing -and ($existing -cne $value -or $to.GetValueKind($name) -ne $kind)) {throw 'Уже существует другая запись с этим именем'}
                $to.SetValue($name,$value,$kind)
                $to.Flush()
                $from.DeleteValue($name)
            } finally {$backup.Dispose()}
        } finally {$live.Dispose()}
    } finally {if ($locked) {$mutex.ReleaseMutex()};$mutex.Dispose()}
}
