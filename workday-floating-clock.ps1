Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class WorkdayClockNative {
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left, Top, Right, Bottom; }
    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr hwnd, out RECT rect);
    [DllImport("user32.dll")]
    public static extern bool ReleaseCapture();
    [DllImport("user32.dll")]
    public static extern IntPtr SendMessage(IntPtr hwnd, int msg, IntPtr wParam, IntPtr lParam);
}
"@
$ErrorActionPreference = "Stop"
$errorLog = Join-Path ([Environment]::GetFolderPath("Desktop")) "workday-floating-clock-error.log"
trap {
    $details = $_ | Out-String
    [IO.File]::WriteAllText($errorLog, $details)
    try {
        [System.Windows.MessageBox]::Show(
            "Floating clock startup failed. Error saved to:`n$errorLog`n`n$details",
            "Workday Floating Clock",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Error
        ) | Out-Null
    } catch {}
    exit 1
}

[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Width="1280" Height="330" MinWidth="320" MinHeight="112"
        WindowStyle="None" ResizeMode="CanResize" AllowsTransparency="True"
        Background="Transparent" Topmost="True" ShowInTaskbar="True"
        TextOptions.TextFormattingMode="Display"
        Title="工作时间悬浮闹钟">
  <Grid x:Name="WindowRoot">
  <Border CornerRadius="22" BorderBrush="#536B91" BorderThickness="1" Padding="14">
    <Border.Background>
      <LinearGradientBrush StartPoint="0,0" EndPoint="1,1">
        <GradientStop Color="#F0182943" Offset="0"/>
        <GradientStop Color="#F0121C31" Offset="1"/>
      </LinearGradientBrush>
    </Border.Background>
    <Border.Effect>
      <DropShadowEffect Color="#000000" BlurRadius="18" ShadowDepth="6"
                        Opacity="0.35"/>
    </Border.Effect>
    <Grid>
      <Grid.ColumnDefinitions>
        <ColumnDefinition x:Name="TimerColumn" Width="280"/>
        <ColumnDefinition x:Name="StockColumn" Width="320"/>
        <ColumnDefinition x:Name="LyricsColumn" Width="*"/>
      </Grid.ColumnDefinitions>
      <Grid x:Name="TimerPanel" Grid.Column="0" Margin="0,0,14,0" Background="#D9142845">
        <Grid.RowDefinitions>
          <RowDefinition Height="*"/>
          <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        <StackPanel x:Name="ClockInfoPanel" Grid.Row="0" VerticalAlignment="Center" Margin="18,12,14,0">
          <TextBlock x:Name="WorkdayTitleText" Text="WORKDAY  ·  工作时间" Foreground="#8FD9FF" FontSize="11"
                     FontWeight="SemiBold"/>
          <TextBlock x:Name="ClockText" Foreground="#F8FBFF" FontSize="42"
                   FontWeight="SemiBold" FontFamily="Bahnschrift, Segoe UI"
                   Margin="0,4,0,0" TextOptions.TextFormattingMode="Ideal"/>
          <TextBlock x:Name="DateText" Foreground="#9EABC4" FontSize="12" Margin="1,-2,0,10"/>
          <TextBlock x:Name="StatusText" Foreground="#7EE6B5" FontSize="14"
                   FontWeight="SemiBold"/>
          <TextBlock x:Name="HintText" Foreground="#AAB6CC" FontSize="12"
                   Margin="0,2,0,0"/>
        </StackPanel>
        <StackPanel x:Name="CountdownPanel" Grid.Row="1" Margin="18,12,14,14">
          <TextBlock x:Name="RemainingLabel" Text="剩余时间" Foreground="#8E9AB3" FontSize="10"/>
          <TextBlock x:Name="CountdownText" Text="00:00:00" Foreground="#FFFFFF"
                     FontSize="27" FontWeight="SemiBold" FontFamily="Bahnschrift, Consolas"
                     TextOptions.TextFormattingMode="Ideal"/>
        </StackPanel>
      </Grid>
      <Grid x:Name="StockPanel" Grid.Column="1" Margin="0,0,14,0" Background="#D9123440">
        <Grid.RowDefinitions>
          <RowDefinition Height="Auto"/>
          <RowDefinition Height="Auto"/>
          <RowDefinition Height="*"/>
        </Grid.RowDefinitions>
        <TextBlock x:Name="MarketTitleText" Text="MARKET  ·  创业板指 399006" Foreground="#8FD9FF" FontSize="11"
                   FontWeight="SemiBold" Margin="12,10,12,0"/>
        <TextBlock x:Name="StockStatusText" Grid.Row="0" Text="准备行情..."
                   Foreground="#8E9AB3" FontSize="10"
                   HorizontalAlignment="Right" Margin="12,10,12,0"/>
        <StackPanel x:Name="StockQuotePanel" Grid.Row="1" Orientation="Horizontal" Margin="12,6,12,7">
          <TextBlock x:Name="StockPriceText" Text="--.--" Foreground="#FFFFFF"
                     FontSize="28" FontWeight="Bold" FontFamily="Consolas"/>
          <StackPanel x:Name="StockDetailPanel" Margin="12,2,0,0" VerticalAlignment="Center">
            <TextBlock x:Name="StockChangeText" Text="--  --%" Foreground="#9EABC4"
                       FontSize="13" FontWeight="SemiBold"/>
            <TextBlock x:Name="StockRangeText" Text="高 --  低 --" Foreground="#8E9AB3"
                       FontSize="11"/>
          </StackPanel>
        </StackPanel>
        <Border x:Name="StockChartHost" Grid.Row="2" Background="#111A2A"
                CornerRadius="10" Padding="5" MinHeight="120" Margin="10,0,10,10">
          <Canvas x:Name="StockChart" ClipToBounds="True"
                  HorizontalAlignment="Stretch" VerticalAlignment="Stretch"/>
        </Border>
      </Grid>
      <Grid x:Name="LyricsPanelRoot" Grid.Column="2" Background="#D9122038" Margin="0">
        <Grid.RowDefinitions>
          <RowDefinition Height="Auto"/>
          <RowDefinition Height="Auto"/>
          <RowDefinition Height="Auto"/>
          <RowDefinition Height="*"/>
        </Grid.RowDefinitions>
        <StackPanel x:Name="LyricsSearchPanel" Grid.Row="0" Orientation="Horizontal" Margin="14,10,12,0">
          <TextBlock Text="MUSIC  ·  歌词" Foreground="#C2B6FF" FontSize="11"
                     FontWeight="SemiBold" VerticalAlignment="Center"/>
          <TextBox x:Name="SearchBox" Width="200" Height="27" Margin="14,0,6,0"
                   Padding="8,4" Background="#243B5C" Foreground="#F5F8FF"
                   BorderBrush="#53627F" ToolTip="Search music title or artist"/>
          <Button x:Name="SearchButton" Content="搜索" Width="58" Height="27"
                  Background="#496AA0" Foreground="#FFFFFF" BorderThickness="0"/>
          <TextBlock x:Name="SearchStatus" Text="支持歌名或歌手，至少输入 2 个字"
                     Foreground="#AAB6CC" FontSize="11" Margin="10,6,0,0"/>
        </StackPanel>
        <DockPanel x:Name="RecommendDock" Grid.Row="1" Margin="14,8,12,0" LastChildFill="True">
          <Button x:Name="RecommendRefreshButton" DockPanel.Dock="Right"
                  Content="刷新推荐" Width="72" Height="24" Margin="8,0,0,0"
                  Background="#2B3F5C" Foreground="#DCE5F5" BorderThickness="0"
                  FontSize="11" ToolTip="换一批推荐歌曲" Cursor="Hand"/>
          <TextBlock DockPanel.Dock="Left" Text="推荐" Foreground="#8E9AB3"
                     FontSize="11" VerticalAlignment="Center" Margin="0,0,8,0"/>
          <WrapPanel x:Name="RecommendPanel" Orientation="Horizontal"/>
        </DockPanel>
        <TextBlock x:Name="TrackText" Grid.Row="2" Text="未选择歌曲"
                   Foreground="#9EABC4" FontSize="12" Margin="14,8,14,8"
                   TextTrimming="CharacterEllipsis" TextWrapping="NoWrap"/>
        <ScrollViewer x:Name="LyricsViewer" Grid.Row="3"
                      VerticalScrollBarVisibility="Hidden"
                      HorizontalScrollBarVisibility="Disabled"
                      IsHitTestVisible="False" CanContentScroll="False" Background="Transparent"
                      Padding="10,0,10,10">
          <StackPanel x:Name="LyricsPanel"/>
        </ScrollViewer>
      </Grid>
      <Grid x:Name="CompactSummaryPanel" Grid.Column="0" Grid.ColumnSpan="3" Visibility="Collapsed">
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="*"/>
          <ColumnDefinition Width="*"/>
          <ColumnDefinition Width="*"/>
        </Grid.ColumnDefinitions>
        <Border Grid.Column="0" Background="#B9162D4B" CornerRadius="10" Margin="0,0,4,0" Padding="6">
          <StackPanel VerticalAlignment="Center">
            <TextBlock Text="现在" Foreground="#7890AD" FontSize="9" HorizontalAlignment="Center"/>
            <TextBlock x:Name="SummaryClockText" Text="--:--" Foreground="#F7FAFF" FontSize="19" FontWeight="SemiBold"
                       FontFamily="Bahnschrift, Segoe UI" HorizontalAlignment="Center"/>
            <TextBlock x:Name="SummaryCountdownText" Text="剩余 --:--:--" Foreground="#9FD5FF" FontSize="10"
                       HorizontalAlignment="Center" TextTrimming="CharacterEllipsis"/>
          </StackPanel>
        </Border>
        <Border Grid.Column="1" Background="#B9143440" CornerRadius="10" Margin="2,0,2,0" Padding="6">
          <StackPanel VerticalAlignment="Center">
            <TextBlock Text="创业板" Foreground="#7890AD" FontSize="9" HorizontalAlignment="Center"/>
            <TextBlock x:Name="SummaryStockPriceText" Text="--.--" Foreground="#F7FAFF" FontSize="18" FontWeight="SemiBold"
                       FontFamily="Consolas" HorizontalAlignment="Center"/>
            <TextBlock x:Name="SummaryStockChangeText" Text="等待行情" Foreground="#8E9AB3" FontSize="10"
                       HorizontalAlignment="Center" TextTrimming="CharacterEllipsis"/>
          </StackPanel>
        </Border>
        <Border Grid.Column="2" Background="#B9122038" CornerRadius="10" Margin="4,0,0,0" Padding="6">
          <StackPanel VerticalAlignment="Center">
            <TextBlock Text="正在播放" Foreground="#897EB1" FontSize="9" HorizontalAlignment="Center"/>
            <TextBlock x:Name="SummaryTrackText" Text="未选择歌曲" Foreground="#EEE9FF" FontSize="12" FontWeight="SemiBold"
                       TextAlignment="Center" TextWrapping="NoWrap" TextTrimming="CharacterEllipsis"/>
            <TextBlock x:Name="SummaryLyricText" Text="歌词加载后显示" Foreground="#B9B0DA" FontSize="9.5"
                       TextAlignment="Center" TextWrapping="Wrap" MaxHeight="28" TextTrimming="CharacterEllipsis">
              <TextBlock.RenderTransform>
                <TranslateTransform x:Name="SummaryLyricTransform" Y="0"/>
              </TextBlock.RenderTransform>
            </TextBlock>
          </StackPanel>
        </Border>
      </Grid>
      <StackPanel x:Name="ChromeButtons" Grid.Column="0" Grid.ColumnSpan="3" Orientation="Horizontal"
                  VerticalAlignment="Top" HorizontalAlignment="Right" Margin="0,0,4,0"
                  Background="#E8172943" Visibility="Collapsed" Opacity="0">
        <Button x:Name="ZoomOutButton" Width="28" Height="26"
                Background="Transparent" Foreground="#9EABC4" BorderThickness="0"
                Padding="0" ToolTip="缩小">
          <Grid Width="12" Height="12">
            <Rectangle Height="1.5" Fill="#9EABC4" VerticalAlignment="Center" RadiusX="0.75" RadiusY="0.75"/>
          </Grid>
        </Button>
        <Button x:Name="ZoomInButton" Width="28" Height="26"
                Background="Transparent" Foreground="#9EABC4" BorderThickness="0"
                Padding="0" ToolTip="放大">
          <Grid Width="12" Height="12">
            <Rectangle Height="1.5" Fill="#9EABC4" VerticalAlignment="Center" RadiusX="0.75" RadiusY="0.75"/>
            <Rectangle Width="1.5" Fill="#9EABC4" HorizontalAlignment="Center" RadiusX="0.75" RadiusY="0.75"/>
          </Grid>
        </Button>
        <Button x:Name="MinimizeButton" Width="28" Height="26"
                Background="Transparent" Foreground="#9EABC4" BorderThickness="0"
                Padding="0" ToolTip="最小化">
          <Grid Width="12" Height="12">
            <Rectangle Height="1.5" Width="11" Fill="#9EABC4" VerticalAlignment="Center" RadiusX="0.75" RadiusY="0.75"/>
          </Grid>
        </Button>
        <Button x:Name="CloseButton" Width="28" Height="26"
                Background="Transparent" Foreground="#9EABC4" BorderThickness="0"
                Padding="0" ToolTip="关闭">
          <Grid Width="12" Height="12">
            <Rectangle Width="1.5" Height="14" Fill="#9EABC4" HorizontalAlignment="Center" VerticalAlignment="Center" RenderTransformOrigin="0.5,0.5">
              <Rectangle.RenderTransform><RotateTransform Angle="45"/></Rectangle.RenderTransform>
            </Rectangle>
            <Rectangle Width="1.5" Height="14" Fill="#9EABC4" HorizontalAlignment="Center" VerticalAlignment="Center" RenderTransformOrigin="0.5,0.5">
              <Rectangle.RenderTransform><RotateTransform Angle="-45"/></Rectangle.RenderTransform>
            </Rectangle>
          </Grid>
        </Button>
      </StackPanel>
    </Grid>
  </Border>
  <Border x:Name="ChromeHotZone" Width="56" Height="40" HorizontalAlignment="Right"
          VerticalAlignment="Top" Background="Transparent" Cursor="Hand"/>
  <Border x:Name="ResizeLeft" Width="9" HorizontalAlignment="Left" Background="Transparent" Cursor="SizeWE"/>
  <Border x:Name="ResizeRight" Width="9" HorizontalAlignment="Right" Background="Transparent" Cursor="SizeWE"/>
  <Border x:Name="ResizeTop" Height="9" VerticalAlignment="Top" Background="Transparent" Cursor="SizeNS"/>
  <Border x:Name="ResizeBottom" Height="9" VerticalAlignment="Bottom" Background="Transparent" Cursor="SizeNS"/>
  <Border x:Name="ResizeTopLeft" Width="18" Height="18" HorizontalAlignment="Left" VerticalAlignment="Top" Background="Transparent" Cursor="SizeNWSE"/>
  <Border x:Name="ResizeTopRight" Width="18" Height="18" HorizontalAlignment="Right" VerticalAlignment="Top" Background="Transparent" Cursor="SizeNESW"/>
  <Border x:Name="ResizeBottomLeft" Width="18" Height="18" HorizontalAlignment="Left" VerticalAlignment="Bottom" Background="Transparent" Cursor="SizeNESW"/>
  <Border x:Name="ResizeBottomRight" Width="18" Height="18" HorizontalAlignment="Right" VerticalAlignment="Bottom" Background="Transparent" Cursor="SizeNWSE"/>
  </Grid>
</Window>
'@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)
$clockText = $window.FindName("ClockText")
$dateText = $window.FindName("DateText")
$statusText = $window.FindName("StatusText")
$hintText = $window.FindName("HintText")
$countdownText = $window.FindName("CountdownText")
$stockPriceText = $window.FindName("StockPriceText")
$stockChangeText = $window.FindName("StockChangeText")
$stockRangeText = $window.FindName("StockRangeText")
$stockStatusText = $window.FindName("StockStatusText")
$stockChart = $window.FindName("StockChart")
$stockChartHost = $window.FindName("StockChartHost")
$stockPanel = $window.FindName("StockPanel")
$timerPanel = $window.FindName("TimerPanel")
$workdayTitleText = $window.FindName("WorkdayTitleText")
$clockInfoPanel = $window.FindName("ClockInfoPanel")
$countdownPanel = $window.FindName("CountdownPanel")
$remainingLabel = $window.FindName("RemainingLabel")
$lyricsPanelRoot = $window.FindName("LyricsPanelRoot")
$marketTitleText = $window.FindName("MarketTitleText")
$stockQuotePanel = $window.FindName("StockQuotePanel")
$stockDetailPanel = $window.FindName("StockDetailPanel")
$lyricsSearchPanel = $window.FindName("LyricsSearchPanel")
$recommendDock = $window.FindName("RecommendDock")
$compactSummaryPanel = $window.FindName("CompactSummaryPanel")
$summaryClockText = $window.FindName("SummaryClockText")
$summaryCountdownText = $window.FindName("SummaryCountdownText")
$summaryStockPriceText = $window.FindName("SummaryStockPriceText")
$summaryStockChangeText = $window.FindName("SummaryStockChangeText")
$summaryTrackText = $window.FindName("SummaryTrackText")
$summaryLyricText = $window.FindName("SummaryLyricText")
$summaryLyricTransform = $window.FindName("SummaryLyricTransform")
$chromeButtons = $window.FindName("ChromeButtons")
$chromeHotZone = $window.FindName("ChromeHotZone")
$searchBox = $window.FindName("SearchBox")
$searchButton = $window.FindName("SearchButton")
$searchStatus = $window.FindName("SearchStatus")
$recommendPanel = $window.FindName("RecommendPanel")
$recommendRefreshButton = $window.FindName("RecommendRefreshButton")
$trackText = $window.FindName("TrackText")
$lyricsViewer = $window.FindName("LyricsViewer")
$lyricsPanel = $window.FindName("LyricsPanel")
$zoomOutButton = $window.FindName("ZoomOutButton")
$zoomInButton = $window.FindName("ZoomInButton")
$closeButton = $window.FindName("CloseButton")
$minimizeButton = $window.FindName("MinimizeButton")
$script:lyricEntries = @()
$script:lyricStartTime = Get-Date
$script:lyricCurrentIndex = -1
$script:targetLyricsOffset = 0
$script:lyricLineControls = @()
$script:lastLyricsFrame = [DateTime]::UtcNow
$script:stockPrices = @()
$script:stockPrevClose = 0
$script:widthBeforeHideStock = 0
$script:stockLayoutHidden = $false
$script:recommendPool = @()
$script:recommendOffset = 0
$script:rng = New-Object System.Random
$script:zoomLevels = @(
    [PSCustomObject]@{ Width = 320; Height = 112; Name = "极简" },
    [PSCustomObject]@{ Width = 760; Height = 270; Name = "紧凑" },
    [PSCustomObject]@{ Width = 1040; Height = 310; Name = "标准" },
    [PSCustomObject]@{ Width = 1280; Height = 330; Name = "宽屏" },
    [PSCustomObject]@{ Width = 1520; Height = 390; Name = "大屏" }
)
$script:isMinimalLayout = $false
$script:lastExpandedWidth = 1040
$script:lastExpandedHeight = 310
$script:suppressExpandedTracking = $false

# AllowsTransparency 会移除系统非客户区；主动返回八方向命中码，四边和四角都可拖动缩放。
$window.Add_SourceInitialized({
    $helper = New-Object Windows.Interop.WindowInteropHelper($window)
    $script:hwndSource = [Windows.Interop.HwndSource]::FromHwnd($helper.Handle)
    $script:resizeHook = [Windows.Interop.HwndSourceHook]{
        param($hwnd, $msg, $wParam, $lParam, [ref]$handled)
        if ($msg -ne 0x0084 -or $window.WindowState -ne [Windows.WindowState]::Normal) {
            return [IntPtr]::Zero
        }
        $rect = New-Object WorkdayClockNative+RECT
        if (-not [WorkdayClockNative]::GetWindowRect($hwnd, [ref]$rect)) { return [IntPtr]::Zero }
        $raw = [BitConverter]::GetBytes($lParam.ToInt64())
        $x = [BitConverter]::ToInt16($raw, 0)
        $y = [BitConverter]::ToInt16($raw, 2)
        $edge = 10
        $left = $x -ge $rect.Left -and $x -lt ($rect.Left + $edge)
        $right = $x -le $rect.Right -and $x -gt ($rect.Right - $edge)
        $top = $y -ge $rect.Top -and $y -lt ($rect.Top + $edge)
        $bottom = $y -le $rect.Bottom -and $y -gt ($rect.Bottom - $edge)
        $hit = 0
        if ($top -and $left) { $hit = 13 }
        elseif ($top -and $right) { $hit = 14 }
        elseif ($bottom -and $left) { $hit = 16 }
        elseif ($bottom -and $right) { $hit = 17 }
        elseif ($left) { $hit = 10 }
        elseif ($right) { $hit = 11 }
        elseif ($top) { $hit = 12 }
        elseif ($bottom) { $hit = 15 }
        if ($hit -ne 0) {
            $handled.Value = $true
            return [IntPtr]::new($hit)
        }
        return [IntPtr]::Zero
    }
    $script:hwndSource.AddHook($script:resizeHook)
})

$resizeZones = @{
    ResizeLeft = 10; ResizeRight = 11; ResizeTop = 12; ResizeTopLeft = 13
    ResizeTopRight = 14; ResizeBottom = 15; ResizeBottomLeft = 16; ResizeBottomRight = 17
}
foreach ($zoneName in $resizeZones.Keys) {
    $zone = $window.FindName($zoneName)
    if ($null -eq $zone) { continue }
    $zone.Tag = $resizeZones[$zoneName]
    $zone.Add_MouseLeftButtonDown({
        if ($window.WindowState -ne [Windows.WindowState]::Normal) { return }
        $helper = New-Object Windows.Interop.WindowInteropHelper($window)
        [void][WorkdayClockNative]::ReleaseCapture()
        [void][WorkdayClockNative]::SendMessage(
            $helper.Handle,
            0x00A1,
            [IntPtr]::new([int]$this.Tag),
            [IntPtr]::Zero
        )
        $_.Handled = $true
    })
}

$window.Add_MouseLeftButtonDown({
    if ($_.ChangedButton -eq [System.Windows.Input.MouseButton]::Left) {
        if ($_.ClickCount -gt 1) { return }
        $origin = $_.OriginalSource
        while ($null -ne $origin -and $origin -ne $window) {
            if ($origin -is [Windows.Controls.Primitives.ButtonBase] -or $origin -is [Windows.Controls.TextBox]) { return }
            try {
                $origin = [Windows.Media.VisualTreeHelper]::GetParent($origin)
            } catch { break }
        }
        $window.DragMove()
    }
})
$closeButton.Add_Click({ $window.Close() })
$minimizeButton.Add_Click({ $window.WindowState = [Windows.WindowState]::Minimized })
function Set-ZoomLevel([int]$direction) {
    $nearest = 0
    $nearestDistance = [double]::MaxValue
    for ($i = 0; $i -lt $script:zoomLevels.Count; $i++) {
        $distance = [math]::Abs($window.Width - $script:zoomLevels[$i].Width)
        if ($distance -lt $nearestDistance) {
            $nearest = $i
            $nearestDistance = $distance
        }
    }
    $targetIndex = [math]::Max(0, [math]::Min($script:zoomLevels.Count - 1, $nearest + $direction))
    $target = $script:zoomLevels[$targetIndex]
    if ($targetIndex -eq 0 -and $window.Width -gt 360) {
        $script:lastExpandedWidth = $window.Width
        $script:lastExpandedHeight = $window.Height
    } elseif ($targetIndex -gt 0) {
        $script:lastExpandedWidth = $target.Width
        $script:lastExpandedHeight = $target.Height
    }
    $script:suppressExpandedTracking = $true
    $window.Width = $target.Width
    $window.Height = $target.Height
    $script:suppressExpandedTracking = $false
    $zoomOutButton.IsEnabled = $targetIndex -gt 0
    $zoomInButton.IsEnabled = $targetIndex -lt ($script:zoomLevels.Count - 1)
    $zoomOutButton.ToolTip = "缩小 · 当前$($target.Name)"
    $zoomInButton.ToolTip = "放大 · 当前$($target.Name)"
    Update-CompactLayout
}

$zoomOutButton.Add_Click({ Set-ZoomLevel -1 })
$zoomInButton.Add_Click({ Set-ZoomLevel 1 })

function Set-MinimalDisplay {
    if ($window.Width -gt 360) {
        $script:lastExpandedWidth = $window.Width
        $script:lastExpandedHeight = $window.Height
    }
    $script:suppressExpandedTracking = $true
    $window.Width = 320
    $window.Height = 112
    $script:suppressExpandedTracking = $false
    Update-CompactLayout
}

function Restore-ExpandedDisplay {
    $targetWidth = [math]::Max(700, $script:lastExpandedWidth)
    $targetHeight = [math]::Max(250, $script:lastExpandedHeight)
    $script:suppressExpandedTracking = $true
    $window.Height = $targetHeight
    $window.Width = $targetWidth
    $script:suppressExpandedTracking = $false
    Update-CompactLayout
}

$window.Add_MouseDoubleClick({
    if ($_.ChangedButton -ne [Windows.Input.MouseButton]::Left) { return }
    $origin = $_.OriginalSource
    while ($null -ne $origin -and $origin -ne $window) {
        if ($origin -is [Windows.Controls.Primitives.ButtonBase] -or $origin -is [Windows.Controls.TextBox]) { return }
        try { $origin = [Windows.Media.VisualTreeHelper]::GetParent($origin) } catch { break }
    }
    if ($window.Width -le 360) { Restore-ExpandedDisplay } else { Set-MinimalDisplay }
    $_.Handled = $true
})
$window.Add_PreviewMouseWheel({
    if (([Windows.Input.Keyboard]::Modifiers -band [Windows.Input.ModifierKeys]::Control) -ne 0) {
        Set-ZoomLevel $(if ($_.Delta -gt 0) { 1 } else { -1 })
        $_.Handled = $true
    }
})
$window.Add_PreviewKeyDown({
    if (([Windows.Input.Keyboard]::Modifiers -band [Windows.Input.ModifierKeys]::Control) -ne 0) {
        if ($_.Key -eq [Windows.Input.Key]::Add -or $_.Key -eq [Windows.Input.Key]::OemPlus) {
            Set-ZoomLevel 1; $_.Handled = $true
        } elseif ($_.Key -eq [Windows.Input.Key]::Subtract -or $_.Key -eq [Windows.Input.Key]::OemMinus) {
            Set-ZoomLevel -1; $_.Handled = $true
        }
    }
})

# 控制栏默认隐身，只在右上角热区短暂出现。
$chromeHideTimer = New-Object Windows.Threading.DispatcherTimer
$chromeHideTimer.Interval = [TimeSpan]::FromMilliseconds(800)
$chromeHideTimer.Add_Tick({
    $chromeHideTimer.Stop()
    if (-not $chromeButtons.IsMouseOver -and -not $chromeHotZone.IsMouseOver) {
        $chromeButtons.BeginAnimation([Windows.UIElement]::OpacityProperty, $null)
        $chromeButtons.Opacity = 0
        $fadeOut = New-Object Windows.Media.Animation.DoubleAnimation
        $fadeOut.From = 1.0
        $fadeOut.To = 0.0
        $fadeOut.Duration = [Windows.Duration]::new([TimeSpan]::FromMilliseconds(130))
        $fadeOut.FillBehavior = [Windows.Media.Animation.FillBehavior]::Stop
        $chromeButtons.BeginAnimation([Windows.UIElement]::OpacityProperty, $fadeOut)
        $chromeCollapseTimer.Stop()
        $chromeCollapseTimer.Start()
    }
})

$chromeCollapseTimer = New-Object Windows.Threading.DispatcherTimer
$chromeCollapseTimer.Interval = [TimeSpan]::FromMilliseconds(150)
$chromeCollapseTimer.Add_Tick({
    $chromeCollapseTimer.Stop()
    if (-not $chromeButtons.IsMouseOver -and -not $chromeHotZone.IsMouseOver) {
        $chromeButtons.Visibility = [Windows.Visibility]::Collapsed
        $chromeHotZone.IsHitTestVisible = $true
    }
})

function Show-ChromeToolbar {
    if ($script:isMinimalLayout) { return }
    $chromeHideTimer.Stop()
    $chromeCollapseTimer.Stop()
    # 工具栏显示时让透明热区退出命中测试，点击才能真正落到四个按钮上。
    $chromeHotZone.IsHitTestVisible = $false
    $chromeButtons.BeginAnimation([Windows.UIElement]::OpacityProperty, $null)
    $chromeButtons.Visibility = [Windows.Visibility]::Visible
    $chromeButtons.Opacity = 1
    $fadeIn = New-Object Windows.Media.Animation.DoubleAnimation
    $fadeIn.From = 0.0
    $fadeIn.To = 1.0
    $fadeIn.Duration = [Windows.Duration]::new([TimeSpan]::FromMilliseconds(130))
    $fadeIn.FillBehavior = [Windows.Media.Animation.FillBehavior]::Stop
    $chromeButtons.BeginAnimation([Windows.UIElement]::OpacityProperty, $fadeIn)
}

function Queue-HideChromeToolbar {
    $chromeHideTimer.Stop()
    $chromeHideTimer.Start()
}

$chromeHotZone.Add_MouseEnter({ Show-ChromeToolbar })
$chromeHotZone.Add_MouseLeave({ Queue-HideChromeToolbar })
$chromeButtons.Add_MouseEnter({ Show-ChromeToolbar })
$chromeButtons.Add_MouseLeave({ Queue-HideChromeToolbar })
$window.Add_StateChanged({
    if ($window.WindowState -eq [Windows.WindowState]::Minimized) {
        $chromeHideTimer.Stop()
        $chromeCollapseTimer.Stop()
        $chromeButtons.Visibility = [Windows.Visibility]::Collapsed
        $chromeButtons.Opacity = 0
        $chromeHotZone.IsHitTestVisible = $true
    }
})

$windowMenu = New-Object Windows.Controls.ContextMenu
$menuMinimal = New-Object Windows.Controls.MenuItem
$menuMinimal.Header = "仅显示倒计时"
$menuMinimal.Add_Click({ Set-MinimalDisplay })
$menuRestore = New-Object Windows.Controls.MenuItem
$menuRestore.Header = "恢复展开模式"
$menuRestore.Add_Click({ Restore-ExpandedDisplay })
$menuMinimize = New-Object Windows.Controls.MenuItem
$menuMinimize.Header = "最小化到任务栏"
$menuMinimize.Add_Click({ $window.WindowState = [Windows.WindowState]::Minimized })
$menuClose = New-Object Windows.Controls.MenuItem
$menuClose.Header = "退出"
$menuClose.Add_Click({ $window.Close() })
[void]$windowMenu.Items.Add($menuMinimal)
[void]$windowMenu.Items.Add($menuRestore)
[void]$windowMenu.Items.Add((New-Object Windows.Controls.Separator))
[void]$windowMenu.Items.Add($menuMinimize)
[void]$windowMenu.Items.Add($menuClose)
$window.ContextMenu = $windowMenu

function Invoke-JsonUtf8($uri) {
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    } catch {}
    $client = New-Object System.Net.WebClient
    $client.Headers["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
    if ($uri -like "*music.163.com*") {
        $client.Headers["Referer"] = "https://music.163.com/"
    }
    if ($uri -like "*gtimg.cn*" -or $uri -like "*y.qq.com*") {
        $client.Headers["Referer"] = "https://y.qq.com/"
    }
    try {
        $bytes = $client.DownloadData([Uri]$uri)
        return [Text.Encoding]::UTF8.GetString($bytes) | ConvertFrom-Json
    } finally {
        $client.Dispose()
    }
}

function Get-TextGbk($uri) {
    $client = New-Object System.Net.WebClient
    $client.Encoding = [Text.Encoding]::GetEncoding("GB2312")
    $client.Headers["User-Agent"] = "WorkdayFloatingClock/1.0"
    $client.Headers["Referer"] = "https://finance.qq.com/"
    try {
        return $client.DownloadString([Uri]$uri)
    } finally {
        $client.Dispose()
    }
}

function Test-StockSessionVisible {
    $now = Get-Date
    if ($now.DayOfWeek -eq [DayOfWeek]::Saturday -or $now.DayOfWeek -eq [DayOfWeek]::Sunday) {
        return $false
    }
    $time = $now.TimeOfDay
    $open = [TimeSpan]::FromMinutes(9 * 60 + 30)
    $hideAfter = [TimeSpan]::FromMinutes(15 * 60 + 5)
    return ($time -ge $open -and $time -lt $hideAfter)
}

function Update-CompactLayout {
    try {
        if ($null -eq $stockPanel -or $null -eq $lyricsPanelRoot) { return }
        $mainGrid = [Windows.Controls.Grid]$stockPanel.Parent
        if ($null -eq $mainGrid -or $mainGrid.ColumnDefinitions.Count -lt 3) { return }

        $timerCol = $mainGrid.ColumnDefinitions[0]
        $stockCol = $mainGrid.ColumnDefinitions[1]
        $lyricsCol = $mainGrid.ColumnDefinitions[2]
        $zero = [Windows.GridLength]::new(0)
        $star = [Windows.GridLength]::new(1, [Windows.GridUnitType]::Star)

        # 极小档：唯一目标是最快看清倒计时。
        if ($window.Width -le 360) {
            $script:isMinimalLayout = $true
            $compactSummaryPanel.Visibility = [Windows.Visibility]::Collapsed
            $timerPanel.Visibility = [Windows.Visibility]::Visible
            $stockPanel.Visibility = [Windows.Visibility]::Collapsed
            $lyricsPanelRoot.Visibility = [Windows.Visibility]::Collapsed
            $clockInfoPanel.Visibility = [Windows.Visibility]::Collapsed
            $chromeButtons.Visibility = [Windows.Visibility]::Collapsed
            $chromeButtons.Opacity = 0
            $chromeHotZone.Visibility = [Windows.Visibility]::Collapsed
            $chromeHotZone.IsHitTestVisible = $true
            $timerCol.Width = $star
            $stockCol.Width = $zero
            $lyricsCol.Width = $zero
            $timerPanel.Margin = "0"
            $timerPanel.Background = [Windows.Media.Brushes]::Transparent
            [Windows.Controls.Grid]::SetRow($countdownPanel, 0)
            [Windows.Controls.Grid]::SetRowSpan($countdownPanel, 2)
            $countdownPanel.Margin = "0"
            $countdownPanel.HorizontalAlignment = [Windows.HorizontalAlignment]::Center
            $countdownPanel.VerticalAlignment = [Windows.VerticalAlignment]::Center
            $remainingLabel.TextAlignment = [Windows.TextAlignment]::Center
            $countdownText.TextAlignment = [Windows.TextAlignment]::Center
            $countdownText.FontSize = 30
            [Windows.Controls.Grid]::SetColumn($lyricsPanelRoot, 2)
            return
        }

        # 先恢复完整模块的基准属性，再按当前宽高降低信息密度。
        $wasMinimalLayout = $script:isMinimalLayout
        $script:isMinimalLayout = $false
        if (-not $script:suppressExpandedTracking -and $window.Width -ge 700) {
            $script:lastExpandedWidth = $window.Width
            $script:lastExpandedHeight = $window.Height
        }
        $clockInfoPanel.Visibility = [Windows.Visibility]::Visible
        $chromeHotZone.Visibility = [Windows.Visibility]::Visible
        if ($wasMinimalLayout) {
            $chromeButtons.Visibility = [Windows.Visibility]::Collapsed
            $chromeButtons.Opacity = 0
            $chromeHotZone.IsHitTestVisible = $true
        }
        $compactSummaryPanel.Visibility = [Windows.Visibility]::Collapsed
        $timerPanel.Visibility = [Windows.Visibility]::Visible
        $stockPanel.Visibility = [Windows.Visibility]::Visible
        $lyricsPanelRoot.Visibility = [Windows.Visibility]::Visible
        $timerPanel.Background = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromArgb(217, 20, 40, 69))
        $workdayTitleText.Visibility = [Windows.Visibility]::Visible
        $clockInfoPanel.Margin = "18,12,14,0"
        $clockText.FontSize = 42
        $dateText.Visibility = [Windows.Visibility]::Visible
        $statusText.Visibility = [Windows.Visibility]::Visible
        $statusText.FontSize = 14
        $hintText.Visibility = [Windows.Visibility]::Visible
        [Windows.Controls.Grid]::SetRow($countdownPanel, 1)
        [Windows.Controls.Grid]::SetRowSpan($countdownPanel, 1)
        $countdownPanel.Margin = "18,12,14,14"
        $countdownPanel.HorizontalAlignment = [Windows.HorizontalAlignment]::Stretch
        $countdownPanel.VerticalAlignment = [Windows.VerticalAlignment]::Stretch
        $remainingLabel.TextAlignment = [Windows.TextAlignment]::Left
        $countdownText.TextAlignment = [Windows.TextAlignment]::Left
        $countdownText.FontSize = 27
        $marketTitleText.Visibility = [Windows.Visibility]::Visible
        $stockStatusText.Visibility = [Windows.Visibility]::Visible
        $stockChartHost.Visibility = [Windows.Visibility]::Visible
        $stockPriceText.FontSize = 28
        $stockQuotePanel.Orientation = [Windows.Controls.Orientation]::Horizontal
        $stockDetailPanel.Margin = "12,2,0,0"
        $stockChangeText.Visibility = [Windows.Visibility]::Visible
        $stockRangeText.Visibility = [Windows.Visibility]::Visible
        [Windows.Controls.Grid]::SetRow($stockQuotePanel, 1)
        [Windows.Controls.Grid]::SetRowSpan($stockQuotePanel, 1)
        $stockQuotePanel.HorizontalAlignment = [Windows.HorizontalAlignment]::Stretch
        $stockQuotePanel.VerticalAlignment = [Windows.VerticalAlignment]::Center
        $stockQuotePanel.Margin = "12,6,12,7"
        $lyricsSearchPanel.Visibility = [Windows.Visibility]::Visible
        $recommendDock.Visibility = [Windows.Visibility]::Visible
        $trackText.Visibility = [Windows.Visibility]::Visible
        [Windows.Controls.Grid]::SetRow($trackText, 2)
        [Windows.Controls.Grid]::SetRowSpan($trackText, 1)
        $trackText.VerticalAlignment = [Windows.VerticalAlignment]::Stretch
        $trackText.TextAlignment = [Windows.TextAlignment]::Left
        $trackText.FontSize = 12
        $trackText.Margin = "14,8,14,8"
        $lyricsViewer.Visibility = [Windows.Visibility]::Visible
        $searchBox.Width = 200
        $searchStatus.Visibility = [Windows.Visibility]::Visible
        [Windows.Controls.Grid]::SetColumn($lyricsPanelRoot, 2)
        [Windows.Controls.Grid]::SetColumn($chromeButtons, 0)

        # 很窄或很矮：不丢模块，切换为三个等宽摘要卡。
        if ($window.Width -le 520 -or $window.Height -lt 170) {
            $compactSummaryPanel.Visibility = [Windows.Visibility]::Visible
            $timerPanel.Visibility = [Windows.Visibility]::Collapsed
            $stockPanel.Visibility = [Windows.Visibility]::Collapsed
            $lyricsPanelRoot.Visibility = [Windows.Visibility]::Collapsed
            $timerCol.Width = $star
            $stockCol.Width = $zero
            $lyricsCol.Width = $zero
            return
        }

        # 窄屏：三个模块都在，但各自只留下最有价值的信息。
        if ($window.Width -lt 650) {
            $timerCol.Width = [Windows.GridLength]::new(170)
            $stockCol.Width = [Windows.GridLength]::new(180)
            $lyricsCol.Width = $star
            $timerPanel.Margin = "0,0,6,0"
            $stockPanel.Margin = "0,0,6,0"
            $workdayTitleText.Visibility = [Windows.Visibility]::Collapsed
            $clockInfoPanel.Margin = "10,8,8,0"
            $clockText.FontSize = 28
            $dateText.Visibility = [Windows.Visibility]::Collapsed
            $hintText.Visibility = [Windows.Visibility]::Collapsed
            $statusText.FontSize = 11
            $countdownPanel.Margin = "10,6,8,10"
            $countdownText.FontSize = 20
            $marketTitleText.Visibility = [Windows.Visibility]::Collapsed
            $stockStatusText.Visibility = [Windows.Visibility]::Collapsed
            $stockChartHost.Visibility = [Windows.Visibility]::Collapsed
            $stockRangeText.Visibility = [Windows.Visibility]::Collapsed
            $stockPriceText.FontSize = 22
            $stockQuotePanel.Orientation = [Windows.Controls.Orientation]::Vertical
            $stockDetailPanel.Margin = "0,2,0,0"
            [Windows.Controls.Grid]::SetRow($stockQuotePanel, 0)
            [Windows.Controls.Grid]::SetRowSpan($stockQuotePanel, 3)
            $stockQuotePanel.HorizontalAlignment = [Windows.HorizontalAlignment]::Center
            $stockQuotePanel.VerticalAlignment = [Windows.VerticalAlignment]::Center
            $stockQuotePanel.Margin = "6"
            $lyricsSearchPanel.Visibility = [Windows.Visibility]::Collapsed
            $recommendDock.Visibility = [Windows.Visibility]::Collapsed
            $lyricsViewer.Visibility = [Windows.Visibility]::Collapsed
            [Windows.Controls.Grid]::SetRow($trackText, 0)
            [Windows.Controls.Grid]::SetRowSpan($trackText, 4)
            $trackText.VerticalAlignment = [Windows.VerticalAlignment]::Center
            $trackText.TextAlignment = [Windows.TextAlignment]::Center
            $trackText.Margin = "6"
            return
        }

        # 紧凑三栏：恢复走势图和歌词，搜索控件继续收起。
        if ($window.Width -lt 900) {
            $timerCol.Width = [Windows.GridLength]::new(220)
            $stockCol.Width = [Windows.GridLength]::new(250)
            $lyricsCol.Width = $star
            $timerPanel.Margin = "0,0,8,0"
            $stockPanel.Margin = "0,0,8,0"
            $clockText.FontSize = 34
            $clockInfoPanel.Margin = "14,10,10,0"
            $countdownPanel.Margin = "14,8,10,12"
            $countdownText.FontSize = 23
            $hintText.Visibility = [Windows.Visibility]::Collapsed
            $stockStatusText.Visibility = [Windows.Visibility]::Collapsed
            $lyricsSearchPanel.Visibility = [Windows.Visibility]::Collapsed
            $recommendDock.Visibility = [Windows.Visibility]::Collapsed
        }
        elseif ($window.Width -lt 1150) {
            $timerCol.Width = [Windows.GridLength]::new(250)
            $stockCol.Width = [Windows.GridLength]::new(290)
            $lyricsCol.Width = $star
            $timerPanel.Margin = "0,0,8,0"
            $stockPanel.Margin = "0,0,8,0"
            $searchBox.Width = 120
            $searchStatus.Visibility = [Windows.Visibility]::Collapsed
        } else {
            $timerCol.Width = [Windows.GridLength]::new(280)
            $stockCol.Width = [Windows.GridLength]::new(320)
            $lyricsCol.Width = $star
            $timerPanel.Margin = "0,0,12,0"
            $stockPanel.Margin = "0,0,12,0"
            $searchBox.Width = 200
            $searchStatus.Visibility = [Windows.Visibility]::Visible
        }

        # 高度不足时优先保留数字和文字，暂时收起最耗空间的图表/推荐。
        if ($window.Height -lt 230) {
            $stockChartHost.Visibility = [Windows.Visibility]::Collapsed
            $recommendDock.Visibility = [Windows.Visibility]::Collapsed
            $hintText.Visibility = [Windows.Visibility]::Collapsed
        }
    } catch {
        $script:lastLayoutError = $_.Exception.ToString()
    }
}

function Draw-StockChart {
    param(
        $prices,
        [double]$prevClose = 0
    )
    try {
        if ($null -eq $stockChart -or $null -eq $stockChartHost) { return }
        if ($stockPanel.Visibility -ne [Windows.Visibility]::Visible) { return }
        $priceList = @($prices | ForEach-Object { [double]$_ })
        if ($priceList.Count -lt 2) { return }

        $stockChartHost.UpdateLayout()
        $stockChart.Children.Clear()
        $hostWidth = $stockChartHost.ActualWidth - 8
        $hostHeight = $stockChartHost.ActualHeight - 8
        if ([double]::IsNaN($hostWidth) -or [double]::IsNaN($hostHeight)) { return }
        if ($hostWidth -lt 20 -or $hostHeight -lt 20) {
            $hostWidth = [math]::Max(20, $stockChartHost.RenderSize.Width - 8)
            $hostHeight = [math]::Max(20, $stockChartHost.RenderSize.Height - 8)
        }
        if ($hostWidth -lt 20 -or $hostHeight -lt 20) { return }

        $stockChart.Width = $hostWidth
        $stockChart.Height = $hostHeight
        $width = $hostWidth
        $height = $hostHeight

        $min = ($priceList | Measure-Object -Minimum).Minimum
        $max = ($priceList | Measure-Object -Maximum).Maximum
        if ($prevClose -gt 0) {
            $min = [math]::Min($min, $prevClose)
            $max = [math]::Max($max, $prevClose)
        }
        if ($max -eq $min) {
            $max += 1
            $min -= 1
        }
        # 留出上下呼吸空间，避免曲线贴边。
        $padding = [math]::Max(($max - $min) * 0.10, [math]::Abs($max) * 0.0002)
        $min -= $padding
        $max += $padding
        $range = $max - $min
        if ($range -le 0) { return }
        $last = $priceList[$priceList.Count - 1]
        $up = ($prevClose -le 0) -or ($last -ge $prevClose)
        $lineColor = if ($up) {
            [Windows.Media.Color]::FromRgb(232, 88, 88)
        } else {
            [Windows.Media.Color]::FromRgb(62, 196, 120)
        }

        # 轻量网格帮助判断趋势，又不会抢曲线视觉焦点。
        foreach ($ratio in @(0.25, 0.5, 0.75)) {
            $gridLine = New-Object Windows.Shapes.Line
            $gridLine.X1 = 0
            $gridLine.X2 = $width
            $gridLine.Y1 = $height * $ratio
            $gridLine.Y2 = $height * $ratio
            $gridLine.Stroke = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromArgb(28, 158, 171, 196))
            $gridLine.StrokeThickness = 1
            $stockChart.Children.Add($gridLine) | Out-Null
        }

        if ($prevClose -gt 0) {
            $yPrev = $height - (($prevClose - $min) / $range) * ($height - 8) - 4
            $dash = New-Object Windows.Shapes.Line
            $dash.X1 = 0
            $dash.Y1 = $yPrev
            $dash.X2 = $width
            $dash.Y2 = $yPrev
            $dash.Stroke = New-Object Windows.Media.SolidColorBrush (
                [Windows.Media.Color]::FromArgb(90, 158, 171, 196)
            )
            $dash.StrokeThickness = 1
            $dashPattern = [Windows.Media.DoubleCollection]::new()
            $dashPattern.Add(2)
            $dashPattern.Add(2)
            $dash.StrokeDashArray = $dashPattern
            $stockChart.Children.Add($dash) | Out-Null
        }

        $polyline = New-Object Windows.Shapes.Polyline
        $polyline.Stroke = New-Object Windows.Media.SolidColorBrush $lineColor
        $polyline.StrokeThickness = 1.8
        $points = New-Object Windows.Media.PointCollection
        for ($i = 0; $i -lt $priceList.Count; $i++) {
            $x = ($i / ($priceList.Count - 1)) * ($width - 4) + 2
            $y = $height - (($priceList[$i] - $min) / $range) * ($height - 8) - 4
            $points.Add((New-Object Windows.Point($x, $y))) | Out-Null
        }
        $polyline.Points = $points
        $stockChart.Children.Add($polyline) | Out-Null

        $dot = New-Object Windows.Shapes.Ellipse
        $dot.Width = 6
        $dot.Height = 6
        $dot.Fill = New-Object Windows.Media.SolidColorBrush $lineColor
        [Windows.Controls.Canvas]::SetLeft($dot, $points[$points.Count - 1].X - 3)
        [Windows.Controls.Canvas]::SetTop($dot, $points[$points.Count - 1].Y - 3)
        $stockChart.Children.Add($dot) | Out-Null
    } catch {
        $script:lastStockError = $_.Exception.ToString()
    }
}

function Draw-StockChartSafe {
    if ($script:stockPrices.Count -lt 2) { return }
    try {
        $stockChartHost.UpdateLayout()
        Draw-StockChart -prices $script:stockPrices -prevClose $script:stockPrevClose
    } catch {
        $script:lastStockError = $_.Exception.ToString()
    }
}

function Update-ChiNext {
    try {
        if (-not (Test-StockSessionVisible)) {
            Update-CompactLayout
            return
        }
        Update-CompactLayout
        $quote = Get-TextGbk "https://qt.gtimg.cn/q=sz399006"
        if ($quote -notmatch '="([^"]+)"') { return }
        $parts = $Matches[1] -split "~"
        if ($parts.Count -lt 35) { return }

        $price = [double]$parts[3]
        $prevClose = [double]$parts[4]
        $high = [double]$parts[33]
        $low = [double]$parts[34]
        $change = [double]$parts[31]
        $pct = [double]$parts[32]
        $up = $change -ge 0
        $color = if ($up) {
            New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(232, 88, 88))
        } else {
            New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(62, 196, 120))
        }

        $stockPriceText.Text = ("{0:F2}" -f $price)
        $stockPriceText.Foreground = $color
        $sign = if ($up) { "+" } else { "" }
        $stockChangeText.Text = ("{0}{1:F2}  {0}{2:F2}%" -f $sign, $change, $pct)
        $stockChangeText.Foreground = $color
        $stockRangeText.Text = ("高 {0:F2}  低 {1:F2}" -f $high, $low)
        $script:stockPrevClose = $prevClose

        $minute = Invoke-JsonUtf8 "https://web.ifzq.gtimg.cn/appstock/app/minute/query?code=sz399006"
        $rows = @($minute.data.sz399006.data.data)
        $prices = New-Object System.Collections.Generic.List[double]
        foreach ($row in $rows) {
            $fields = "$row" -split "\s+"
            if ($fields.Count -ge 2) {
                $prices.Add([double]$fields[1]) | Out-Null
            }
        }
        if ($prices.Count -gt 0) {
            $script:stockPrices = @($prices.ToArray())
            $stockChartHost.UpdateLayout()
            Draw-StockChart -prices $script:stockPrices -prevClose $script:stockPrevClose
        }
    } catch {
        $stockChangeText.Text = "行情暂时不可用"
        $stockChangeText.Foreground = [Windows.Media.Brushes]::Gray
    }
}

$script:stockRequestActive = $false
$script:lastStockError = $null

function Set-StockUnavailable($message) {
    $stockStatusText.Text = $message
    if (-not $script:stockPrices -or $script:stockPrices.Count -eq 0) {
        $stockChangeText.Text = $message
        $stockChangeText.Foreground = [Windows.Media.Brushes]::Gray
    }
}

function ConvertTo-InvariantDouble($value, [ref]$number) {
    $styles = [Globalization.NumberStyles]::Float -bor [Globalization.NumberStyles]::AllowThousands
    return [double]::TryParse(
        [string]$value,
        $styles,
        [Globalization.CultureInfo]::InvariantCulture,
        $number
    )
}

function Get-StockMinutePrices($minute) {
    $result = New-Object System.Collections.Generic.List[double]
    if ($null -eq $minute -or $null -eq $minute.data) { return $result.ToArray() }

    # 股票代码是动态属性，不能把解析绑死在 sz399006 这一层。
    $symbolNode = $null
    foreach ($property in @($minute.data.PSObject.Properties)) {
        if ($null -ne $property.Value) { $symbolNode = $property.Value; break }
    }
    if ($null -eq $symbolNode) { return $result.ToArray() }

    $rows = $symbolNode
    if ($null -ne $symbolNode.data) { $rows = $symbolNode.data }
    if ($null -ne $rows.data) { $rows = $rows.data }
    if ($rows -is [string]) { $rows = $rows -split "`r?`n" }

    foreach ($row in @($rows)) {
        $candidate = $null
        if ($null -ne $row.price) {
            $candidate = $row.price
        } elseif ($null -ne $row.current) {
            $candidate = $row.current
        } else {
            $fields = ([string]$row).Trim() -split '[\s,]+'
            if ($fields.Count -ge 2) { $candidate = $fields[1] }
        }
        $parsed = 0.0
        if ($null -ne $candidate -and (ConvertTo-InvariantDouble $candidate ([ref]$parsed)) -and $parsed -gt 0) {
            $result.Add($parsed) | Out-Null
        }
    }
    return $result.ToArray()
}

function Apply-StockQuoteText($quote) {
    if ($quote -notmatch '="([^"]+)"') { return }
    $parts = $Matches[1] -split "~"
    if ($parts.Count -lt 35) { return }

    $price = 0.0; $prevClose = 0.0; $high = 0.0; $low = 0.0; $change = 0.0; $pct = 0.0
    if (-not (ConvertTo-InvariantDouble $parts[3] ([ref]$price))) { throw "最新价格式无效" }
    [void](ConvertTo-InvariantDouble $parts[4] ([ref]$prevClose))
    [void](ConvertTo-InvariantDouble $parts[33] ([ref]$high))
    [void](ConvertTo-InvariantDouble $parts[34] ([ref]$low))
    [void](ConvertTo-InvariantDouble $parts[31] ([ref]$change))
    [void](ConvertTo-InvariantDouble $parts[32] ([ref]$pct))
    $up = $change -ge 0
    $color = if ($up) {
        New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(232, 88, 88))
    } else {
        New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(62, 196, 120))
    }

    $stockPriceText.Text = ("{0:F2}" -f $price)
    $stockPriceText.Foreground = $color
    $summaryStockPriceText.Text = ("{0:F2}" -f $price)
    $summaryStockPriceText.Foreground = $color
    $sign = if ($up) { "+" } else { "" }
    $stockChangeText.Text = ("{0}{1:F2}  {0}{2:F2}%" -f $sign, $change, $pct)
    $stockChangeText.Foreground = $color
    $summaryStockChangeText.Text = ("{0}{1:F2}%" -f $sign, $pct)
    $summaryStockChangeText.Foreground = $color
    $stockRangeText.Text = ("高 {0:F2}  低 {1:F2}" -f $high, $low)
    $script:stockPrevClose = $prevClose
}

function Start-StockDownload([string]$uri, [string]$stage) {
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $client = New-Object System.Net.WebClient
        $client.Headers["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
        $client.Headers["Referer"] = "https://finance.qq.com/"
        $script:stockNetworkClient = $client
        $script:stockNetworkStage = $stage
        $script:stockNetworkTask = $client.DownloadDataTaskAsync([Uri]$uri)
    } catch {
        if ($null -ne $client) { $client.Dispose() }
        $script:stockNetworkClient = $null
        $script:stockNetworkTask = $null
        $script:stockRequestActive = $false
        Set-StockUnavailable "行情连接失败"
    }
}

function Request-StockMinuteAsync {
    $stockStatusText.Text = "加载分时..."
    Start-StockDownload "https://web.ifzq.gtimg.cn/appstock/app/minute/query?code=sz399006" "minute"
}

function Request-StockQuoteAsync {
    if ($script:stockRequestActive) { return }
    $script:stockRequestActive = $true
    Update-CompactLayout
    $stockStatusText.Text = "连接行情..."
    Start-StockDownload "https://qt.gtimg.cn/q=sz399006" "quoteHttps"
}

function Complete-StockDownload {
    $task = $script:stockNetworkTask
    if ($null -eq $task -or -not $task.IsCompleted) { return }
    $stage = $script:stockNetworkStage
    $client = $script:stockNetworkClient
    $script:stockNetworkTask = $null
    $script:stockNetworkClient = $null
    try {
        if ($task.IsCanceled -or $task.IsFaulted) {
            if ($stage -eq "quoteHttps") {
                Start-StockDownload "http://qt.gtimg.cn/q=sz399006" "quoteHttp"
            } elseif ($stage -eq "quoteHttp") {
                Set-StockUnavailable "报价失败 · 尝试分时"
                Request-StockMinuteAsync
            } else {
                Set-StockUnavailable "分时连接失败"
                $script:stockRequestActive = $false
            }
            return
        }

        $bytes = $task.Result
        if ($stage -eq "quoteHttps" -or $stage -eq "quoteHttp") {
            $quote = [Text.Encoding]::GetEncoding("GB2312").GetString($bytes)
            try {
                Apply-StockQuoteText $quote
                $stockStatusText.Text = "最新价已更新 · 加载分时..."
            } catch {
                Set-StockUnavailable "报价解析失败 · 尝试分时"
            }
            Request-StockMinuteAsync
            return
        }

        $minute = [Text.Encoding]::UTF8.GetString($bytes) | ConvertFrom-Json
        $prices = @(Get-StockMinutePrices $minute)
        if ($prices.Count -gt 1) {
            $script:stockPrices = $prices
            $session = if (Test-StockSessionVisible) { "盘中" } else { "最近交易日" }
            $stockStatusText.Text = ("{0} {1} 点 · {2:HH:mm:ss}" -f $session, $prices.Count, (Get-Date))
            Draw-StockChartSafe
        } else {
            Set-StockUnavailable "暂无分时数据"
        }
        $script:stockRequestActive = $false
    } catch {
        $script:lastStockError = $_.Exception.ToString()
        if ($script:stockPrices.Count -gt 1) {
            $stockStatusText.Text = ("分时 {0} 点 · 已更新" -f $script:stockPrices.Count)
        } else {
            Set-StockUnavailable "行情解析失败"
        }
        $script:stockRequestActive = $false
    } finally {
        if ($null -ne $client) { $client.Dispose() }
    }
}
function Get-LyricsText($track) {
    try {
        $syncedText = $null
        $plainText = $null
        if ($track.Source -eq "netease") {
            $lyrics = Invoke-JsonUtf8 (
                "https://music.163.com/api/song/lyric?id=$($track.Id)&lv=1&kv=1&tv=-1"
            )
            $syncedText = $lyrics.lrc.lyric
            $plainText = $lyrics.tlyric.lyric
        } else {
            $trackName = [uri]::EscapeDataString($track.TrackName)
            $artistName = [uri]::EscapeDataString($track.ArtistName)
            $lyrics = Invoke-JsonUtf8 (
                "https://lrclib.net/api/get?track_name=$trackName&artist_name=$artistName"
            )
            $syncedText = $lyrics.syncedLyrics
            $plainText = $lyrics.plainLyrics
        }
        if ($syncedText) {
            $entries = New-Object System.Collections.Generic.List[object]
            foreach ($rawLine in ($syncedText -split "`n")) {
                $timeMatches = [regex]::Matches(
                    $rawLine,
                    '(?:\[|<)(\d{1,3}):(\d{2})(?:[\.:](\d{1,3}))?(?:\]|>)'
                )
                $clean = ($rawLine -replace '(?:\[\d{1,3}:\d{2}(?:[\.:]\d{1,3})?\]|<\d{1,3}:\d{2}(?:[\.:]\d{1,3})?>)', '').Trim()
                if ($timeMatches.Count -gt 0 -and -not [string]::IsNullOrWhiteSpace($clean)) {
                    foreach ($match in $timeMatches) {
                        $fraction = if ($match.Groups[3].Value) {
                            [double]("0." + $match.Groups[3].Value)
                        } else { 0 }
                        $entries.Add([PSCustomObject]@{
                            At = ([int]$match.Groups[1].Value * 60) +
                                 [int]$match.Groups[2].Value + $fraction
                            Text = $clean
                        })
                    }
                }
            }
            $script:lyricEntries = @($entries | Sort-Object At, Text -Unique)
            $script:lyricStartTime = Get-Date
            $script:lyricCurrentIndex = -1
            return (($script:lyricEntries | Select-Object -First 6).Text -join "`r`n")
        }
        if ($plainText) {
            $plainLines = @($plainText -split "`n" | ForEach-Object { $_.Trim() } | Where-Object {
                -not [string]::IsNullOrWhiteSpace($_) -and $_ -notmatch '^\[(ar|al|ti|by|offset):'
            })
            $script:lyricEntries = @(
                for ($i = 0; $i -lt $plainLines.Count; $i++) {
                    [PSCustomObject]@{ At = $i * 3; Text = $plainLines[$i].Trim() }
                }
            )
            $script:lyricStartTime = Get-Date
            $script:lyricCurrentIndex = -1
            return ($plainLines -join "`r`n")
        }
        $script:lyricEntries = @()
        return "这首歌暂时没有可用歌词。"
    } catch {
        $script:lyricEntries = @()
        return "歌词加载失败：$($_.Exception.Message)"
    }
}

function Set-LyricsMessage($message) {
    $lyricsPanel.Children.Clear()
    $script:lyricLineControls = @()
    $summaryLyricText.Text = $message
    $messageBlock = New-Object Windows.Controls.TextBlock
    $messageBlock.Text = $message
    $messageBlock.Foreground = [Windows.Media.Brushes]::LightGray
    $messageBlock.FontSize = 14
    $messageBlock.TextWrapping = [Windows.TextWrapping]::Wrap
    $messageBlock.Margin = "8,18,8,8"
    $lyricsPanel.Children.Add($messageBlock) | Out-Null
}

function Initialize-LyricsDisplay {
    $lyricsPanel.Children.Clear()
    $controls = New-Object System.Collections.Generic.List[object]
    foreach ($entry in $script:lyricEntries) {
        $line = New-Object Windows.Controls.TextBlock
        $line.Text = $entry.Text
        $line.TextWrapping = [Windows.TextWrapping]::Wrap
        $line.TextAlignment = [Windows.TextAlignment]::Center
        $line.FontSize = 14
        $line.Margin = "10,7,10,7"
        $line.Foreground = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromArgb(145, 190, 202, 224))
        $line.Background = [Windows.Media.Brushes]::Transparent
        $line.Opacity = 0.78
        $lyricsPanel.Children.Add($line) | Out-Null
        $controls.Add($line) | Out-Null
    }
    $script:lyricLineControls = @($controls.ToArray())
    $script:lyricCurrentIndex = -1
    $script:targetLyricsOffset = 0
    $summaryLyricText.Text = if ($script:lyricEntries.Count -gt 0) { "等待第一句…" } else { "暂无可用歌词" }
    $lyricsViewer.ScrollToVerticalOffset(0)
}

function Load-TrackObject($track) {
    $trackText.Text = $track.DisplayName
    $summaryTrackText.Text = $track.TrackName
    $summaryTrackText.ToolTip = $track.DisplayName
    $searchStatus.Text = "加载歌词..."
    $summaryLyricText.Text = "歌词加载中…"
    $lyricsResult = Get-LyricsText $track
    if ($script:lyricEntries.Count -gt 0) {
        Initialize-LyricsDisplay
        Update-LyricsDisplay
        $searchStatus.Text = "已加载"
    } else {
        Set-LyricsMessage $lyricsResult
        $searchStatus.Text = "暂无歌词"
    }
}

function Get-BuiltinRecommendSongs {
    @(
        [PSCustomObject]@{ TrackName = "青花瓷"; ArtistName = "周杰伦"; DisplayName = "青花瓷 - 周杰伦"; Source = "local"; Id = "0" }
        [PSCustomObject]@{ TrackName = "晴天"; ArtistName = "周杰伦"; DisplayName = "晴天 - 周杰伦"; Source = "local"; Id = "0" }
        [PSCustomObject]@{ TrackName = "稻香"; ArtistName = "周杰伦"; DisplayName = "稻香 - 周杰伦"; Source = "local"; Id = "0" }
        [PSCustomObject]@{ TrackName = "江南"; ArtistName = "林俊杰"; DisplayName = "江南 - 林俊杰"; Source = "local"; Id = "0" }
        [PSCustomObject]@{ TrackName = "修炼爱情"; ArtistName = "林俊杰"; DisplayName = "修炼爱情 - 林俊杰"; Source = "local"; Id = "0" }
        [PSCustomObject]@{ TrackName = "演员"; ArtistName = "薛之谦"; DisplayName = "演员 - 薛之谦"; Source = "local"; Id = "0" }
        [PSCustomObject]@{ TrackName = "认真的雪"; ArtistName = "薛之谦"; DisplayName = "认真的雪 - 薛之谦"; Source = "local"; Id = "0" }
        [PSCustomObject]@{ TrackName = "光年之外"; ArtistName = "邓紫棋"; DisplayName = "光年之外 - 邓紫棋"; Source = "local"; Id = "0" }
        [PSCustomObject]@{ TrackName = "泡沫"; ArtistName = "邓紫棋"; DisplayName = "泡沫 - 邓紫棋"; Source = "local"; Id = "0" }
        [PSCustomObject]@{ TrackName = "富士山下"; ArtistName = "陈奕迅"; DisplayName = "富士山下 - 陈奕迅"; Source = "local"; Id = "0" }
        [PSCustomObject]@{ TrackName = "十年"; ArtistName = "陈奕迅"; DisplayName = "十年 - 陈奕迅"; Source = "local"; Id = "0" }
        [PSCustomObject]@{ TrackName = "海阔天空"; ArtistName = "Beyond"; DisplayName = "海阔天空 - Beyond"; Source = "local"; Id = "0" }
        [PSCustomObject]@{ TrackName = "突然好想你"; ArtistName = "五月天"; DisplayName = "突然好想你 - 五月天"; Source = "local"; Id = "0" }
        [PSCustomObject]@{ TrackName = "温柔"; ArtistName = "五月天"; DisplayName = "温柔 - 五月天"; Source = "local"; Id = "0" }
        [PSCustomObject]@{ TrackName = "消愁"; ArtistName = "毛不易"; DisplayName = "消愁 - 毛不易"; Source = "local"; Id = "0" }
        [PSCustomObject]@{ TrackName = "平凡之路"; ArtistName = "朴树"; DisplayName = "平凡之路 - 朴树"; Source = "local"; Id = "0" }
        [PSCustomObject]@{ TrackName = "那些花儿"; ArtistName = "朴树"; DisplayName = "那些花儿 - 朴树"; Source = "local"; Id = "0" }
        [PSCustomObject]@{ TrackName = "理想三旬"; ArtistName = "陈鸿宇"; DisplayName = "理想三旬 - 陈鸿宇"; Source = "local"; Id = "0" }
        [PSCustomObject]@{ TrackName = "起风了"; ArtistName = "买辣椒也用券"; DisplayName = "起风了 - 买辣椒也用券"; Source = "local"; Id = "0" }
        [PSCustomObject]@{ TrackName = "红豆"; ArtistName = "王菲"; DisplayName = "红豆 - 王菲"; Source = "local"; Id = "0" }
        [PSCustomObject]@{ TrackName = "嘉宾"; ArtistName = "张远"; DisplayName = "嘉宾 - 张远"; Source = "local"; Id = "0" }
        [PSCustomObject]@{ TrackName = "跳楼机"; ArtistName = "LBI利比"; DisplayName = "跳楼机 - LBI利比"; Source = "local"; Id = "0" }
        [PSCustomObject]@{ TrackName = "告白气球"; ArtistName = "周杰伦"; DisplayName = "告白气球 - 周杰伦"; Source = "local"; Id = "0" }
        [PSCustomObject]@{ TrackName = "夜曲"; ArtistName = "周杰伦"; DisplayName = "夜曲 - 周杰伦"; Source = "local"; Id = "0" }
    )
}

function Get-RecommendPool {
    # 先保证本地歌单可用，再尝试在线补充
    $pool = New-Object System.Collections.ArrayList
    $seen = @{}
    foreach ($item in @(Get-BuiltinRecommendSongs)) {
        $key = "local-" + [string]$item.DisplayName
        if (-not $seen.ContainsKey($key)) {
            $seen[$key] = $true
            [void]$pool.Add($item)
        }
    }
    try {
        $response = Invoke-JsonUtf8 "https://music.163.com/api/personalized/newsong"
        foreach ($item in @($response.result)) {
            try {
                if ($null -eq $item -or $null -eq $item.song) { continue }
                $name = [string]$item.song.name
                if ([string]::IsNullOrWhiteSpace($name)) { continue }
                $idText = [string]$item.song.id
                if ($seen.ContainsKey($idText)) { continue }
                $seen[$idText] = $true
                $artist = "未知歌手"
                if ($item.song.artists) {
                    $artists = @($item.song.artists)
                    if ($artists.Count -gt 0) { $artist = [string]$artists[0].name }
                }
                [void]$pool.Add([PSCustomObject]@{
                    Id = $idText
                    TrackName = $name
                    ArtistName = $artist
                    Source = "netease"
                    DisplayName = ($name + " - " + $artist)
                })
            } catch {}
        }
    } catch {}

    $arr = @($pool.ToArray())
    if ($arr.Count -le 1) { return ,$arr }
    for ($i = $arr.Count - 1; $i -gt 0; $i--) {
        $j = Get-Random -Maximum ($i + 1)
        $tmp = $arr[$i]
        $arr[$i] = $arr[$j]
        $arr[$j] = $tmp
    }
    return ,$arr
}

function Resolve-RecommendTrack($picked) {
    $name = [string]$picked.TrackName
    $artist = [string]$picked.ArtistName
    $idText = [string]$picked.Id
    if ($picked.Source -eq "netease" -and $idText -and $idText -ne "0") {
        return [PSCustomObject]@{
            Id = $idText
            TrackName = $name
            ArtistName = $artist
            Source = "netease"
            DisplayName = ($name + " - " + $artist)
        }
    }

    $query = ($name + " " + $artist).Trim()
    $encodedQuery = [uri]::EscapeDataString($query)
    $response = Invoke-JsonUtf8 ("https://music.163.com/api/search/get/web?csrf_token=&s=" + $encodedQuery + "&type=1&offset=0&total=true&limit=5")
    $songs = @()
    if ($response -and $response.result -and $response.result.songs) {
        $songs = @($response.result.songs)
    }
    if ($songs.Count -eq 0) {
        $encodedQuery = [uri]::EscapeDataString($name)
        $response = Invoke-JsonUtf8 ("https://music.163.com/api/search/get/web?csrf_token=&s=" + $encodedQuery + "&type=1&offset=0&total=true&limit=5")
        if ($response -and $response.result -and $response.result.songs) {
            $songs = @($response.result.songs)
        }
    }
    if ($songs.Count -eq 0) { return $null }

    $item = $songs[0]
    $resolvedArtist = $artist
    if ($item.artists) {
        $artists = @($item.artists)
        if ($artists.Count -gt 0) { $resolvedArtist = [string]$artists[0].name }
    }
    return [PSCustomObject]@{
        Id = [string]$item.id
        TrackName = [string]$item.name
        ArtistName = $resolvedArtist
        Source = "netease"
        DisplayName = ([string]$item.name + " - " + $resolvedArtist)
    }
}

function Update-SongRecommendations {
    param([switch]$Online)
    try {
        if ($null -eq $recommendPanel -or $null -eq $recommendRefreshButton) { return }
        $recommendRefreshButton.IsEnabled = $false
        $searchStatus.Text = "刷新推荐中..."

        $all = @(Get-BuiltinRecommendSongs)
        if ($Online) {
            try {
                $online = @(Get-RecommendPool)
                if ($online.Count -gt 0) { $all = $online }
            } catch {}
        }

        if (-not $script:recommendOffset) { $script:recommendOffset = 0 }
        $script:recommendOffset = [int]$script:recommendOffset
        if ($script:recommendOffset -ge $all.Count) { $script:recommendOffset = 0 }

        $batch = New-Object System.Collections.ArrayList
        for ($n = 0; $n -lt 4 -and $n -lt $all.Count; $n++) {
            $idx = ($script:recommendOffset + $n) % $all.Count
            [void]$batch.Add($all[$idx])
        }
        $script:recommendOffset = ($script:recommendOffset + 4) % $all.Count
        $script:recommendPool = $all

        $recommendPanel.Children.Clear()
        foreach ($song in @($batch)) {
            $label = [string]$song.TrackName
            if ([string]::IsNullOrWhiteSpace($label)) { continue }
            if ($label.Length -gt 10) { $label = $label.Substring(0, 10) + "…" }
            $btn = New-Object Windows.Controls.Button
            $btn.Content = $label
            $btn.Margin = "0,0,6,4"
            $btn.Padding = "8,3"
            $btn.Background = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(42, 58, 86))
            $btn.Foreground = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(220, 229, 245))
            $btn.BorderThickness = 0
            $btn.FontSize = 11
            $btn.Cursor = [Windows.Input.Cursors]::Hand
            $btn.ToolTip = [string]$song.DisplayName
            $btn.Tag = $song
            $btn.add_Click({
                try {
                    $picked = $this.Tag
                    if ($null -eq $picked) { return }
                    $searchBox.Text = [string]$picked.TrackName
                    $searchStatus.Text = "加载推荐歌词..."
                    $resolved = Resolve-RecommendTrack $picked
                    if ($null -eq $resolved) {
                        $searchStatus.Text = "未找到该推荐歌曲"
                        return
                    }
                    Load-TrackObject $resolved
                } catch {
                    $searchStatus.Text = "推荐歌曲加载失败"
                }
            })
            [void]$recommendPanel.Children.Add($btn)
        }
        $searchStatus.Text = "已刷新推荐，点击歌名加载歌词"
    } catch {
        $searchStatus.Text = ("推荐失败：" + $_.Exception.Message)
    } finally {
        if ($null -ne $recommendRefreshButton) { $recommendRefreshButton.IsEnabled = $true }
    }
}

function Search-Music {
    $query = $searchBox.Text.Trim()
    if (-not $query) {
        $searchStatus.Text = "请输入歌名或歌手"
        return
    }
    if ($query.Length -lt 2) {
        $searchStatus.Text = "请输入至少 2 个字，例如：青花瓷"
        return
    }
    $searchButton.IsEnabled = $false
    $searchStatus.Text = "搜索中..."
    try {
        $encodedQuery = [uri]::EscapeDataString($query)
        $response = Invoke-JsonUtf8 "https://music.163.com/api/search/get/web?csrf_token=&s=$encodedQuery&type=1&offset=0&total=true&limit=10"
        $item = @($response.result.songs) | Select-Object -First 1
        $source = "netease"
        if ($null -eq $item) {
            $response = Invoke-JsonUtf8 "https://lrclib.net/api/search?q=$encodedQuery"
            $item = @($response) | Where-Object { $_.id -and ($_.trackName -or $_.name) } | Select-Object -First 1
            $source = "lrclib"
        }
        if ($null -eq $item) {
            $searchStatus.Text = "没有找到结果"
            $trackText.Text = "未找到歌曲"
            $script:lyricEntries = @()
            Set-LyricsMessage "请换一个歌名或歌手搜索。"
            return
        }
        if ($source -eq "netease") {
            $trackName = $item.name
            $artistName = $item.artists[0].name
            $trackId = [string]$item.id
        } else {
            $trackName = $item.trackName
            $artistName = $item.artistName
            $trackId = [string]$item.id
        }
        $track = [PSCustomObject]@{
            Id = $trackId
            TrackName = $trackName
            ArtistName = $artistName
            Source = $source
            DisplayName = ("{0} - {1}" -f $trackName, $artistName)
        }
        Load-TrackObject $track
    } catch {
        $searchStatus.Text = "搜索失败"
        $script:lyricEntries = @()
        Set-LyricsMessage "无法连接歌词服务，请检查网络后重试。"
    } finally {
        $searchButton.IsEnabled = $true
    }
}

$searchButton.Add_Click({ Search-Music })
$searchBox.Add_KeyDown({
    if ($_.Key -eq [System.Windows.Input.Key]::Enter) { Search-Music }
})
$recommendRefreshButton.Add_Click({
    try {
        Update-SongRecommendations -Online
    } catch {
        $searchStatus.Text = "推荐刷新失败"
    }
})
function Format-Duration([TimeSpan]$duration) {
    if ($duration.TotalSeconds -lt 0) { $duration = [TimeSpan]::Zero }
    return "{0:00}:{1:00}:{2:00}" -f [math]::Floor($duration.TotalHours), $duration.Minutes, $duration.Seconds
}

function Get-NextWorkStart([DateTime]$from) {
    $candidate = $from.Date.AddHours(9)
    if ($from -ge $candidate) { $candidate = $candidate.AddDays(1) }
    while ($candidate.DayOfWeek -eq [DayOfWeek]::Saturday -or $candidate.DayOfWeek -eq [DayOfWeek]::Sunday) {
        $candidate = $candidate.AddDays(1)
    }
    return $candidate
}

function Update-Clock {
    $now = Get-Date
    $clockText.Text = $now.ToString("HH:mm:ss")
    $summaryClockText.Text = $now.ToString("HH:mm")
    $dateText.Text = $now.ToString("yyyy 年 M 月 d 日  dddd", [Globalization.CultureInfo]::GetCultureInfo("zh-CN"))
    $time = $now.TimeOfDay
    $morningStart = [TimeSpan]::FromHours(9)
    $lunchStart = [TimeSpan]::FromHours(12)
    $afternoonStart = [TimeSpan]::FromMinutes(13 * 60 + 30)
    $workEnd = [TimeSpan]::FromHours(18)

    $isWeekend = $now.DayOfWeek -eq [DayOfWeek]::Saturday -or $now.DayOfWeek -eq [DayOfWeek]::Sunday
    if ($isWeekend) {
        $nextStart = Get-NextWorkStart $now
        $statusText.Text = "周末休息"
        $statusText.Foreground = [Windows.Media.Brushes]::LightSkyBlue
        $hintText.Text = ("下个工作日 {0:MM-dd HH:mm} 开始" -f $nextStart)
        $countdownText.Text = Format-Duration ($nextStart - $now)
    }
    elseif ($time -ge $morningStart -and $time -lt $lunchStart) {
        $statusText.Text = "上午工作中"
        $statusText.Foreground = [Windows.Media.Brushes]::LightGreen
        $hintText.Text = "距离午休 · 12:00"
        $countdownText.Text = Format-Duration ($lunchStart - $time)
    }
    elseif ($time -ge $lunchStart -and $time -lt $afternoonStart) {
        $statusText.Text = "午间休息"
        $statusText.Foreground = [Windows.Media.Brushes]::Gold
        $hintText.Text = "下午工作 · 13:30 开始"
        $countdownText.Text = Format-Duration ($afternoonStart - $time)
    }
    elseif ($time -ge $afternoonStart -and $time -lt $workEnd) {
        $statusText.Text = "下午工作中"
        $statusText.Foreground = [Windows.Media.Brushes]::LightGreen
        $hintText.Text = "距离下班 · 18:00"
        $countdownText.Text = Format-Duration ($workEnd - $time)
    }
    elseif ($time -lt $morningStart) {
        $statusText.Text = "等待上班"
        $statusText.Foreground = [Windows.Media.Brushes]::LightSkyBlue
        $hintText.Text = "上午工作 · 09:00 开始"
        $countdownText.Text = Format-Duration ($morningStart - $time)
    }
    else {
        $nextStart = Get-NextWorkStart $now
        $statusText.Text = "今日工作结束"
        $statusText.Foreground = [Windows.Media.Brushes]::LightSkyBlue
        $hintText.Text = ("下个工作日 {0:MM-dd HH:mm} 开始" -f $nextStart)
        $countdownText.Text = Format-Duration ($nextStart - $now)
    }
    $summaryCountdownText.Text = "剩余 " + $countdownText.Text
}

function Set-SummaryLyricLine([string]$text) {
    if ([string]::IsNullOrWhiteSpace($text)) { $text = "♪" }
    $summaryLyricText.BeginAnimation([Windows.UIElement]::OpacityProperty, $null)
    $summaryLyricText.Opacity = 1
    $summaryLyricText.Text = $text
    $fade = New-Object Windows.Media.Animation.DoubleAnimation
    $fade.From = 0.25
    $fade.To = 1.0
    $fade.Duration = [Windows.Duration]::new([TimeSpan]::FromMilliseconds(220))
    $fade.FillBehavior = [Windows.Media.Animation.FillBehavior]::Stop
    $summaryLyricText.BeginAnimation([Windows.UIElement]::OpacityProperty, $fade)
    if ($null -ne $summaryLyricTransform) {
        $summaryLyricTransform.BeginAnimation([Windows.Media.TranslateTransform]::YProperty, $null)
        $summaryLyricTransform.Y = 0
        $slide = New-Object Windows.Media.Animation.DoubleAnimation
        $slide.From = 5.0
        $slide.To = 0.0
        $slide.Duration = [Windows.Duration]::new([TimeSpan]::FromMilliseconds(220))
        $slide.FillBehavior = [Windows.Media.Animation.FillBehavior]::Stop
        $summaryLyricTransform.BeginAnimation([Windows.Media.TranslateTransform]::YProperty, $slide)
    }
}

function Update-LyricsDisplay {
    if ($script:lyricEntries.Count -eq 0 -or $script:lyricLineControls.Count -ne $script:lyricEntries.Count) { return }
    $elapsed = ((Get-Date) - $script:lyricStartTime).TotalSeconds
    $lastEntry = $script:lyricEntries[$script:lyricEntries.Count - 1]
    if ($elapsed -gt ($lastEntry.At + 6)) {
        $script:lyricStartTime = Get-Date
        $elapsed = 0
        $script:targetLyricsOffset = 0
    }
    $index = -1
    for ($i = 0; $i -lt $script:lyricEntries.Count; $i++) {
        if ($script:lyricEntries[$i].At -le $elapsed) { $index = $i } else { break }
    }
    if ($index -eq $script:lyricCurrentIndex) { return }
    $previousIndex = $script:lyricCurrentIndex
    $script:lyricCurrentIndex = $index

    if ($previousIndex -ge 0 -and $previousIndex -lt $script:lyricLineControls.Count) {
        $previous = $script:lyricLineControls[$previousIndex]
        $previous.Foreground = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromArgb(145, 190, 202, 224))
        $previous.FontWeight = [Windows.FontWeights]::Normal
        $previous.Background = [Windows.Media.Brushes]::Transparent
        $previous.Opacity = 0.78
    }
    if ($index -lt 0) {
        Set-SummaryLyricLine "等待第一句…"
        return
    }

    $currentLine = $script:lyricLineControls[$index]
    Set-SummaryLyricLine $script:lyricEntries[$index].Text
    $currentLine.Foreground = [Windows.Media.Brushes]::White
    $currentLine.FontWeight = [Windows.FontWeights]::SemiBold
    $currentLine.Background = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromArgb(105, 72, 102, 168))
    $currentLine.Opacity = 1

    # 仅更新两行样式，避免每句歌词都重建整棵视觉树。
    try {
        $lyricsPanel.UpdateLayout()
        $point = $currentLine.TransformToAncestor($lyricsViewer).Transform((New-Object Windows.Point(0, 0)))
        $desired = $lyricsViewer.VerticalOffset + $point.Y + ($currentLine.ActualHeight / 2) - ($lyricsViewer.ViewportHeight / 2)
        $script:targetLyricsOffset = [math]::Max(0, [math]::Min($lyricsViewer.ScrollableHeight, $desired))
    } catch {
        $script:targetLyricsOffset = [math]::Max(0, $index * 30 - $lyricsViewer.ViewportHeight / 2)
    }
}

$timer = New-Object Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromSeconds(1)
$timer.Add_Tick({
    Update-Clock
    # 每分钟检查一次开收盘显示窗口，避免卡在临界点
    if ((Get-Date).Second -eq 0) { Update-CompactLayout }
})
Update-Clock
$timer.Start()

$lyricsScrollTimer = New-Object Windows.Threading.DispatcherTimer
$lyricsScrollTimer.Interval = [TimeSpan]::FromMilliseconds(50)
$lyricsScrollTimer.Add_Tick({
    Update-LyricsDisplay
})
$lyricsScrollTimer.Start()

$script:lyricsRenderingHandler = [EventHandler]{
    $nowFrame = [DateTime]::UtcNow
    $frameSeconds = [math]::Min(0.05, ($nowFrame - $script:lastLyricsFrame).TotalSeconds)
    $script:lastLyricsFrame = $nowFrame
    $difference = $script:targetLyricsOffset - $lyricsViewer.VerticalOffset
    if ([math]::Abs($difference) -gt 0.08) {
        # 与帧率无关的指数缓动，60/120Hz 屏幕都保持同样手感。
        $ease = 1 - [math]::Exp(-10 * $frameSeconds)
        $lyricsViewer.ScrollToVerticalOffset($lyricsViewer.VerticalOffset + ($difference * $ease))
    } elseif ([math]::Abs($difference) -gt 0) {
        $lyricsViewer.ScrollToVerticalOffset($script:targetLyricsOffset)
    }
}
[Windows.Media.CompositionTarget]::add_Rendering($script:lyricsRenderingHandler)

$stockNetworkTimer = New-Object Windows.Threading.DispatcherTimer
$stockNetworkTimer.Interval = [TimeSpan]::FromMilliseconds(100)
$stockNetworkTimer.Add_Tick({ Complete-StockDownload })
$stockNetworkTimer.Start()

$stockTimer = New-Object Windows.Threading.DispatcherTimer
$stockTimer.Interval = [TimeSpan]::FromSeconds(30)
$stockTimer.Add_Tick({ Request-StockQuoteAsync })
$stockChartHost.Add_SizeChanged({
    if ($script:stockPrices.Count -gt 1) {
        Draw-StockChart -prices $script:stockPrices -prevClose $script:stockPrevClose
    }
})
$window.Add_SizeChanged({
    Update-CompactLayout
    if ($script:stockPrices.Count -gt 1) { Draw-StockChartSafe }
})
$window.Add_ContentRendered({
    Update-CompactLayout
    Request-StockQuoteAsync
    Update-SongRecommendations
})
$stockTimer.Start()

$window.Add_Closed({ $timer.Stop() })
$window.Add_Closed({ $lyricsScrollTimer.Stop() })
$window.Add_Closed({ $stockTimer.Stop() })
$window.Add_Closed({ $chromeHideTimer.Stop(); $chromeCollapseTimer.Stop() })
$window.Add_Closed({
    $stockNetworkTimer.Stop()
    if ($null -ne $script:stockNetworkClient) {
        try { $script:stockNetworkClient.CancelAsync() } catch {}
        $script:stockNetworkClient.Dispose()
        $script:stockNetworkClient = $null
    }
})
$window.Add_Closed({ [Windows.Media.CompositionTarget]::remove_Rendering($script:lyricsRenderingHandler) })
$window.Add_Closed({
    if ($null -ne $script:hwndSource -and $null -ne $script:resizeHook) {
        $script:hwndSource.RemoveHook($script:resizeHook)
    }
})
$window.ShowDialog() | Out-Null
