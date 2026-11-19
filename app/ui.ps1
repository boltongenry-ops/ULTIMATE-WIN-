Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase,System.Windows.Forms
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class PauseControl {
 [DllImport("ntdll.dll")] public static extern int NtSuspendProcess(IntPtr handle);
 [DllImport("ntdll.dll")] public static extern int NtResumeProcess(IntPtr handle);
}
'@
[xml]$layout=@'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Title="Ultimate Win" Width="1120" Height="730" MinWidth="900" MinHeight="590" WindowStartupLocation="CenterScreen" FontFamily="Segoe UI" Background="#F3F6FA" Foreground="#182C44">
<Window.Resources>
<Style TargetType="Button"><Setter Property="Background" Value="White"/><Setter Property="Foreground" Value="#193856"/><Setter Property="Padding" Value="14,9"/><Setter Property="Margin" Value="0,0,8,8"/><Setter Property="Cursor" Value="Hand"/><Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button"><Border x:Name="box" Background="{TemplateBinding Background}" CornerRadius="7" Padding="{TemplateBinding Padding}" BorderBrush="#C5D4DF" BorderThickness="1"><ContentPresenter HorizontalAlignment="{TemplateBinding HorizontalContentAlignment}"/></Border><ControlTemplate.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter TargetName="box" Property="Opacity" Value=".78"/></Trigger><Trigger Property="IsEnabled" Value="False"><Setter TargetName="box" Property="Opacity" Value=".45"/></Trigger></ControlTemplate.Triggers></ControlTemplate></Setter.Value></Setter></Style>
<Style TargetType="TextBox"><Setter Property="Padding" Value="8,5"/><Setter Property="VerticalContentAlignment" Value="Center"/></Style>
</Window.Resources>
<Grid><Grid.ColumnDefinitions><ColumnDefinition Width="210"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
<Border Background="#142C44" Padding="18,28"><StackPanel><TextBlock Text="Ultimate Win" FontWeight="SemiBold" FontSize="25" Foreground="White" Margin="6,0,0,32"/><StackPanel Name="Nav"/></StackPanel></Border>
<Grid Grid.Column="1" Margin="30,24"><Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
<TextBlock Name="Heading" FontSize="30" FontWeight="SemiBold"/><TextBlock Name="Hint" Grid.Row="1" TextWrapping="Wrap" Foreground="#46627A" Margin="0,6,0,18"/>
<StackPanel Name="Controls" Grid.Row="2"/><Grid Name="Body" Grid.Row="3" Margin="0,5"/>
<TextBlock Name="Status" Grid.Row="4" Margin="0,10,0,0" TextWrapping="Wrap" Foreground="#385B72"/></Grid></Grid></Window>
'@
$win=[Windows.Markup.XamlReader]::Load([Xml.XmlNodeReader]::new($layout))
foreach ($name in 'Heading','Hint','Controls','Body','Status','Nav') {Set-Variable -Name $name -Value $win.FindName($name)}
$pages='Обзор','Процессы','Автозагрузка','Устройства','Файлы','Сеть','Диагностика','ИИ-помощник'
$navButtons=@{}
$paused=@{}
$history=New-Object Collections.ArrayList
$baseUrl='https://opencode.ai/inference/go/openai/v1'
$selectedModel=''
$sessionKey=''
$transcript=''
$root=[Environment]::GetFolderPath('MyDocuments')
$mode='size'
$backgroundOnly=$false
$pending=''
$approvedActions=@{dns='Очистить кэш DNS';verify='Проверить системные файлы';metrics='Показать показатели Windows'}
$job=$null
function Button($panel,$label,$fn) {
    $b=New-Object Windows.Controls.Button
    $b.Content=$label
    $b.Add_Click($fn)
    [void]$panel.Children.Add($b)
    $b
}
function Row {
    $r=New-Object Windows.Controls.WrapPanel
    [void]$Controls.Children.Add($r)
    $r
}
function Label($panel,$value,$size) {
    $t=New-Object Windows.Controls.TextBlock
    $t.Text=$value; $t.FontSize=$size; $t.TextWrapping='Wrap'; $t.Margin='0,3,12,6'
    [void]$panel.Children.Add($t)
    $t
}
function Table {
    $script:grid=New-Object Windows.Controls.DataGrid
    $grid.IsReadOnly=$true; $grid.CanUserAddRows=$false; $grid.SelectionMode='Single'
    $grid.Background='White'; $grid.BorderBrush='#D5E1EB'; $grid.RowHeight=32
    $grid.HeadersVisibility='Column'; $grid.GridLinesVisibility='Horizontal'; $grid.HorizontalGridLinesBrush='#E6EDF3'
    # Explicit columns also support PowerShell custom objects on .NET Framework.
    $grid.AutoGenerateColumns=$false
    [void]$Body.Children.Add($grid)
}
function Fill($items) {
    $data=@($items | Where-Object { $null -ne $_ })
    $grid.Columns.Clear()
    if ($data.Count) {
        foreach ($prop in $data[0].PSObject.Properties.Name) {
            if ($prop -in 'Stamp','Guid') {continue}
            $col=New-Object Windows.Controls.DataGridTextColumn
            $col.Header=$prop; $col.Binding=New-Object Windows.Data.Binding($prop)
            [void]$grid.Columns.Add($col)
        }
    }
    $grid.ItemsSource=$data
    $Status.Text="Строк: $($data.Count)"
}
function Run($code,$arguments,$done) {
    if ($script:job) {return}
    $ps=[PowerShell]::Create()
    [void]$ps.AddScript($workerSource).AddStatement().AddScript($code)
    foreach ($argValue in $arguments) {[void]$ps.AddArgument($argValue)}
    $Status.Text='Выполняется…'
    $Nav.IsEnabled=$false; $Controls.IsEnabled=$false; $Body.IsEnabled=$false
    $script:job=@{ps=$ps;handle=$ps.BeginInvoke();done=$done}
}
$timer=New-Object Windows.Threading.DispatcherTimer
$timer.Interval=[TimeSpan]::FromMilliseconds(200)
$timer.Add_Tick({
    if (!$job) {
        if ($win.IsVisible -and $win.IsActive -and $active -eq 'Обзор' -and [DateTime]::UtcNow -ge $nextRefresh) {Dashboard}
        return
    }
    if (!$job.handle.IsCompleted) {return}
    $finished=$job; $script:job=$null
    $Nav.IsEnabled=$true; $Controls.IsEnabled=$true; $Body.IsEnabled=$true
    try {
        $response=@($finished.ps.EndInvoke($finished.handle))
        
        $Status.Text='Готово'
        & $finished.done $response
    } catch {$Status.Text="Ошибка: $($_.Exception.Message)"}
    finally {$finished.ps.Dispose()}
})
function Confirm($text) {
    [Windows.MessageBox]::Show($win,$text,'Ultimate Win','YesNo','Question','No') -eq 'Yes'
}
function Dashboard {
    $script:nextRefresh=[DateTime]::UtcNow.AddSeconds(5)
    Run 'Metrics' @() {param($rows)
        $m=$rows[0]
        $Body.Children.Clear()
        $stack=New-Object Windows.Controls.StackPanel
        [void]$Body.Children.Add($stack)
        $cards=New-Object Windows.Controls.Primitives.UniformGrid
        $cards.Rows=1; $cards.Columns=3
        [void]$stack.Children.Add($cards)
        foreach ($pair in @(@('Процессор',$m.CPU),@('ОЗУ · занято',$m.RAM),@('Видеопамять · занято',$m.VRAM))) {
            $card=New-Object Windows.Controls.Border
            $card.Background='White'; $card.CornerRadius='12'; $card.Padding='14'; $card.Margin='0,0,8,16'
            $inside=New-Object Windows.Controls.StackPanel
            $card.Child=$inside; [void]$cards.Children.Add($card)
            (Label $inside $pair[0] 13).Foreground='#47738A'
            (Label $inside $pair[1] 22).FontWeight='SemiBold'
        }
        [void](Label $stack $m.OS 20)
        [void](Label $stack "С момента загрузки: $($m.Uptime)" 14)
        $Status.Text="Обновлено в $(Get-Date -Format HH:mm:ss)"
    }
}
function RefreshProcesses {
    Run 'Processes | Sort-Object "Память, МиБ" -Descending' @() {param($rows)
        if ($backgroundOnly) {Fill @($rows | Where-Object Вид -eq 'Фоновый')} else {Fill $rows}
    }
}
function ProcessAction($action) {
    $row=$grid.SelectedItem
    if (!$row) {$Status.Text='Выберите процесс';return}
    try {
        $id=[int]$row.PID
        if ($action -eq 'Возобновить') {
            if (!$paused.ContainsKey($id)) {throw 'Выберите процесс, приостановленный в этой сессии'}
            $p=$paused[$id]
            if (!$p.HasExited -and [PauseControl]::NtResumeProcess($p.Handle) -ne 0) {throw 'Windows отклонила возобновление'}
            $paused.Remove($id);$p.Dispose()
        } else {
            $p=Get-Process -Id $id
            try {
                $handle=$p.Handle
                $osPath=[Environment]::GetFolderPath('Windows')+'\'
                if (!$row.Stamp -or $p.StartTime.ToUniversalTime().Ticks -ne $row.Stamp -or $id -eq $PID -or $p.SessionId -ne (Get-Process -Id $PID).SessionId -or !$p.MainWindowHandle.ToInt64() -or !$p.Path -or $p.Path.StartsWith($osPath,[StringComparison]::OrdinalIgnoreCase)) {throw 'Действие доступно для оконных приложений текущего сеанса вне папки Windows'}
                if ($paused.ContainsKey($id)) {throw 'Сначала возобновите приложение'}
                if (!(Confirm "$action $($p.ProcessName) (PID $id)? Несохранённые данные могут быть потеряны.")) {return}
                if ($p.HasExited) {throw 'Процесс уже завершился'}
                if ($action -eq 'Завершить') {$p.Kill()} else {
                    if ([PauseControl]::NtSuspendProcess($handle) -ne 0) {throw 'Windows отклонила приостановку'}
                    $paused[$id]=$p
                }
            } finally {if (!$paused.ContainsKey($id)) {$p.Dispose()}}
        }
        RefreshProcesses
    } catch {$Status.Text=$_.Exception.Message}
}
function FileScan {
    $script:scanRoot=$root; $script:scanMode=$mode
    $grid.ItemsSource=$null
    Run 'param($r,$m) Scan $r $m' @($root,$mode) {param($rows) Fill $rows}
}
function Elevated($exe,$argsText) {
    Run 'param($exe,$a) $p=Start-Process -FilePath $exe -ArgumentList $a -Verb RunAs -PassThru -Wait; if($p.ExitCode -ne 0){throw "Код завершения: $($p.ExitCode)"}' @($exe,$argsText) {ActionResult 'Команда завершена, код 0'}
}
function ActionResult($result) {
    $Status.Text=$result
    if ($active -eq 'ИИ-помощник') {
        [void]$history.Add(@{role='user';content="Результат подтверждённого действия Windows: $result"})
        $script:transcript+="Windows · $result`r`n`r`n"
        $log.Text=$transcript;$log.ScrollToEnd()
    }
}
function Action($id) {
    if (!$approvedActions.ContainsKey($id)) {return}
    if (!(Confirm "$($approvedActions[$id])?")) {return}
    switch ($id) {
        metrics {Page 'Обзор'}
        dns {Run 'Clear-DnsClientCache' @() {ActionResult 'Кэш DNS очищен'}}
        verify {Elevated "$env:SystemRoot\System32\sfc.exe" '/verifyonly'}
    }
}
function RememberChat {
    $script:baseUrl=$endpoint.Text.Trim();$script:sessionKey=$secret.Password;$script:selectedModel=$model.Text.Trim()
    if ($script:conversationEndpoint -ne $baseUrl) {
        $script:chatSession=[guid]::NewGuid().ToString();$history.Clear();$script:transcript='';$script:pending='';$script:conversationEndpoint=$baseUrl
        $log.Text='';$apply.Visibility='Collapsed'
    }
}
function SendChat {
    RememberChat
    $question=$inputBox.Text.Trim()
    if (!$question -or !$selectedModel -or !$sessionKey) {$Status.Text='Введите API-ключ, модель и сообщение';return}
    $script:pending='';$apply.Visibility='Collapsed'
    $script:sent=$question
    $sys='Отвечай по-русски. Ты помощник по Windows. Для предложения действия добавь отдельной последней строкой ACTION: dns, ACTION: verify или ACTION: metrics. Доступны только эти действия после согласия пользователя. Не утверждай, что действие выполнено.'
    $messages=@(@{role='system';content=$sys}) + @($history) + @(@{role='user';content=$question})
    Run 'param($url,$key,$model,$msgs,$share,$sid) if($share){$msgs=@($msgs)+@(@{role="user";content=("Сводка Windows: "+((Metrics)|ConvertTo-Json -Compress))})}; Api $url $key $model $msgs $false $sid' @($baseUrl,$sessionKey,$selectedModel,$messages,$share.IsChecked,$chatSession) {param($rows)
        $answer=[string]$rows[0]
        [void]$history.Add(@{role='user';content=$sent});[void]$history.Add(@{role='assistant';content=$answer})
        if ($answer -match '(?m)^ACTION: (dns|verify|metrics)\s*\z') {
            $script:pending=$Matches[1];$answer=$answer.Substring(0,$answer.LastIndexOf('ACTION:')).TrimEnd()
            $apply.Content=$approvedActions[$pending];$apply.Visibility='Visible'
        }
        $script:transcript+="Вы · $sent`r`n`r`nПомощник · $answer`r`n`r`n"
        $log.Text=$transcript;$log.ScrollToEnd();$inputBox.Clear()
    }
}
function Page($name) {
    if ($script:active -eq 'ИИ-помощник') {RememberChat}
    $script:active=$name; $Heading.Text=$name
    $Controls.Children.Clear();$Body.Children.Clear();$Status.Text=''
    foreach ($entry in $navButtons.GetEnumerator()) {
        $entry.Value.Background=if ($entry.Key -eq $name){'#206A78'}else{'#1B374F'}
    }
    $r=Row
    switch ($name) {
        'Обзор' {
            $Hint.Text='Текущая нагрузка и ресурсы компьютера · обновление каждые 5 секунд'
            [void](Button $r 'Обновить' {Dashboard})
            Dashboard
        }
        'Процессы' {
            $Hint.Text='Фоновые процессы работают без видимого главного окна. Описание берётся из сведений о программе, когда они доступны.'
            [void](Button $r 'Обновить' {RefreshProcesses})
            [void](Button $r 'Все / фоновые' {$script:backgroundOnly=!$backgroundOnly;RefreshProcesses})
            foreach ($act in 'Приостановить','Возобновить','Завершить') {
                [void](Button $r $act {param($sender,$eventArgs) ProcessAction $sender.Content})
            }
            Table;RefreshProcesses
        }
        'Автозагрузка' {
            $Hint.Text='Команды, зарегистрированные для запуска при входе в Windows'
            [void](Button $r 'Обновить' {Page 'Автозагрузка'})
            Table;Run 'Startup' @() {param($rows) Fill $rows}
        }
        'Устройства' {
            $Hint.Text='Подключённые устройства Plug and Play и состояние их драйверов'
            [void](Button $r 'Обновить' {Page 'Устройства'})
            Table;Run 'Devices' @() {param($rows) Fill $rows}
        }
        'Файлы' {
            $Hint.Text='Выберите папку и режим поиска. Дубли сравниваются по содержимому. Недоступные папки и ссылки пропускаются.'
            [void](Button $r 'Выбрать папку' {
                $dlg=New-Object Windows.Forms.FolderBrowserDialog
                try {if ($dlg.ShowDialog() -eq 'OK') {$script:root=$dlg.SelectedPath;$script:mode='size';Page 'Файлы'}} finally {$dlg.Dispose()}
            })
            foreach ($choice in @(@('Размеры','size'),@('Дубли','dup'),@('Пустые','empty'),@('TEMP','temp'))) {
                $btn=Button $r $choice[0] {param($sender,$e)
                    $script:mode=$sender.Tag
                    if ($mode -eq 'temp') {$script:root=[IO.Path]::GetTempPath()}
                    $folderLabel.Text="$($sender.Content) · $root"
                    FileScan
                }
                $btn.Tag=$choice[1]
            }
            $script:folderLabel=Label $Controls $root 14
            [void](Button (Row) 'Удалить выбранное' {
                $selected=$grid.SelectedItem
                if (!$selected -or $scanMode -eq 'size') {$Status.Text='Выберите строку в результатах поиска дублей, пустышек или TEMP';return}
                $prompt=if ($selected.Тип -eq 'Пустая папка') {'Удалить пустую папку без корзины?'}else{'Переместить файл в корзину?'}
                if (Confirm "$prompt`n$($selected.Путь)") {
                    Run 'param($row,$r,$m) Recycle $row $r $m' @($selected,$scanRoot,$scanMode) {FileScan}
                }
            })
            Table
        }
        'Сеть' {
            $Hint.Text='Скорость передачи данных по активным интерфейсам за последний интервал измерения'
            [void](Button $r 'Измерить' {Page 'Сеть'})
            [void](Button $r 'Очистить DNS' {Action 'dns'})
            [void](Button $r 'Перезапустить адаптер' {
                $item=$grid.SelectedItem
                if (!$item) {$Status.Text='Выберите сетевой адаптер';return}
                if (Confirm "Перезапустить адаптер $($item.Адаптер)? Соединение временно прервётся.") {
                    $guid=([guid]$item.Guid).ToString()
                    $command="`$ErrorActionPreference='Stop'; `$n=Get-NetAdapter | Where-Object { `$_.InterfaceGuid -eq [guid]'$guid' }; if (!`$n) {throw 'Adapter unavailable'}; `$n | Restart-NetAdapter -Confirm:`$false -ErrorAction Stop"
                    Elevated "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" ("-NoProfile -EncodedCommand "+[Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command)))
                }
            })
            Table;Run 'Network' @() {param($rows) Fill $rows}
        }
        'Диагностика' {
            $Hint.Text='Windows проверит целостность защищённых системных файлов. Результат выводится в окне SFC и записывается в журнал CBS.'
            [void](Button $r 'Проверить систему' {Action 'verify'})
            [void](Button $r 'Открыть журнал CBS' {
                try {Start-Process "$env:SystemRoot\System32\notepad.exe" -ArgumentList ('"'+$env:SystemRoot+'\Logs\CBS\CBS.log"')} catch {$Status.Text=$_.Exception.Message}
            })
        }
        'ИИ-помощник' {
            $Hint.Text='Подключите OpenCode Go или совместимый Chat Completions API. Ключ хранится в памяти до закрытия приложения.'
            [void](Label $r 'Адрес API' 13)
            $script:endpoint=New-Object Windows.Controls.TextBox;$endpoint.Width=255;$endpoint.Text=$baseUrl;[void]$r.Children.Add($endpoint)
            [void](Label $r ' API-ключ' 13)
            $script:secret=New-Object Windows.Controls.PasswordBox;$secret.Width=165;$secret.Password=$sessionKey;[void]$r.Children.Add($secret)
            $r=Row
            [void](Label $r 'Модель' 13)
            $script:model=New-Object Windows.Controls.ComboBox;$model.IsEditable=$true;$model.Width=210;$model.Text=$selectedModel;[void]$r.Children.Add($model)
            [void](Button $r 'Загрузить модели' {
                RememberChat
                if (!$sessionKey) {$Status.Text='Введите API-ключ';return}
                Run 'param($url,$key,$sid) Api $url $key $null $null $true $sid' @($baseUrl,$sessionKey,$chatSession) {param($rows)
                    $model.ItemsSource=@($rows);if ($rows.Count) {$model.SelectedIndex=0}
                    $Status.Text="Моделей: $($rows.Count)"
                }
            })
            $script:share=New-Object Windows.Controls.CheckBox;$share.Content='Приложить сводку Windows';$share.VerticalAlignment='Center';[void]$r.Children.Add($share)
            $dock=New-Object Windows.Controls.DockPanel;[void]$Body.Children.Add($dock)
            $bottom=New-Object Windows.Controls.StackPanel;[Windows.Controls.DockPanel]::SetDock($bottom,'Bottom');[void]$dock.Children.Add($bottom)
            $script:inputBox=New-Object Windows.Controls.TextBox;$inputBox.Height=54;$inputBox.TextWrapping='Wrap';$inputBox.AcceptsReturn=$true;[void]$bottom.Children.Add($inputBox)
            $bar=New-Object Windows.Controls.WrapPanel;[void]$bottom.Children.Add($bar)
            [void](Button $bar 'Отправить' {SendChat})
            $script:apply=Button $bar 'Выполнить' {Action $pending}
            if ($pending) {$apply.Content=$approvedActions[$pending]} else {$apply.Visibility='Collapsed'}
            $script:log=New-Object Windows.Controls.TextBox;$log.IsReadOnly=$true;$log.TextWrapping='Wrap';$log.VerticalScrollBarVisibility='Auto';$log.Text=$transcript
            [void]$dock.Children.Add($log)
        }
    }
}
foreach ($section in $pages) {
    $b=Button $Nav $section {param($sender,$e) Page $sender.Content}
    $b.HorizontalContentAlignment='Left';$b.Foreground='White';$navButtons[$section]=$b
}
$win.Add_Closed({
    $timer.Stop()
    foreach ($p in $paused.Values) {try {if (!$p.HasExited) {[void][PauseControl]::NtResumeProcess($p.Handle)}} finally {$p.Dispose()}}
})
$timer.Start()
Page 'Обзор'
[void]$win.ShowDialog()
