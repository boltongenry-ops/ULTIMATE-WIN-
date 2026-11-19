Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase,System.Windows.Forms,System.Drawing
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class PauseControl {
 [DllImport("ntdll.dll")] public static extern int NtSuspendProcess(IntPtr handle);
 [DllImport("ntdll.dll")] public static extern int NtResumeProcess(IntPtr handle);
}
'@
[xml]$layout=@'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Title="Ultimate Win" Width="1120" Height="730" MinWidth="900" MinHeight="590" WindowStartupLocation="CenterScreen" FontFamily="Segoe UI" Background="{DynamicResource Backdrop}" Foreground="{DynamicResource Ink}">
<Window.Resources>
<Style TargetType="CheckBox"><Setter Property="Foreground" Value="{DynamicResource Ink}"/></Style>
<Style TargetType="DataGrid"><Setter Property="Background" Value="{DynamicResource Glass}"/><Setter Property="Foreground" Value="{DynamicResource Ink}"/><Setter Property="RowBackground" Value="{DynamicResource Surface}"/><Setter Property="AlternatingRowBackground" Value="{DynamicResource Glass}"/><Setter Property="BorderBrush" Value="{DynamicResource Edge}"/><Setter Property="HorizontalGridLinesBrush" Value="{DynamicResource Edge}"/></Style>
<Style TargetType="DataGridColumnHeader"><Setter Property="Padding" Value="10,8"/><Setter Property="FontWeight" Value="SemiBold"/><Setter Property="Background" Value="{DynamicResource Surface}"/><Setter Property="Foreground" Value="{DynamicResource Ink}"/></Style>
<Style TargetType="Button"><Setter Property="Background" Value="{DynamicResource Surface}"/><Setter Property="Foreground" Value="{DynamicResource Ink}"/><Setter Property="Padding" Value="14,9"/><Setter Property="Margin" Value="0,0,8,8"/><Setter Property="Cursor" Value="Hand"/><Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button"><Border x:Name="box" Background="{TemplateBinding Background}" CornerRadius="7" Padding="{TemplateBinding Padding}" BorderBrush="{DynamicResource Edge}" BorderThickness="1"><ContentPresenter HorizontalAlignment="{TemplateBinding HorizontalContentAlignment}"/></Border><ControlTemplate.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter TargetName="box" Property="Opacity" Value=".78"/></Trigger><Trigger Property="IsEnabled" Value="False"><Setter TargetName="box" Property="Opacity" Value=".45"/></Trigger></ControlTemplate.Triggers></ControlTemplate></Setter.Value></Setter></Style>
<Style TargetType="TextBox">
  <Setter Property="Background" Value="{DynamicResource Field}"/><Setter Property="Foreground" Value="{DynamicResource Ink}"/><Setter Property="CaretBrush" Value="{DynamicResource Ink}"/><Setter Property="BorderBrush" Value="{DynamicResource Edge}"/><Setter Property="Padding" Value="10,7"/><Setter Property="VerticalContentAlignment" Value="Center"/>
  <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="TextBox"><Border x:Name="Frame" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="7" Padding="{TemplateBinding Padding}"><ScrollViewer x:Name="PART_ContentHost" VerticalAlignment="{TemplateBinding VerticalContentAlignment}"/></Border><ControlTemplate.Triggers><Trigger Property="IsKeyboardFocusWithin" Value="True"><Setter TargetName="Frame" Property="BorderBrush" Value="{DynamicResource Accent}"/></Trigger></ControlTemplate.Triggers></ControlTemplate></Setter.Value></Setter>
</Style>
<Style TargetType="PasswordBox">
  <Setter Property="Background" Value="{DynamicResource Field}"/><Setter Property="Foreground" Value="{DynamicResource Ink}"/><Setter Property="CaretBrush" Value="{DynamicResource Ink}"/><Setter Property="Padding" Value="10,7"/>
  <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="PasswordBox"><Border x:Name="Frame" Background="{TemplateBinding Background}" BorderBrush="{DynamicResource Edge}" BorderThickness="1" CornerRadius="7" Padding="{TemplateBinding Padding}"><ScrollViewer x:Name="PART_ContentHost"/></Border><ControlTemplate.Triggers><Trigger Property="IsKeyboardFocusWithin" Value="True"><Setter TargetName="Frame" Property="BorderBrush" Value="{DynamicResource Accent}"/></Trigger></ControlTemplate.Triggers></ControlTemplate></Setter.Value></Setter>
</Style>
<Style TargetType="ComboBoxItem"><Setter Property="Foreground" Value="{DynamicResource Ink}"/><Setter Property="Padding" Value="10,6"/><Setter Property="Template"><Setter.Value><ControlTemplate TargetType="ComboBoxItem"><Border x:Name="Item" Background="Transparent" Padding="{TemplateBinding Padding}"><ContentPresenter/></Border><ControlTemplate.Triggers><Trigger Property="IsHighlighted" Value="True"><Setter TargetName="Item" Property="Background" Value="{DynamicResource Outgoing}"/></Trigger><Trigger Property="IsSelected" Value="True"><Setter TargetName="Item" Property="Background" Value="{DynamicResource Outgoing}"/></Trigger></ControlTemplate.Triggers></ControlTemplate></Setter.Value></Setter></Style>
<Style TargetType="ComboBox"><Setter Property="Foreground" Value="{DynamicResource Ink}"/><Setter Property="Template"><Setter.Value><ControlTemplate TargetType="ComboBox"><Grid>
<Border Background="{DynamicResource Field}" BorderBrush="{DynamicResource Edge}" BorderThickness="1" CornerRadius="7"/>
<TextBox x:Name="PART_EditableTextBox" Margin="1,1,30,1" Background="Transparent" BorderThickness="0"/>
<ToggleButton Focusable="False" HorizontalAlignment="Right" Width="30" IsChecked="{Binding IsDropDownOpen,RelativeSource={RelativeSource TemplatedParent},Mode=TwoWay}"><ToggleButton.Template><ControlTemplate TargetType="ToggleButton"><Border Background="Transparent"><TextBlock Text="⌄" HorizontalAlignment="Center" VerticalAlignment="Center" Foreground="{DynamicResource Ink}"/></Border></ControlTemplate></ToggleButton.Template></ToggleButton>
<Popup x:Name="PART_Popup" Placement="Bottom" IsOpen="{TemplateBinding IsDropDownOpen}" AllowsTransparency="True"><Border Background="{DynamicResource Field}" BorderBrush="{DynamicResource Edge}" BorderThickness="1" CornerRadius="7" MinWidth="{Binding ActualWidth,RelativeSource={RelativeSource TemplatedParent}}"><ScrollViewer MaxHeight="220"><ItemsPresenter/></ScrollViewer></Border></Popup>
</Grid></ControlTemplate></Setter.Value></Setter></Style>

</Window.Resources>
<Grid Margin="12"><Grid.ColumnDefinitions><ColumnDefinition Width="222"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
<Border Background="{DynamicResource Sidebar}" CornerRadius="18" Padding="14,22" BorderThickness="1" BorderBrush="{DynamicResource Edge}"><DockPanel><Button Name="ThemeSwitch" DockPanel.Dock="Bottom" Margin="2,12,2,0"/><ScrollViewer VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled"><StackPanel><StackPanel Orientation="Horizontal" Margin="0,0,0,24"><Image Name="BrandIcon" Width="36" Height="36"/><TextBlock Text="Ultimate Win" FontWeight="SemiBold" FontSize="20" Foreground="White" VerticalAlignment="Center" Margin="8,0,0,0"/></StackPanel><StackPanel Name="Nav"/></StackPanel></ScrollViewer></DockPanel></Border>
<Border Grid.Column="1" Margin="12,0,0,0" Background="{DynamicResource Glass}" BorderBrush="{DynamicResource Edge}" BorderThickness="1" CornerRadius="18" Padding="24"><Grid><Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
<TextBlock Name="Heading" FontSize="30" FontWeight="SemiBold"/><TextBlock Name="Hint" Grid.Row="1" TextWrapping="Wrap" Foreground="{DynamicResource Muted}" Margin="0,6,0,18"/>
<StackPanel Name="Controls" Grid.Row="2"/><Grid Name="Body" Grid.Row="3" Margin="0,5"/>
<DockPanel Grid.Row="4"><Button DockPanel.Dock="Right" Name="CancelRead" Content="Отменить" Visibility="Collapsed"/><TextBlock Name="Status" Margin="0,10,0,0" TextWrapping="Wrap" Foreground="{DynamicResource Muted}"/></DockPanel></Grid></Border></Grid></Window>
'@
$win=[Windows.Markup.XamlReader]::Load([Xml.XmlNodeReader]::new($layout))
foreach ($name in 'Heading','Hint','Controls','Body','Status','Nav') {Set-Variable -Name $name -Value $win.FindName($name)}
if ($env:ULTIMATEWIN_EXE) {
    $icon=[Drawing.Icon]::ExtractAssociatedIcon($env:ULTIMATEWIN_EXE)
    if ($icon) {
        try {
            $source=[Windows.Interop.Imaging]::CreateBitmapSourceFromHIcon($icon.Handle,[Windows.Int32Rect]::Empty,[Windows.Media.Imaging.BitmapSizeOptions]::FromEmptyOptions())
            $source.Freeze()
            $win.Icon=$source
            $win.FindName('BrandIcon').Source=$source
        } finally {$icon.Dispose()}
    }
}
$cancelRead=$win.FindName('CancelRead')
$cancelRead.Add_Click({
    if (!$job -or !$job.Cancellable -or $job.StopHandle) {return}
    $job.StopHandle=$job.ps.BeginStop($null,$null)
    $cancelRead.IsEnabled=$false
    $Status.Text='Останавливаем проверку…'
})
$themeFile=Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'UltimateWin/theme.txt'
function SetTheme($dark) {
    $script:darkTheme=[bool]$dark
    $palette=if ($dark) {
        @{Field='#18252F'; Accent='#60CFC0'; Outgoing='#EB20454A'; Ink='#F1F5FB'; Muted='#ACC2D1'; Glass='#B0181C24'; Surface='#F3242B36'; Sidebar='#CC0A1018'; Edge='#565E7888'; Start='#080B11'; Glow='#15444B'; End='#18152D'}
    } else {
        @{Field='#E6F0F2'; Accent='#16736C'; Outgoing='#EDC9ECE8'; Ink='#102C3C'; Muted='#405F71'; Glass='#ACFFFFFF'; Surface='#EAF9FCFF'; Sidebar='#DC183044'; Edge='#887C9EAC'; Start='#C1DCE5'; Glow='#9EE0DC'; End='#D8CFEB'}
    }
    $brush=[Windows.Media.BrushConverter]::new()
    foreach ($key in 'Accent','Field','Outgoing','Ink','Muted','Glass','Surface','Sidebar','Edge') {
        $win.Resources[$key]=$brush.ConvertFromString($palette[$key])
    }
    $gradient=[Windows.Media.LinearGradientBrush]::new()
    $gradient.EndPoint=[Windows.Point]::new(1,0.85)
    foreach ($stop in @(@('Start',0),@('Glow',0.42),@('End',1))) {
        $color=[Windows.Media.ColorConverter]::ConvertFromString($palette[$stop[0]])
        $gradient.GradientStops.Add([Windows.Media.GradientStop]::new($color,$stop[1]))
    }
    $win.Resources['Backdrop']=$gradient
    $themeSwitch.Content=if ($dark) {'☀   Светлая тема'} else {'☾   Тёмная тема'}
}
$themeSwitch=$win.FindName('ThemeSwitch')
$initialDark=$false
try {
    if ([IO.File]::Exists($themeFile)) {$initialDark=[IO.File]::ReadAllText($themeFile) -eq 'dark'}
    else {$initialDark=(Get-ItemPropertyValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' AppsUseLightTheme) -eq 0}
} catch {}
SetTheme $initialDark
$themeSwitch.Add_Click({
    SetTheme (!$darkTheme)
    try {
        [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($themeFile))
        $value=if ($darkTheme) {'dark'} else {'light'}
        [IO.File]::WriteAllText($themeFile,$value)
    } catch {$Status.Text='Тема применена только для текущего сеанса'}
})
$pages='Обзор','Процессы','Автозагрузка','Устройства','Драйверы','Программы','Диски','Файлы','Память','Сеть','Диагностика','ИИ-помощник'
$navButtons=@{}
$paused=@{}
$history=New-Object Collections.ArrayList
$baseUrl='https://opencode.ai/inference/go/openai/v1'
$selectedModel=''
$sessionKey=''
$chatEntries=New-Object Collections.ArrayList
$draft=''
$snapshot=''
$conversationEndpoint=$baseUrl
$chatSession=[guid]::NewGuid().ToString()
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
    $grid.RowHeight=34
    $grid.HeadersVisibility='Column'; $grid.GridLinesVisibility='Horizontal'
    # Explicit columns also support PowerShell custom objects on .NET Framework.
    $grid.AutoGenerateColumns=$false
    [void]$Body.Children.Add($grid)
}
function Fill($items) {
    $data=@($items | Where-Object { $null -ne $_ })
    $grid.Columns.Clear()
    if ($data.Count) {
        foreach ($prop in $data[0].PSObject.Properties.Name) {
            if ($prop -in 'Stamp','Guid','Target') {continue}
            $col=New-Object Windows.Controls.DataGridTextColumn
            $col.Header=$prop; $col.Binding=New-Object Windows.Data.Binding($prop)
            [void]$grid.Columns.Add($col)
        }
    }
    $grid.ItemsSource=$data
    $Status.Text="Строк: $($data.Count)"
    if ($searchBox -and $searchBox.Text) {FilterTable}
}
function Run($code,$arguments,$done,$operation='') {
    if ($script:job) {return}
    $ps=[PowerShell]::Create()
    [void]$ps.AddScript($workerSource).AddStatement().AddScript($code)
    foreach ($argValue in $arguments) {[void]$ps.AddArgument($argValue)}
    $Status.Text='Выполняется…'
    $Nav.IsEnabled=$false; $Controls.IsEnabled=$false; $Body.IsEnabled=$false
    try {
        $script:job=@{ps=$ps;handle=$ps.BeginInvoke();done=$done;Cancellable=[bool]$operation;Operation=$operation;Started=[Diagnostics.Stopwatch]::StartNew()}
        if ($operation) {$cancelRead.IsEnabled=$true;$cancelRead.Visibility='Visible';$Status.Text=$operation}
    } catch {
        $ps.Dispose()
        $Nav.IsEnabled=$true; $Controls.IsEnabled=$true; $Body.IsEnabled=$true
        $Status.Text="Не удалось запустить запрос: $($_.Exception.GetBaseException().Message)"
    }
}
$timer=New-Object Windows.Threading.DispatcherTimer
$timer.Interval=[TimeSpan]::FromMilliseconds(200)
$timer.Add_Tick({
    if (!$job) {
        if ($win.IsVisible -and $win.IsActive -and $active -eq 'Обзор' -and [DateTime]::UtcNow -ge $nextRefresh) {Dashboard}
        return
    }
    if (!$job.handle.IsCompleted -or ($job.StopHandle -and !$job.StopHandle.IsCompleted)) {
        if ($job.Cancellable -and !$job.StopHandle) {$Status.Text="$($job.Operation) · $([int]$job.Started.Elapsed.TotalSeconds) с"}
        return
    }
    $cancelRead.Visibility='Collapsed'
    $finished=$job; $script:job=$null
    $Nav.IsEnabled=$true; $Controls.IsEnabled=$true; $Body.IsEnabled=$true
    try {
        if ($finished.StopHandle) {
            $finished.ps.EndStop($finished.StopHandle)
            $Status.Text='Проверка отменена'
            return
        }
        $response=@($finished.ps.EndInvoke($finished.handle))
        
        $Status.Text='Готово'
        & $finished.done $response
    } catch {$Status.Text="Ошибка: $($_.Exception.Message)"}
    finally {$finished.ps.Dispose()}
})
function AppDialog($title,$message,$initial,$accept) {
    $dialog=New-Object Windows.Window
    $dialog.Owner=$win;$dialog.Title=$title;$dialog.WindowStartupLocation='CenterOwner'
    $dialog.Width=470;$dialog.SizeToContent='Height';$dialog.ResizeMode='NoResize'
    $dialog.Resources.MergedDictionaries.Add($win.Resources)
    $dialog.Background=$win.Resources['Field'];$dialog.Foreground=$win.Resources['Ink']
    $dialog.Icon=$win.Icon;$dialog.FontFamily=$win.FontFamily
    $panel=New-Object Windows.Controls.StackPanel;$panel.Margin='22';$dialog.Content=$panel
    (Label $panel $title 20).FontWeight='SemiBold'
    [void](Label $panel $message 14)
    if ($null -ne $initial) {
        $box=New-Object Windows.Controls.TextBox;$box.Text=$initial;$box.Margin='0,8,0,4'
        [void]$panel.Children.Add($box)
        $problem=Label $panel '' 13
    }
    $buttons=New-Object Windows.Controls.WrapPanel;$buttons.Margin='0,12,0,0';$buttons.HorizontalAlignment='Right'
    [void]$panel.Children.Add($buttons)
    $no=Button $buttons 'Отмена' {$dialog.DialogResult=$false};$no.IsCancel=$true
    $yes=Button $buttons $accept {
        if ($null -ne $initial) {
            try {
                $path=Get-Item -LiteralPath $box.Text.Trim() -Force -ErrorAction Stop
                if ($path -isnot [IO.DirectoryInfo]) {throw 'folder'}
                $dialog.Tag=$path.FullName
            } catch {$problem.Text='Введите путь к существующей папке';return}
        }
        $dialog.DialogResult=$true
    }
    $yes.Background='#186D73';$yes.Foreground='White'
    if ($null -ne $initial) {$yes.IsDefault=$true}
    if ($dialog.ShowDialog()) {if ($null -ne $initial) {return $dialog.Tag};return $true}
    if ($null -eq $initial) {return $false}
}
function Confirm($text) {AppDialog 'Подтверждение' $text $null 'Продолжить'}
function ChooseFolder($title,$initial) {AppDialog $title 'Путь к папке' $initial 'Выбрать'}
function SearchTable {
    $r=Row
    [void](Label $r 'Поиск' 13)
    $script:searchBox=New-Object Windows.Controls.TextBox
    [Windows.Automation.AutomationProperties]::SetAutomationId($searchBox,'InventorySearch')
    $searchBox.Width=260;$searchBox.Margin='0,0,0,7'
    [void]$r.Children.Add($searchBox)
    $searchBox.Add_TextChanged({if ($grid.ItemsSource) {FilterTable}})
}
function FilterTable {
    $term=$searchBox.Text.Trim()
    $view=[Windows.Data.CollectionViewSource]::GetDefaultView($grid.ItemsSource)
    if (!$view -or !$view.CanFilter) {return}
    if (!$term) {$view.Filter=$null} else {
        $filter={param($row)
            foreach ($prop in $row.PSObject.Properties) {
                if ($prop.Name -ne 'Target' -and ([string]$prop.Value).IndexOf($term,[StringComparison]::OrdinalIgnoreCase) -ge 0) {return $true}
            }
            return $false
        }.GetNewClosure()
        $view.Filter=[Predicate[object]]$filter
    }
    $Status.Text="Строк: $($view.Count)"
}
function Dashboard {
    $script:nextRefresh=[DateTime]::MaxValue
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
            $card.SetResourceReference([Windows.Controls.Border]::BackgroundProperty,'Surface')
            $card.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty,'Edge')
            $card.BorderThickness='1'; $card.CornerRadius='12'; $card.Padding='14'; $card.Margin='0,0,8,16'
            $inside=New-Object Windows.Controls.StackPanel
            $card.Child=$inside; [void]$cards.Children.Add($card)
            (Label $inside $pair[0] 13).SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty,'Muted')
            (Label $inside $pair[1] 22).FontWeight='SemiBold'
        }
        [void](Label $stack $m.OS 20)
        [void](Label $stack "С момента загрузки: $($m.Uptime)" 14)
        $script:nextRefresh=[DateTime]::UtcNow.AddSeconds(5)
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
    Run 'param($r,$m) Scan $r $m' @($root,$mode) {param($rows) Fill $rows} 'Сканирование папки'
}
function Elevated($exe,$argsText) {
    Run 'param($exe,$a) $p=Start-Process -FilePath $exe -ArgumentList $a -Verb RunAs -PassThru -Wait; if($p.ExitCode -ne 0){throw "Код завершения: $($p.ExitCode)"}' @($exe,$argsText) {ActionResult 'Команда завершена, код 0'}
}
function ActionResult($result) {
    $Status.Text=$result
    if ($active -eq 'ИИ-помощник') {
        [void]$history.Add(@{role='user';content="Результат подтверждённого действия Windows: $result"})
        [void]$chatEntries.Add(@{Author='Windows';Text=$result})
        ShowConversation
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
function ResetChat {
    $script:chatSession=[guid]::NewGuid().ToString()
    $history.Clear()
    $chatEntries.Clear()
    $script:pending=''
    $script:snapshot=''
    $script:draft=''
    $apply.Visibility='Collapsed'
    $inputBox.Clear()
    $attachment.Content='Приложить сводку'
    ShowConversation
}
function ShowConversation {
    $thread.Children.Clear()
    if (!$chatEntries.Count) {
        $welcome=Label $thread 'Чем помочь с Windows?' 23
        $welcome.FontWeight='SemiBold'
        $suggestions=New-Object Windows.Controls.WrapPanel
        [void]$thread.Children.Add($suggestions)
        foreach ($prompt in @(
            @('Компьютер тормозит','Компьютер стал работать медленнее. Как определить причину?'),
            @('Пропадает интернет','Интернет периодически пропадает. Помоги проверить соединение по шагам.'),
            @('Мало места','Как выяснить, какие файлы занимают место, и что можно безопасно удалить?')
        )) {
            $b=Button $suggestions $prompt[0] {param($sender,$e)
                if ($inputBox.Text.Trim() -and !(Confirm 'Заменить черновик выбранным вопросом?')) {return}
                $inputBox.Text=$sender.Tag
                [void]$inputBox.Focus()
                $inputBox.CaretIndex=$inputBox.Text.Length
            }
            $b.Tag=$prompt[1]
        }
        return
    }
    foreach ($entry in $chatEntries) {
        $card=New-Object Windows.Controls.Border
        $card.CornerRadius='13';$card.Padding='14,8';$card.BorderThickness='1'
        $card.Margin=if ($entry.Author -eq 'Вы') {'48,4,0,6'} else {'0,4,30,6'}
        $surface=if ($entry.Author -eq 'Вы') {'Outgoing'} else {'Surface'}
        $card.SetResourceReference([Windows.Controls.Border]::BackgroundProperty,$surface)
        $card.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty,'Edge')
        $content=New-Object Windows.Controls.StackPanel
        $card.Child=$content
        $title=Label $content $entry.Author 12
        $title.FontWeight='SemiBold'
        $title.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty,'Muted')
        $text=New-Object Windows.Controls.TextBox
        $text.IsReadOnly=$true;$text.Background='Transparent';$text.BorderThickness='0'
        $text.Padding='0';$text.TextWrapping='Wrap';$text.FontSize=15;$text.Text=$entry.Text
        [void]$content.Children.Add($text)
        if ($entry.Author -eq 'Помощник' -and $entry.Text) {
            $copy=Button $content 'Копировать ответ' {param($sender,$e)
                [Windows.Clipboard]::SetText($sender.Tag)
                $Status.Text='Ответ скопирован'
            }
            $copy.Tag=$entry.Text;$copy.HorizontalAlignment='Left';$copy.Padding='7,3';$copy.Margin='0,8,0,0'
        }
        [void]$thread.Children.Add($card)
    }
    $scroll.ScrollToEnd()
}
function RememberChat {
    $nextEndpoint=$endpoint.Text.Trim()
    if ($nextEndpoint.TrimEnd('/') -ne $baseUrl.TrimEnd('/') -and $sessionKey -and $secret.Password -ceq $sessionKey) {
        $secret.Clear()
        $Status.Text='Адрес изменился. Введите ключ для нового API.'
    }
    $script:baseUrl=$nextEndpoint;$script:sessionKey=$secret.Password;$script:selectedModel=$model.Text.Trim()
    if ($script:conversationEndpoint -ne $baseUrl) {
        $keepDraft=$inputBox.Text
        ResetChat
        $inputBox.Text=$keepDraft
        $script:conversationEndpoint=$baseUrl
    }
    $script:draft=$inputBox.Text
}
function SendChat {
    RememberChat
    $question=$inputBox.Text.Trim()
    if (!$question -or !$selectedModel -or !$sessionKey) {$Status.Text='Введите API-ключ, модель и сообщение';return}
    $script:pending='';$apply.Visibility='Collapsed'
    $script:sent=$question
    $sys='Отвечай по-русски. Ты помощник по Windows. Для предложения действия добавь отдельной последней строкой ACTION: dns, ACTION: verify или ACTION: metrics. Доступны только эти действия после согласия пользователя. Не утверждай, что действие выполнено.'
    $messages=@(@{role='system';content=$sys}) + @($history) + @(@{role='user';content=$question})
    if ($snapshot) {$messages+=@{role='user';content="Сводка Windows: $snapshot"}}
    Run 'param($url,$key,$model,$msgs,$sid) Api $url $key $model $msgs $false $sid' @($baseUrl,$sessionKey,$selectedModel,$messages,$chatSession) {param($rows)
        $answer=[string]$rows[0]
        [void]$history.Add(@{role='user';content=$sent});[void]$history.Add(@{role='assistant';content=$answer})
        if ($answer -match '(?m)^ACTION: (dns|verify|metrics)\s*\z') {
            $script:pending=$Matches[1];$answer=$answer.Substring(0,$answer.LastIndexOf('ACTION:')).TrimEnd()
            $apply.Content=$approvedActions[$pending];$apply.Visibility='Visible'
        }
        [void]$chatEntries.Add(@{Author='Вы';Text=$sent})
        if ($snapshot) {[void]$chatEntries.Add(@{Author='Сводка Windows';Text=$snapshot})}
        [void]$chatEntries.Add(@{Author='Помощник';Text=$answer})
        $script:snapshot='';$attachment.Content='Приложить сводку'
        $inputBox.Clear();$script:draft=''
        ShowConversation
    }
}
function ExplainSelection {
    $entry=$grid.SelectedItem
    if (!$entry) {$Status.Text='Выберите строку для объяснения';return}
    $fields=foreach ($field in $entry.PSObject.Properties) {
        if ($field.Name -notin 'Target','Stamp','Guid','Команда') {"$($field.Name): $($field.Value)"}
    }
    $question="Объясни запись из раздела «$active» и предложи следующий шаг.`n"+($fields -join "`n")
    if ($draft -and !(Confirm 'Заменить текущий черновик вопросом о выбранной записи?')) {return}
    $script:draft=$question
    Page 'ИИ-помощник'
    $Status.Text='Проверьте текст перед отправкой'
}
function Page($name) {
    if ($script:active -eq 'ИИ-помощник') {RememberChat}
    $script:searchBox=$null
    $script:active=$name; $Heading.Text=$name
    $Controls.Children.Clear();$Body.Children.Clear();$Status.Text=''
    foreach ($entry in $navButtons.GetEnumerator()) {
        $entry.Value.Background=if ($entry.Key -eq $name){'#206A78'}else{'#1B374F'}
    }
    $r=Row
    if ($name -in 'Процессы','Автозагрузка','Устройства','Диски','Драйверы','Память') {
        [void](Button $r 'Объяснить' {ExplainSelection})
    }
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
            [void](Button $r 'Включить / отключить' {
                $entry=$grid.SelectedItem
                if (!$entry) {$Status.Text='Выберите запись автозагрузки';return}
                $verb=if ($entry.Target.Disabled) {'Включить'} else {'Отключить'}
                if (Confirm "$verb «$($entry.Название)» при входе в Windows?") {
                    Run 'param($row) SwitchStartup $row; Startup' @($entry) {param($rows) Fill $rows}
                }
            })
            [void](Button $r 'Параметры Windows' {Start-Process 'ms-settings:startupapps'})
            [void](Button $r 'Удалить из автозагрузки' {
                $entry=$grid.SelectedItem
                if (!$entry) {$Status.Text='Выберите запись автозагрузки';return}
                if ($entry.Target.Disabled) {$Status.Text='Для удаления сначала восстановите запись';return}
                $effect=if ($entry.Target.Folder) {'Элемент папки автозагрузки будет перемещён в корзину.'} else {'Будет удалена команда запуска из реестра.'}
                if (Confirm "Удалить «$($entry.Название)» из автозагрузки?`n$($entry.Пользователь) · $($entry.Источник)`n$effect") {
                    Run 'param($entry) RemoveStartup $entry; Startup' @($entry) {param($rows) Fill $rows; $Status.Text='Запись удалена из автозагрузки'}
                }
            })
            Table;Run 'Startup' @() {param($rows) Fill $rows}
        }
        'Устройства' {
            $Hint.Text='Подключённые устройства Plug and Play и состояние их драйверов'
            [void](Button $r 'Обновить' {Page 'Устройства'})
            Table;Run 'Devices' @() {param($rows) Fill $rows}
        }
        'Диски' {
            $Hint.Text='Разделы и свободное место. Выберите локальный том с буквой для проверки файловой системы.'
            [void](Button $r 'Разделы' {Page 'Диски'})
            [void](Button $r 'Накопители' {Run 'DriveHealth' @() {param($rows) Fill $rows}})
            [void](Button $r 'Проверить том' {
                $letter=$grid.SelectedItem.Том
                if (!$letter) {$Status.Text='Выберите том с буквой в списке разделов';return}
                if (Confirm "Проверить файловую систему $letter в режиме чтения? Windows запросит права администратора. Отчёт появится в окне CHKDSK.") {
                    Run 'param($volume) CheckDisk $volume' @($letter) {param($rows) $Status.Text=$rows[0]}
                }
            })
            Table;Run 'DiskPartitions' @() {param($rows) Fill $rows}
        }
        'Драйверы' {
            $Hint.Text='Версии, поставщики и подписи установленных драйверов.'
            [void](Button $r 'Обновить список' {Page 'Драйверы'})
            [void](Button $r 'Экспорт INF' {
                $inf=$grid.SelectedItem.INF
                if ($inf -notmatch '^oem[0-9]+\.inf$') {$Status.Text='Для экспорта выберите сторонний пакет oem*.inf';return}
                $folder=ChooseFolder 'Папка для копии драйвера' ([Environment]::GetFolderPath('MyDocuments'))
                if ($folder) {
                    Run 'param($inf,$dest) if($inf -notmatch "^oem[0-9]+\.inf$"){throw "Недопустимое имя INF"}; $out=& "$env:SystemRoot\System32\pnputil.exe" /export-driver $inf $dest; if($LASTEXITCODE){throw ($out -join " ")}' @($inf,$folder) {$Status.Text='Пакет драйвера экспортирован'}
                }
            })
            [void](Button $r 'Windows Update' {Start-Process 'ms-settings:windowsupdate'})
            SearchTable
            Table;Run 'DriverList' @() {param($rows) Fill $rows}
        }
        'Программы' {
            $Hint.Text='Установленные классические приложения. Найдите программу по названию или издателю.'
            [void](Button $r 'Обновить' {Page 'Программы'})
            [void](Button $r 'Удалить…' {
                $row=$grid.SelectedItem
                if (!$row) {$Status.Text='Выберите программу';return}
                $product=$row.Target.Product
                if ($product -match '^\{[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}\}$') {
                    if (Confirm "Открыть мастер удаления «$($row.Название)»?") {
                        Run 'param($id) $p=Start-Process "$env:SystemRoot\System32\msiexec.exe" -ArgumentList "/x $id" -PassThru -Wait; if ($p.ExitCode -notin 0,3010,1602){throw "Код Windows Installer: $($p.ExitCode)"}; InstalledApps | Sort-Object Название' @($product) {param($rows) Fill $rows}
                    }
                } elseif (Confirm "Открыть установленные приложения Windows для удаления «$($row.Название)»? Выберите программу в системном списке.") {
                    Start-Process 'ms-settings:appsfeatures'
                }
            })
            [void](Button $r 'Все приложения Windows' {Start-Process 'ms-settings:appsfeatures'})
            SearchTable
            Table;Run 'InstalledApps | Sort-Object Название' @() {param($rows) Fill $rows}
        }
        'Память' {
            $Hint.Text='Физическая память, кэш и выделение виртуальной памяти — по данным Windows.'
            [void](Button $r 'Использование' {Page 'Память'})
            [void](Button $r 'Модули ОЗУ' {Run 'MemoryModules' @() {param($rows) Fill $rows}})
            [void](Button $r 'Проверка ОЗУ…' {
                if (Confirm 'Открыть диагностику памяти Windows? В системном окне можно выбрать проверку при следующем запуске.') {Start-Process "$env:SystemRoot\System32\mdsched.exe"}
            })
            Table;Run 'MemoryOverview' @() {param($rows) Fill $rows}
        }
        'Файлы' {
            $Hint.Text='Выберите папку и режим поиска. Дубли сравниваются по содержимому. Недоступные папки и ссылки пропускаются.'
            [void](Button $r 'Выбрать папку' {
                $folder=ChooseFolder 'Выберите папку' $root
                if ($folder) {$script:root=$folder;$script:mode='size';Page 'Файлы'}
            })
            foreach ($choice in @(@('По папкам','folders'),@('Размеры','size'),@('Дубли','dup'),@('Пустые','empty'),@('TEMP','temp'))) {
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
                if (!$selected -or $scanMode -in 'size','folders') {$Status.Text='Выберите строку в результатах поиска дублей, пустышек или TEMP';return}
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
            [void](Button $r 'Проверить соединение' {
                Run 'NetworkChecks' @() {param($rows) Fill $rows} 'Проверяем шлюз, DNS и HTTPS'
            })
            [void](Button $r 'Очистить DNS' {Action 'dns'})
            [void](Button $r 'Перезапустить адаптер' {
                $item=$grid.SelectedItem
                if (!$item.Guid) {$Status.Text='Нажмите «Измерить» и выберите сетевой адаптер';return}
                if (Confirm "Перезапустить адаптер $($item.Адаптер)? Соединение временно прервётся.") {
                    $guid=([guid]$item.Guid).ToString()
                    $command="`$ErrorActionPreference='Stop'; `$n=Get-NetAdapter | Where-Object { `$_.InterfaceGuid -eq [guid]'$guid' }; if (!`$n) {throw 'Adapter unavailable'}; `$n | Restart-NetAdapter -Confirm:`$false -ErrorAction Stop"
                    Elevated "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" ("-NoProfile -EncodedCommand "+[Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command)))
                }
            })
            Table;Run 'Network' @() {param($rows) Fill $rows}
        }
        'Диагностика' {
            $Hint.Text='Измерьте нагрузку процессора, диска и памяти или проверьте целостность системных файлов Windows.'
            [void](Button $r 'Почему тормозит ПК?' {
                Run 'LoadSample' @() {param($rows) Fill $rows; $Status.Text='Измерение завершено. Для подробностей откройте раздел «Процессы».'} 'Измеряем нагрузку около 30 секунд'
            })
            Table
            [void](Button $r 'Проверить систему' {Action 'verify'})
            [void](Button $r 'Открыть журнал CBS' {
                try {Start-Process "$env:SystemRoot\System32\notepad.exe" -ArgumentList ('"'+$env:SystemRoot+'\Logs\CBS\CBS.log"')} catch {$Status.Text=$_.Exception.Message}
            })
        }
        'ИИ-помощник' {
            $Hint.Text='Обсудите проблему и выберите следующий шаг.'
            $settings=New-Object Windows.Controls.Expander
            $settings.Header='Подключение и модель';$settings.Margin='0,0,0,8'
            $settings.SetResourceReference([Windows.Controls.Control]::ForegroundProperty,'Ink')
            $settings.IsExpanded=!($sessionKey -and $selectedModel)
            [void]$Controls.Children.Add($settings)
            $fields=New-Object Windows.Controls.StackPanel;$settings.Content=$fields
            $r=New-Object Windows.Controls.WrapPanel;[void]$fields.Children.Add($r)
            [void](Label $r 'Адрес API' 13)
            $script:endpoint=New-Object Windows.Controls.TextBox;$endpoint.Width=245;$endpoint.Text=$baseUrl;[void]$r.Children.Add($endpoint)
            [void](Label $r ' API-ключ' 13)
            $script:secret=New-Object Windows.Controls.PasswordBox;$secret.Width=155;$secret.Password=$sessionKey;[void]$r.Children.Add($secret)
            $r=New-Object Windows.Controls.WrapPanel;[void]$fields.Children.Add($r)
            [void](Label $r 'Модель' 13)
            $script:model=New-Object Windows.Controls.ComboBox;$model.IsEditable=$true;$model.Width=205;$model.Text=$selectedModel;[void]$r.Children.Add($model)
            [void](Button $r 'Загрузить модели' {
                RememberChat
                if (!$sessionKey) {$Status.Text='Введите API-ключ';return}
                Run 'param($url,$key,$sid) Api $url $key $null $null $true $sid' @($baseUrl,$sessionKey,$chatSession) {param($rows)
                    $model.ItemsSource=@($rows);if ($rows.Count) {$model.SelectedIndex=0}
                    $Status.Text="Моделей: $($rows.Count)"
                }
            })
            $dock=New-Object Windows.Controls.DockPanel;[void]$Body.Children.Add($dock)
            $bottom=New-Object Windows.Controls.StackPanel;[Windows.Controls.DockPanel]::SetDock($bottom,'Bottom');[void]$dock.Children.Add($bottom)
            $script:inputBox=New-Object Windows.Controls.TextBox;$inputBox.Height=58;$inputBox.Margin='0,8,0,6';$inputBox.TextWrapping='Wrap';$inputBox.AcceptsReturn=$true;$inputBox.Text=$draft;$inputBox.VerticalScrollBarVisibility='Auto'
            $inputBox.ToolTip='Ctrl+Enter — отправить';[void]$bottom.Children.Add($inputBox)
            $inputBox.Add_PreviewKeyDown({param($sender,$e)
                if ($e.Key -eq 'Return' -and [Windows.Input.Keyboard]::Modifiers -eq 'Control') {$e.Handled=$true;SendChat}
            })
            $bar=New-Object Windows.Controls.WrapPanel;[void]$bottom.Children.Add($bar)
            $send=Button $bar 'Отправить' {SendChat}
            $send.Background='#176A70';$send.Foreground='White'
            $script:attachment=Button $bar 'Приложить сводку' {
                if ($snapshot) {
                    $script:snapshot='';$attachment.Content='Приложить сводку';return
                }
                Run 'Metrics | ConvertTo-Json' @() {param($rows)
                    $preview=[string]$rows[0]
                    if (Confirm "Добавить эту сводку к следующему сообщению?`n`n$preview") {
                        $script:snapshot=$preview;$attachment.Content='Убрать сводку'
                    }
                }
            }
            if ($snapshot) {$attachment.Content='Убрать сводку'}
            [void](Button $bar 'Новый чат' {
                if (($chatEntries.Count -or $inputBox.Text -or $snapshot) -and !(Confirm 'Очистить переписку и начать новый чат?')) {return}
                ResetChat
            })
            $script:apply=Button $bar 'Выполнить' {Action $pending}
            if ($pending) {$apply.Content=$approvedActions[$pending]} else {$apply.Visibility='Collapsed'}
            $script:scroll=New-Object Windows.Controls.ScrollViewer
            $scroll.VerticalScrollBarVisibility='Auto';$scroll.HorizontalScrollBarVisibility='Disabled'
            $script:thread=New-Object Windows.Controls.StackPanel;$scroll.Content=$thread
            [void]$dock.Children.Add($scroll)
            ShowConversation
        }
    }
}
$glyphs=@('E80F','E950','E7E8','E772','E950','ECAA','EDA2','E8B7','E950','E774','E9D9','E8F2')
foreach ($section in $pages) {
    $b=Button $Nav $section {param($sender,$e) Page $sender.Tag}
    $b.Tag=$section
    $line=New-Object Windows.Controls.StackPanel;$line.Orientation='Horizontal'
    $mark=New-Object Windows.Controls.TextBlock;$mark.FontFamily='Segoe MDL2 Assets';$mark.VerticalAlignment='Center'
    $mark.Text=[char][Convert]::ToInt32($glyphs[[Array]::IndexOf($pages,$section)],16);$mark.Margin='0,0,10,0'
    [void]$line.Children.Add($mark)
    $caption=New-Object Windows.Controls.TextBlock;$caption.Text=$section;[void]$line.Children.Add($caption)
    $b.Content=$line
    [Windows.Automation.AutomationProperties]::SetName($b,$section)
    [Windows.Automation.AutomationProperties]::SetAutomationId($b,"Nav-$section")
    $b.Padding='12,7';$b.Margin='0,0,4,4';$b.HorizontalContentAlignment='Left';$b.Foreground='White';$navButtons[$section]=$b
}
$win.Add_Closed({
    $timer.Stop()
    foreach ($p in $paused.Values) {try {if (!$p.HasExited) {[void][PauseControl]::NtResumeProcess($p.Handle)}} finally {$p.Dispose()}}
})
$win.Dispatcher.Add_UnhandledException({
    param($sender,$eventArgs)
    $eventArgs.Handled=$true
    $Status.Text="Ошибка интерфейса: $($eventArgs.Exception.GetBaseException().Message)"
})
$timer.Start()
Page 'Обзор'
[void]$win.ShowDialog()
