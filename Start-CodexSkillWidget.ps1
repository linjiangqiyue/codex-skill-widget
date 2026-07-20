param(
    [string]$CodexHome = (Join-Path $env:USERPROFILE '.codex'),
    [switch]$ValidateOnly,
    [switch]$QaMode,
    [string]$CapturePath,
    [ValidateSet('托管任务','产品判断','UI 检查','Skills')][string]$CaptureMode,
    [ValidateSet('小','标准','大')][string]$CaptureSize,
    [string]$CaptureQuery
)

$ErrorActionPreference = 'Stop'
if ([Threading.Thread]::CurrentThread.GetApartmentState() -ne 'STA') {
    $arguments = @('-NoProfile','-ExecutionPolicy','Bypass','-STA','-File',('"{0}"' -f $PSCommandPath),'-CodexHome',('"{0}"' -f $CodexHome))
    if ($ValidateOnly) { $arguments += '-ValidateOnly' }
    if ($QaMode) { $arguments += '-QaMode' }
    if ($CapturePath) { $arguments += @('-CapturePath',('"{0}"' -f $CapturePath)) }
    if ($CaptureMode) { $arguments += @('-CaptureMode',('"{0}"' -f $CaptureMode)) }
    if ($CaptureSize) { $arguments += @('-CaptureSize',('"{0}"' -f $CaptureSize)) }
    if ($CaptureQuery) { $arguments += @('-CaptureQuery',('"{0}"' -f $CaptureQuery)) }
    Start-Process powershell.exe -ArgumentList ($arguments -join ' ')
    return
}

Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms
Add-Type -TypeDefinition 'using System; using System.Runtime.InteropServices; public static class WidgetConsole { [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow(); [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int n); }' -ErrorAction SilentlyContinue

$modulePath = Join-Path $PSScriptRoot 'src\SkillCatalog.psm1'
Import-Module $modulePath -Force
$usageAdapterPath = Join-Path $PSScriptRoot 'src\UsageAdapter.psm1'
Import-Module $usageAdapterPath -Force
$githubSyncPath = Join-Path $PSScriptRoot 'src\GitHubSkillSync.psm1'
Import-Module $githubSyncPath -Force
$script:catalog = @(Get-CodexSkillCatalog -CodexHome $CodexHome)
$historyPath = Join-Path $PSScriptRoot 'query-history.json'
$quarantineRoot = Join-Path $PSScriptRoot 'github-quarantine'
$settingsPath = Join-Path $PSScriptRoot 'settings.json'
$settings = if (Test-Path -LiteralPath $settingsPath) {
    try { Get-Content -LiteralPath $settingsPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch { [pscustomobject]@{} }
} else { [pscustomobject]@{} }

if ($ValidateOnly) {
    $sample = @(Find-CodexSkills -Catalog $script:catalog -Query '按照原型修改网页并测试' -Top 6)
    [pscustomobject]@{ Status='OK'; SkillCount=$script:catalog.Count; SampleRecommendations=@($sample.Name) } | ConvertTo-Json -Depth 4
    return
}

$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Width="420" Height="520" MinWidth="340" MaxWidth="520" MinHeight="194" MaxHeight="700"
        Title="Codex Skill 助手" WindowStyle="None" ResizeMode="NoResize"
        AllowsTransparency="True" Background="Transparent" Topmost="True" ShowInTaskbar="False"
        FontFamily="Microsoft YaHei UI, Segoe UI">
    <Window.Resources>
        <SolidColorBrush x:Key="TextPrimary" Color="#F4F4F4"/>
        <SolidColorBrush x:Key="TextSecondary" Color="#AAA8AB"/>
        <Style x:Key="IconButton" TargetType="Button">
            <Setter Property="Width" Value="30"/><Setter Property="Height" Value="30"/>
            <Setter Property="Background" Value="Transparent"/><Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Foreground" Value="#D8D7D9"/><Setter Property="FontFamily" Value="Segoe MDL2 Assets"/>
            <Setter Property="FontSize" Value="14"/><Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button">
                <Border x:Name="Bg" Background="{TemplateBinding Background}" CornerRadius="8"><ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></Border>
                <ControlTemplate.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Bg" Property="Background" Value="#20FFFFFF"/></Trigger></ControlTemplate.Triggers>
            </ControlTemplate></Setter.Value></Setter>
        </Style>
        <Style x:Key="PrimaryButton" TargetType="Button">
            <Setter Property="Background" Value="#261D1C1F"/><Setter Property="Foreground" Value="#F4F4F4"/>
            <Setter Property="BorderBrush" Value="#80FFFFFF"/><Setter Property="BorderThickness" Value="1"/><Setter Property="Padding" Value="14,8"/>
            <Setter Property="FontWeight" Value="SemiBold"/><Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button">
                <Border x:Name="Bg" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="8"><ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></Border>
                <ControlTemplate.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Bg" Property="Background" Value="#35FFFFFF"/><Setter TargetName="Bg" Property="BorderBrush" Value="#C0FFFFFF"/></Trigger></ControlTemplate.Triggers>
            </ControlTemplate></Setter.Value></Setter>
        </Style>
        <Style x:Key="ModeButton" TargetType="RadioButton">
            <Setter Property="Foreground" Value="#AAA8AB"/><Setter Property="FontSize" Value="11"/><Setter Property="Cursor" Value="Hand"/>
            <Setter Property="HorizontalContentAlignment" Value="Center"/><Setter Property="VerticalContentAlignment" Value="Center"/>
            <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
            <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="RadioButton">
                <Border x:Name="ModeBg" Margin="2" Padding="5,4" Background="Transparent" BorderBrush="Transparent" BorderThickness="1" CornerRadius="7">
                    <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                </Border>
                <ControlTemplate.Triggers>
                    <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="ModeBg" Property="Background" Value="#18FFFFFF"/></Trigger>
                    <Trigger Property="IsChecked" Value="True"><Setter TargetName="ModeBg" Property="Background" Value="#161D1C1F"/><Setter TargetName="ModeBg" Property="BorderBrush" Value="#9AFFFFFF"/><Setter Property="Foreground" Value="#F5F5F5"/><Setter Property="FontWeight" Value="SemiBold"/></Trigger>
                    <Trigger Property="IsKeyboardFocused" Value="True"><Setter TargetName="ModeBg" Property="BorderBrush" Value="#80FFFFFF"/><Setter TargetName="ModeBg" Property="BorderThickness" Value="1"/></Trigger>
                </ControlTemplate.Triggers>
            </ControlTemplate></Setter.Value></Setter>
        </Style>
    </Window.Resources>
    <Border x:Name="Shell" Background="#EA161517" BorderBrush="#42FFFFFF" BorderThickness="1" CornerRadius="14">
        <Grid Margin="14,10,14,14">
            <Grid.RowDefinitions><RowDefinition Height="32"/><RowDefinition Height="46"/><RowDefinition Height="38"/><RowDefinition Height="50"/><RowDefinition Height="*"/><RowDefinition Height="42"/></Grid.RowDefinitions>
            <Grid Grid.Row="0">
                <Grid.ColumnDefinitions><ColumnDefinition Width="32"/><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/><ColumnDefinition Width="Auto"/><ColumnDefinition Width="Auto"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                <TextBlock Grid.Column="0" Text="&#xE8B7;" FontFamily="Segoe MDL2 Assets" FontSize="19" Foreground="#ECEBED" VerticalAlignment="Center"/>
                <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center">
                    <TextBlock Text="Codex 助手" Foreground="{StaticResource TextPrimary}" FontSize="16" FontWeight="SemiBold"/>
                    <TextBlock x:Name="CountText" Margin="8,2,0,0" Foreground="{StaticResource TextSecondary}" FontSize="11"/>
                </StackPanel>
                <Button x:Name="SizeButton" Grid.Column="2" Style="{StaticResource IconButton}" FontFamily="Microsoft YaHei UI" Content="中" ToolTip="切换小、中、大尺寸"/>
                <Button x:Name="PinButton" Grid.Column="3" Style="{StaticResource IconButton}" Content="&#xE718;" ToolTip="置顶"/>
                <Button x:Name="CollapseButton" Grid.Column="4" Style="{StaticResource IconButton}" Content="&#xE921;" ToolTip="收起"/>
                <Button x:Name="CloseButton" Grid.Column="5" Style="{StaticResource IconButton}" Content="&#xE8BB;" ToolTip="关闭"/>
            </Grid>
            <Border x:Name="UsageCard" Grid.Row="1" Margin="0,4,0,3" Background="#441C1B1D" CornerRadius="10" BorderBrush="#48FFFFFF" BorderThickness="1" Cursor="Hand">
                <Grid Margin="11,0,7,0">
                    <Grid.ColumnDefinitions><ColumnDefinition Width="28"/><ColumnDefinition Width="Auto"/><ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/><ColumnDefinition Width="30"/></Grid.ColumnDefinitions>
                    <Canvas Width="22" Height="22" VerticalAlignment="Center">
                        <Ellipse Width="18" Height="18" Canvas.Left="2" Canvas.Top="2" Stroke="#4DFFFFFF" StrokeThickness="2"/>
                        <Path x:Name="UsageRing" Stroke="#74C69D" StrokeThickness="2.5" StrokeStartLineCap="Round" StrokeEndLineCap="Round"/>
                        <Ellipse Width="4" Height="4" Canvas.Left="9" Canvas.Top="9" Fill="#F1EEE8"/>
                    </Canvas>
                    <TextBlock Grid.Column="1" Text="剩余额度" Foreground="#D0CED1" FontSize="12" VerticalAlignment="Center"/>
                    <TextBlock x:Name="UsagePercent" Grid.Column="2" Text="--%" Margin="8,0,0,0" Foreground="#72CFA4" FontSize="15" FontWeight="SemiBold" VerticalAlignment="Center"/>
                    <TextBlock x:Name="UsageReset" Grid.Column="3" Margin="10,1,0,0" Foreground="#858287" FontSize="10" VerticalAlignment="Center" TextTrimming="CharacterEllipsis"/>
                    <Button x:Name="UsageRefreshButton" Grid.Column="4" Style="{StaticResource IconButton}" Content="&#xE72C;" ToolTip="刷新额度"/>
                </Grid>
            </Border>
            <Border x:Name="ModeBar" Grid.Row="2" Margin="0,3,0,3" Background="#F019181A" CornerRadius="8" BorderBrush="#48FFFFFF" BorderThickness="1">
                <UniformGrid Columns="4" Margin="2">
                    <RadioButton x:Name="ModeManaged" GroupName="WorkMode" Style="{StaticResource ModeButton}" Content="托管任务" Tag="托管任务" ToolTip="把口语需求整理成可执行、可验收的任务" IsChecked="True"/>
                    <RadioButton x:Name="ModeProduct" GroupName="WorkMode" Style="{StaticResource ModeButton}" Content="产品判断" Tag="产品判断" ToolTip="指出具体产品问题，拒绝笼统奉承"/>
                    <RadioButton x:Name="ModeUI" GroupName="WorkMode" Style="{StaticResource ModeButton}" Content="UI 检查" Tag="UI 检查" ToolTip="把肉眼问题转换成专业修复要求"/>
                    <RadioButton x:Name="ModeSkills" GroupName="WorkMode" Style="{StaticResource ModeButton}" Content="能力库" Tag="Skills" ToolTip="查看和补充任务所需能力"/>
                </UniformGrid>
            </Border>
            <Border Grid.Row="3" Margin="0,4,0,4" Background="#521E1D20" CornerRadius="10" BorderBrush="#50FFFFFF" BorderThickness="1">
                <Grid Margin="14,0,8,0"><Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="34"/></Grid.ColumnDefinitions>
                    <Grid>
                        <TextBox x:Name="QueryBox" Background="Transparent" BorderThickness="0" Foreground="#F3F2F4" FontSize="15" VerticalContentAlignment="Center" CaretBrush="#F3F2F4"/>
                        <TextBlock x:Name="Placeholder" Text="用中文描述你想做什么…" Foreground="#858287" FontSize="15" VerticalAlignment="Center" IsHitTestVisible="False"/>
                    </Grid>
                    <Button x:Name="SearchButton" Grid.Column="1" Style="{StaticResource IconButton}" Content="&#xE721;" ToolTip="推荐 skills"/>
                </Grid>
            </Border>
            <Grid x:Name="ExpandedArea" Grid.Row="4" Margin="0,8,0,0" Background="#F019181A">
                <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
                <TextBlock x:Name="HintText" Text="推荐组合" Foreground="#E1DFE2" FontWeight="SemiBold" Margin="2,0,0,8"/>
                <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto"><StackPanel x:Name="ResultsPanel"/></ScrollViewer>
            </Grid>
            <Grid x:Name="Footer" Grid.Row="5" Margin="2,8,2,0">
                <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="32"/><ColumnDefinition Width="112"/></Grid.ColumnDefinitions>
                <TextBlock x:Name="StatusText" Margin="0,0,10,0" Foreground="#98959A" FontSize="11" VerticalAlignment="Center" TextTrimming="CharacterEllipsis"/>
                <Button x:Name="GitHubSyncButton" Grid.Column="1" Style="{StaticResource IconButton}" Content="&#xE72C;" ToolTip="立即从 GitHub 补充 skills"/>
                <Button x:Name="CopyButton" Grid.Column="2" Height="34" Style="{StaticResource PrimaryButton}" Content="复制提示词"/>
            </Grid>
        </Grid>
    </Border>
</Window>
'@

if ($QaMode) {
    $xaml = $xaml.Replace('AllowsTransparency="True" Background="Transparent"', 'AllowsTransparency="False" Background="#1F1C18"')
}

[xml]$xml = $xaml
$reader = New-Object System.Xml.XmlNodeReader $xml
$window = [Windows.Markup.XamlReader]::Load($reader)
if ($QaMode) { $window.ShowInTaskbar = $true }
if (-not $QaMode -and -not $CapturePath) {$window.Add_Loaded({$consoleHandle=[WidgetConsole]::GetConsoleWindow();if($consoleHandle -ne [IntPtr]::Zero){[WidgetConsole]::ShowWindow($consoleHandle,0)|Out-Null}})}
$shell = $window.FindName('Shell'); $queryBox = $window.FindName('QueryBox'); $placeholder = $window.FindName('Placeholder')
$resultsPanel = $window.FindName('ResultsPanel'); $countText = $window.FindName('CountText'); $statusText = $window.FindName('StatusText')
$hintText = $window.FindName('HintText'); $expandedArea = $window.FindName('ExpandedArea'); $footer = $window.FindName('Footer')
$usageCard = $window.FindName('UsageCard'); $usageRing = $window.FindName('UsageRing'); $usagePercent = $window.FindName('UsagePercent')
$usageReset = $window.FindName('UsageReset'); $usageRefreshButton = $window.FindName('UsageRefreshButton')
$sizeButton=$window.FindName('SizeButton');$pinButton = $window.FindName('PinButton'); $collapseButton = $window.FindName('CollapseButton'); $closeButton = $window.FindName('CloseButton')
$searchButton = $window.FindName('SearchButton'); $copyButton = $window.FindName('CopyButton'); $githubSyncButton = $window.FindName('GitHubSyncButton')
$modeButtons=@('ModeManaged','ModeProduct','ModeUI','ModeSkills') | ForEach-Object {$window.FindName($_)}
$countText.Text = ('{0} 个可用' -f $script:catalog.Count)
$script:currentSkills = @(); $script:isCollapsed = $false; $script:expandedHeight = 520
$script:sizeMode=if($settings.PSObject.Properties['SizeMode']){[string]$settings.SizeMode}else{'标准'}
$script:workMode = if($settings.PSObject.Properties['WorkMode']){[string]$settings.WorkMode}else{'托管任务'}
$selectedModeButton=$modeButtons | Where-Object {$_.Tag -eq $script:workMode} | Select-Object -First 1
if($selectedModeButton){$selectedModeButton.IsChecked=$true}else{$script:workMode='托管任务';$modeButtons[0].IsChecked=$true}
$script:githubJob = $null; $script:lastGitHubSync = [datetime]::MinValue
if ($settings.PSObject.Properties['Topmost']) { $window.Topmost = [bool]$settings.Topmost }

function New-ResultCard([object]$skill, [int]$index) {
    $card = New-Object System.Windows.Controls.Border
    $card.Background = [Windows.Media.Brushes]::Transparent
    $card.BorderBrush = (New-Object Windows.Media.BrushConverter).ConvertFromString('#30FFFFFF')
    $card.BorderThickness = '0,0,0,1'; $card.Padding = '8,8'; $card.Tag = $skill
    $grid = New-Object System.Windows.Controls.Grid
    $grid.ColumnDefinitions.Add((New-Object Windows.Controls.ColumnDefinition -Property @{Width='28'}))
    $grid.ColumnDefinitions.Add((New-Object Windows.Controls.ColumnDefinition -Property @{Width='*'}))
    $number = New-Object Windows.Controls.TextBlock -Property @{Text=('{0:00}' -f ($index+1));Foreground=(New-Object Windows.Media.BrushConverter).ConvertFromString('#858287');FontSize=11;VerticalAlignment='Top';Margin='0,2,0,0'}
    $stack = New-Object Windows.Controls.StackPanel; [Windows.Controls.Grid]::SetColumn($stack,1)
    $title = New-Object Windows.Controls.TextBlock -Property @{Text=$skill.Name;Foreground=(New-Object Windows.Media.BrushConverter).ConvertFromString('#F3F2F4');FontSize=13;FontWeight='SemiBold';ToolTip=$skill.Description}
    $summary = if ($skill.PSObject.Properties['ChineseSummary'] -and $skill.ChineseSummary) { $skill.ChineseSummary } else { '通用辅助能力' }
    $desc = New-Object Windows.Controls.TextBlock -Property @{Text=('用途：'+$summary);Foreground=(New-Object Windows.Media.BrushConverter).ConvertFromString('#A09DA2');FontSize=10;TextWrapping='Wrap';Margin='0,3,0,0';ToolTip=$skill.Description}
    $stack.Children.Add($title)|Out-Null; $stack.Children.Add($desc)|Out-Null
    $grid.Children.Add($number)|Out-Null; $grid.Children.Add($stack)|Out-Null; $card.Child=$grid
    $card.Add_MouseEnter({$this.Background=(New-Object Windows.Media.BrushConverter).ConvertFromString('#12FFFFFF')})
    $card.Add_MouseLeave({$this.Background=[Windows.Media.Brushes]::Transparent})
    return $card
}

function New-UsageRingGeometry([double]$percent) {
    $value=[Math]::Max(0,[Math]::Min(100,$percent))/100.0
    if($value -le 0){return [Windows.Media.Geometry]::Empty}
    $radius=8.5;$center=11.0;$start=-90.0;$finish=$start+(359.8*$value)
    $sr=$start*[Math]::PI/180;$fr=$finish*[Math]::PI/180
    $figure=New-Object Windows.Media.PathFigure
    $figure.StartPoint=New-Object Windows.Point(($center+$radius*[Math]::Cos($sr)),($center+$radius*[Math]::Sin($sr)))
    $arc=New-Object Windows.Media.ArcSegment
    $arc.Point=New-Object Windows.Point(($center+$radius*[Math]::Cos($fr)),($center+$radius*[Math]::Sin($fr)))
    $arc.Size=New-Object Windows.Size($radius,$radius);$arc.SweepDirection='Clockwise';$arc.IsLargeArc=$value -gt .5
    $figure.Segments.Add($arc)|Out-Null;$geometry=New-Object Windows.Media.PathGeometry;$geometry.Figures.Add($figure)|Out-Null
    $geometry
}

function Format-ResetCountdown([datetime]$resetAt) {
    $left=$resetAt-[datetime]::Now
    if($left.TotalMinutes -le 1){return '即将重置'}
    if($left.TotalDays -ge 1){return ('约 {0}天{1}小时后重置' -f [Math]::Floor($left.TotalDays),$left.Hours)}
    if($left.TotalHours -ge 1){return ('约 {0}小时{1}分后重置' -f [Math]::Floor($left.TotalHours),$left.Minutes)}
    return ('约 {0}分钟后重置' -f [Math]::Ceiling($left.TotalMinutes))
}

function Update-UsageDisplay {
    $usage = Get-WidgetUsageSnapshot -CodexHome $CodexHome
    $usagePercent.Text = if($usage.Status -eq 'Unlimited'){'无限'}else{$usage.PrimaryText}
    $usageRing.Data = if($null -ne $usage.RemainingPercent){New-UsageRingGeometry ([double]$usage.RemainingPercent)}else{[Windows.Media.Geometry]::Empty}
    $color = if($usage.Status -ne 'Ok' -and $usage.Status -ne 'Unlimited'){'#D98B7B'}elseif([double]$usage.RemainingPercent -le 10){'#E57373'}elseif([double]$usage.RemainingPercent -le 25){'#E9B872'}else{'#74C69D'}
    $brush=(New-Object Windows.Media.BrushConverter).ConvertFromString($color);$usagePercent.Foreground=$brush;$usageRing.Stroke=$brush
    if($usage.Status -eq 'Unavailable'){$usageReset.Text='额度暂不可用';$usageCard.ToolTip=$usage.Message}
    elseif($null -ne $usage.ResetAtLocal){$usageReset.Text=Format-ResetCountdown ([datetime]$usage.ResetAtLocal);$usageCard.ToolTip=('准确时间：{0:MM-dd HH:mm}，点击刷新' -f [datetime]$usage.ResetAtLocal)}
    else{$usageReset.Text='';$usageCard.ToolTip='点击刷新额度'}
}

function Update-Recommendations {
    $task = $queryBox.Text.Trim()
    $frequent = @(Get-FrequentQueryTerms -HistoryPath $historyPath -Top 4 | ForEach-Object Term)
    $enrichedTask = (@($task) + $frequent -join ' ')
    if ($script:workMode -eq 'Skills') {
        $script:currentSkills = if ([string]::IsNullOrWhiteSpace($task)) {
            @($script:catalog | Sort-Object Category,Name)
        } else {
            @(Find-CodexSkills -Catalog $script:catalog -Query $enrichedTask -Mode $script:workMode -Top 100)
        }
    } else {
        $script:currentSkills = @(Find-CodexSkills -Catalog $script:catalog -Query $enrichedTask -Mode $script:workMode -Top 6)
    }
    $resultsPanel.Children.Clear()
    for ($i=0; $i -lt $script:currentSkills.Count; $i++) { $resultsPanel.Children.Add((New-ResultCard $script:currentSkills[$i] $i))|Out-Null }
    if ($script:workMode -eq 'Skills') {
        $hintText.Text = if ($task) { "找到 $($script:currentSkills.Count) 项能力" } else { "全部 $($script:catalog.Count) 项能力" }
        $statusText.Text = if ($script:currentSkills.Count) { "可滚动浏览全部 $($script:catalog.Count) 个" } else { '没有匹配项，请换一种中文描述' }
    } else {
        $hintText.Text = "$($script:workMode) · 推荐顺序"
        $statusText.Text = if ($script:currentSkills.Count) { "从 $($script:catalog.Count) 个中推荐 $($script:currentSkills.Count) 个" } else { '没有匹配项，请换一种中文描述' }
    }
}

function Set-WidgetSize([string]$mode) {
    $workArea=[Windows.SystemParameters]::WorkArea
    $target=switch($mode){'小'{@{W=360;H=420}}'大'{@{W=500;H=620}}default{@{W=420;H=520}}}
    $script:sizeMode=$mode
    $window.Width=[Math]::Max(340,[Math]::Min($target.W,$workArea.Width-24))
    if(-not $script:isCollapsed){
        $window.Height=[Math]::Max(360,[Math]::Min($target.H,$workArea.Height-24))
        $script:expandedHeight=$window.Height
    }
    $window.Left=[Math]::Max($workArea.Left,[Math]::Min($window.Left,$workArea.Right-$window.Width))
    $window.Top=[Math]::Max($workArea.Top,[Math]::Min($window.Top,$workArea.Bottom-$window.Height))
    $sizeButton.Content=switch($mode){'小'{'小'}'大'{'大'}default{'中'}}
    $sizeButton.ToolTip="当前：$mode；点击切换小、标准、大尺寸"
}

function Start-GitHubSkillSync([bool]$Force=$false) {
    if ($script:githubJob -and $script:githubJob.State -in @('Running','NotStarted')) { return }
    if (-not $Force -and ([datetime]::Now-$script:lastGitHubSync).TotalMinutes -lt 30) { return }
    $terms = @(Get-FrequentQueryTerms -HistoryPath $historyPath -Top 6 | ForEach-Object Term)
    if (-not $terms.Count) { return }
    $statusText.Text='正在 GitHub 搜索并隔离审核…'; $githubSyncButton.IsEnabled=$false
    $module=$githubSyncPath; $homePath=$CodexHome; $quarantine=$quarantineRoot
    $script:githubJob = Start-Job -ArgumentList $module,$homePath,$quarantine,$terms -ScriptBlock {
        param($module,$homePath,$quarantine,$terms)
        Import-Module $module -Force
        $installed=0; $rejected=0; $errors=0
        $candidates=@(Find-GitHubSkillCandidates -Terms $terms)
        foreach($candidate in $candidates){
            try {
                $stage=Expand-GitHubCandidateToQuarantine -Candidate $candidate -QuarantineRoot $quarantine
                if(-not $stage.Audit.Safe){$rejected++;continue}
                $destinationName=if($candidate.SkillPath -eq '.'){($candidate.Repository -split '/')[-1]}else{[IO.Path]::GetFileName($candidate.SkillPath)}
                $destination=Join-Path (Join-Path $homePath 'skills') $destinationName
                if(Test-Path -LiteralPath $destination){continue}
                Install-GitHubSkillCandidate -Candidate $candidate -CodexHome $homePath
                $installed++
            } catch {$errors++}
        }
        [pscustomobject]@{Candidates=$candidates.Count;Installed=$installed;Rejected=$rejected;Errors=$errors}
    }
    $script:lastGitHubSync=[datetime]::Now
}

function Set-Collapsed([bool]$collapsed) {
    $script:isCollapsed=$collapsed
    if ($collapsed) {
        $script:expandedHeight=$window.Height; $expandedArea.Visibility='Collapsed'; $footer.Visibility='Collapsed'
        $window.ResizeMode='NoResize'; $window.Height=194; $collapseButton.Content=[char]0xE922
    } else {
        $expandedArea.Visibility='Visible'; $footer.Visibility='Visible'; $window.ResizeMode='NoResize'
        $window.Height=[Math]::Max(360,$script:expandedHeight); $collapseButton.Content=[char]0xE921
    }
}

$queryBox.Add_TextChanged({$placeholder.Visibility=if($queryBox.Text){'Collapsed'}else{'Visible'}})
$queryBox.Add_KeyDown({if($_.Key -eq 'Enter'){if($queryBox.Text.Trim()){Add-QueryHistory -HistoryPath $historyPath -Query $queryBox.Text.Trim()};Update-Recommendations;Start-GitHubSkillSync;$_.Handled=$true}})
$searchButton.Add_Click({if($queryBox.Text.Trim()){Add-QueryHistory -HistoryPath $historyPath -Query $queryBox.Text.Trim()};Update-Recommendations;Start-GitHubSkillSync})
$githubSyncButton.Add_Click({Start-GitHubSkillSync $true})
foreach($modeButton in $modeButtons){$modeButton.Add_Checked({
    $script:workMode=[string]$this.Tag
    $placeholder.Text=switch($script:workMode){'产品判断'{'描述哪里感觉不合理…'}'UI 检查'{'描述哪里看起来不对…'}'Skills'{'描述你想完成什么…'}default{'用口语说你想托管什么…'}}
    Update-Recommendations
})}
$placeholder.Text=switch($script:workMode){'产品判断'{'描述哪里感觉不合理…'}'UI 检查'{'描述哪里看起来不对…'}'Skills'{'描述你想完成什么…'}default{'用口语说你想托管什么…'}}
$usageRefreshButton.Add_Click({Update-UsageDisplay})
$usageCard.Add_MouseLeftButtonUp({Update-UsageDisplay})
$copyButton.Add_Click({
    $task=$queryBox.Text.Trim(); if(-not $task){$task='请根据我的下一条中文需求选择合适的 skills'}
    [Windows.Clipboard]::SetText((New-CodexTaskPrompt -Task $task -Skills $script:currentSkills -Mode $script:workMode))
    $statusText.Text='已复制，可以直接粘贴给 Codex'
})
$pinButton.Add_Click({$window.Topmost=-not $window.Topmost;$pinButton.Opacity=if($window.Topmost){1}else{0.45}})
$sizeButton.Add_Click({$next=switch($script:sizeMode){'小'{'标准'}'标准'{'大'}default{'小'}};Set-WidgetSize $next})
$collapseButton.Add_Click({Set-Collapsed (-not $script:isCollapsed)})
$closeButton.Add_Click({$window.Close()})
$window.Add_MouseLeftButtonDown({if($_.ButtonState -eq 'Pressed' -and $_.OriginalSource -isnot [Windows.Controls.TextBox]){try{$window.DragMove()}catch{}}})
$window.Add_SourceInitialized({
    # WPF uses device-independent pixels. SystemParameters avoids placing the
    # widget off-screen on mixed-DPI multi-monitor setups.
    $workArea = [Windows.SystemParameters]::WorkArea
    Set-WidgetSize $(if($CaptureSize){$CaptureSize}else{$script:sizeMode})
    if ($settings.PSObject.Properties['Left'] -and $settings.PSObject.Properties['Top'] -and -not $CapturePath) {
        $window.Left = [double]$settings.Left
        $window.Top = [double]$settings.Top
    } else {
        $window.Left = $workArea.Right - $window.Width - 28
        $window.Top = $workArea.Top + 28
    }
    $window.Left=[Math]::Max($workArea.Left,[Math]::Min($window.Left,$workArea.Right-$window.Width))
    $window.Top=[Math]::Max($workArea.Top,[Math]::Min($window.Top,$workArea.Bottom-$window.Height))
})
$window.Add_Closing({
    if($script:githubJob){Stop-Job $script:githubJob -ErrorAction SilentlyContinue;Remove-Job $script:githubJob -Force -ErrorAction SilentlyContinue}
    if(-not $CapturePath){
        [pscustomobject]@{
            Left=[Math]::Round($window.Left,0); Top=[Math]::Round($window.Top,0)
            Width=[Math]::Round($window.Width,0)
            Height=[Math]::Round([Math]::Max(360,$script:expandedHeight),0)
            SizeMode=$script:sizeMode
            WorkMode=$script:workMode
            Topmost=$window.Topmost
        } | ConvertTo-Json | Set-Content -LiteralPath $settingsPath -Encoding UTF8
    }
})

if($CaptureMode){$script:workMode=$CaptureMode;$captureModeButton=$modeButtons|Where-Object {$_.Tag -eq $CaptureMode}|Select-Object -First 1;if($captureModeButton){$captureModeButton.IsChecked=$true}}
if($CaptureQuery){$queryBox.Text=$CaptureQuery}
Update-Recommendations
Update-UsageDisplay
$usageTimer=New-Object Windows.Threading.DispatcherTimer
$usageTimer.Interval=[TimeSpan]::FromSeconds(60)
$usageTimer.Add_Tick({Update-UsageDisplay})
$usageTimer.Start()
$githubTimer=New-Object Windows.Threading.DispatcherTimer
$githubTimer.Interval=[TimeSpan]::FromSeconds(2)
$githubTimer.Add_Tick({
    if($script:githubJob -and $script:githubJob.State -in @('Completed','Failed','Stopped')){
        $result=@(Receive-Job $script:githubJob -ErrorAction SilentlyContinue | Select-Object -Last 1)
        Remove-Job $script:githubJob -Force -ErrorAction SilentlyContinue; $script:githubJob=$null; $githubSyncButton.IsEnabled=$true
        $script:catalog=@(Get-CodexSkillCatalog -CodexHome $CodexHome); $countText.Text=('{0} 个可用' -f $script:catalog.Count)
        if($result.Count){$statusText.Text=('GitHub：安装 {0}，隔离 {1}' -f $result[0].Installed,$result[0].Rejected)}else{$statusText.Text='GitHub 同步未完成，请稍后重试'}
        Update-Recommendations
    }
})
$githubTimer.Start()
if ($CapturePath) {
    $window.Add_ContentRendered({
        [Windows.Input.Keyboard]::Focus($(if($CaptureMode){$captureModeButton}else{$modeButtons[0]}))|Out-Null
        $window.UpdateLayout()
        $width=[Math]::Max(1,[int][Math]::Ceiling($window.ActualWidth));$height=[Math]::Max(1,[int][Math]::Ceiling($window.ActualHeight))
        $bitmap=New-Object Windows.Media.Imaging.RenderTargetBitmap($width,$height,96,96,[Windows.Media.PixelFormats]::Pbgra32)
        $bitmap.Render($window);$encoder=New-Object Windows.Media.Imaging.PngBitmapEncoder;$encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
        $stream=[IO.File]::Open($CapturePath,[IO.FileMode]::Create);try{$encoder.Save($stream)}finally{$stream.Dispose()}
        $window.Close()
    })
}
[void]$window.ShowDialog()
