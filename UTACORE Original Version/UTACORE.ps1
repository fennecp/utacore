[CmdletBinding()]
param(
    [string]$ConfigPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$ScriptRootPath = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$UtacoreLogoPngPath = Join-Path $ScriptRootPath 'UTACORE.png'
$UtacoreIconPath = Join-Path $ScriptRootPath 'UTACORE.ico'

function Test-HexColor {
    param([string]$Value)

    return $Value -match '^#(?:[0-9A-Fa-f]{6})$'
}

function Get-DefaultInstallFolderName {
    param([string]$VoicebankName)

    if ([string]::IsNullOrWhiteSpace($VoicebankName)) {
        return 'Voicebank'
    }

    $invalidCharacters = [System.IO.Path]::GetInvalidFileNameChars()
    $builder = New-Object System.Text.StringBuilder

    foreach ($character in $VoicebankName.ToCharArray()) {
        if ($invalidCharacters -contains $character) {
            [void]$builder.Append('_')
        }
        else {
            [void]$builder.Append($character)
        }
    }

    return $builder.ToString().Trim()
}

function New-InstallerScriptContent {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Config
    )

    $configJson = $Config | ConvertTo-Json -Depth 5 -Compress
    $configBase64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($configJson))

    $template = @'
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms

$ErrorActionPreference = 'Stop'

function Show-ErrorDialog {
    param([string]$Message)

    [System.Windows.MessageBox]::Show(
        $Message,
        'Installer Error',
        [System.Windows.MessageBoxButton]::OK,
        [System.Windows.MessageBoxImage]::Error
    ) | Out-Null
}

function Show-InfoDialog {
    param([string]$Message)

    [System.Windows.MessageBox]::Show(
        $Message,
        'Installer',
        [System.Windows.MessageBoxButton]::OK,
        [System.Windows.MessageBoxImage]::Information
    ) | Out-Null
}

function Get-BrushFromHex {
    param([string]$Hex)

    try {
        return [System.Windows.Media.BrushConverter]::new().ConvertFromString($Hex)
    }
    catch {
        return [System.Windows.Media.Brushes]::SteelBlue
    }
}

function Get-LightBrushFromHex {
    param([string]$Hex)

    try {
        $color = [System.Windows.Media.ColorConverter]::ConvertFromString($Hex)
        $lightColor = [System.Windows.Media.Color]::FromRgb(
            [byte][Math]::Min(255, $color.R + 34),
            [byte][Math]::Min(255, $color.G + 34),
            [byte][Math]::Min(255, $color.B + 34)
        )
        return [System.Windows.Media.SolidColorBrush]::new($lightColor)
    }
    catch {
        return [System.Windows.Media.Brushes]::LightSteelBlue
    }
}

function Read-TextFileUtf8 {
    param([string]$Path)

    return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
}

try {
    $configJson = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('__CONFIG_BASE64__'))
    $config = $configJson | ConvertFrom-Json

    $bundleRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
    $voicebankArchive = Join-Path $bundleRoot 'voicebank.zip'
    $characterImagePath = Join-Path $bundleRoot $config.CharacterImageFileName
    $videoPath = if ($config.HasIntroVideo) { Join-Path $bundleRoot $config.IntroVideoFileName } else { $null }
    $termsPath = Join-Path $bundleRoot 'terms.txt'
    $appIconPath = Join-Path $bundleRoot 'utacore-icon.ico'

    $accentBrush = Get-BrushFromHex -Hex $config.AccentColor
    $lightAccentBrush = Get-LightBrushFromHex -Hex $config.AccentColor
    $defaultInstallRoot = Join-Path $env:USERPROFILE 'Documents\UTAU Voicebanks'
    $defaultInstallPath = Join-Path $defaultInstallRoot $config.DefaultFolderName

    $xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="UTACORE Installer"
        Width="980"
        Height="700"
        WindowStartupLocation="CenterScreen"
        ResizeMode="NoResize"
        WindowStyle="None"
        WindowState="Maximized"
        Topmost="True"
        Background="Black">
    <Grid Margin="0">
        <Grid.RowDefinitions>
            <RowDefinition x:Name="HeaderRow" Height="Auto" />
            <RowDefinition Height="*" />
        </Grid.RowDefinitions>

        <Border x:Name="HeaderBar"
                Grid.Row="0"
                Background="#2D5C88"
                Padding="24">
            <StackPanel>
                <TextBlock x:Name="HeaderTitle"
                           Text=""
                           FontSize="28"
                           FontWeight="Bold"
                           Foreground="White" />
                <TextBlock x:Name="HeaderSubtitle"
                           Text=""
                           FontSize="15"
                           Foreground="#F4F7FB"
                           Margin="0,6,0,0" />
            </StackPanel>
        </Border>

        <Grid Grid.Row="1">
            <Grid x:Name="SplashView" Visibility="Visible" Background="Black">
                <MediaElement x:Name="IntroVideo"
                              Stretch="Uniform"
                              LoadedBehavior="Manual"
                              UnloadedBehavior="Stop" />
                <Button x:Name="SkipVideoButton"
                        Content="Skip Video"
                        Width="132"
                        Height="38"
                        FontWeight="SemiBold"
                        HorizontalAlignment="Right"
                        VerticalAlignment="Top"
                        Margin="0,24,24,0"
                        Visibility="Collapsed" />
            </Grid>

            <Grid x:Name="InstallerView" Visibility="Collapsed" Margin="24">
                <Grid.RowDefinitions>
                    <RowDefinition Height="*" />
                    <RowDefinition Height="Auto" />
                </Grid.RowDefinitions>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="290" />
                    <ColumnDefinition Width="24" />
                    <ColumnDefinition Width="*" />
                </Grid.ColumnDefinitions>

                <Border Grid.Row="0"
                        Grid.Column="0"
                        CornerRadius="18"
                        Background="White"
                        Padding="18">
                    <StackPanel>
                        <Border CornerRadius="14"
                                BorderThickness="1"
                                BorderBrush="#DDDDDD"
                                Background="#FCFCFC"
                                Padding="8">
                            <Image x:Name="CharacterImage"
                                   Height="330"
                                   Stretch="Uniform" />
                        </Border>
                        <TextBlock x:Name="InfoAuthor"
                                   Margin="0,16,0,0"
                                   FontWeight="Bold"
                                   FontSize="15"
                                   Foreground="#333333" />
                    </StackPanel>
                </Border>

                <Border Grid.Row="0"
                        Grid.Column="2"
                        CornerRadius="18"
                        Background="White"
                        Padding="0">
                    <ScrollViewer VerticalScrollBarVisibility="Auto">
                        <StackPanel Margin="24">
                            <TextBlock Text="Voicebank Information"
                                       FontSize="24"
                                       FontWeight="Bold"
                                       Foreground="#222222" />
                            <TextBlock x:Name="InfoName"
                                       Margin="0,10,0,0"
                                       FontSize="18"
                                       FontWeight="SemiBold"
                                       Foreground="#404040" />

                            <Border Margin="0,18,0,18"
                                    Padding="0"
                                    CornerRadius="14"
                                    Background="#F7F9FC"
                                    BorderThickness="1"
                                    BorderBrush="#E1E7EF">
                                <TextBlock x:Name="InfoDescription"
                                           Padding="18"
                                           TextWrapping="Wrap"
                                           FontSize="14"
                                           Foreground="#333333" />
                            </Border>

                            <TextBlock Text="Install Location"
                                       FontSize="16"
                                       FontWeight="Bold"
                                       Foreground="#222222" />
                            <TextBlock Text="Choose the folder where this voicebank should be extracted."
                                       FontSize="13"
                                       Foreground="#666666"
                                       Margin="0,4,0,12" />
                            <Grid>
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="*" />
                                    <ColumnDefinition Width="12" />
                                    <ColumnDefinition Width="150" />
                                </Grid.ColumnDefinitions>
                                <TextBox x:Name="InstallPathTextBox"
                                         Grid.Column="0"
                                         Height="38"
                                         Padding="10,8,10,8"
                                         VerticalContentAlignment="Center" />
                                <Button x:Name="BrowseButton"
                                        Grid.Column="2"
                                        Content="Browse..."
                                        Height="38"
                                        FontWeight="SemiBold" />
                            </Grid>

                            <TextBlock x:Name="InstallStatus"
                                       Margin="0,18,0,0"
                                       FontSize="13"
                                       Foreground="#555555"
                                       Text="Ready to install." />

                            <StackPanel Orientation="Horizontal"
                                        HorizontalAlignment="Right"
                                        Margin="0,22,0,0">
                                <Button x:Name="InstallButton"
                                        Content="Start Install"
                                        Width="150"
                                        Height="42"
                                        FontWeight="Bold" />
                            </StackPanel>
                        </StackPanel>
                    </ScrollViewer>
                </Border>
            </Grid>

            <Grid x:Name="TermsView" Visibility="Collapsed" Margin="24">
                <Border CornerRadius="24"
                        Background="White"
                        Padding="28">
                    <Grid>
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto" />
                            <RowDefinition Height="*" />
                            <RowDefinition Height="Auto" />
                        </Grid.RowDefinitions>
                        <TextBlock Text="Terms of Service"
                                   FontSize="28"
                                   FontWeight="Bold"
                                   Foreground="#222222" />
                        <TextBox x:Name="TermsTextBox"
                                 Grid.Row="1"
                                 Margin="0,18,0,18"
                                 IsReadOnly="True"
                                 TextWrapping="Wrap"
                                 VerticalScrollBarVisibility="Auto"
                                 HorizontalScrollBarVisibility="Disabled"
                                 FontSize="14"
                                 Padding="14"
                                 Background="#F8F8FA"
                                 BorderBrush="#D9DCE2" />
                        <StackPanel Grid.Row="2"
                                    Orientation="Horizontal"
                                    HorizontalAlignment="Right">
                            <Button x:Name="DisagreeButton"
                                    Content="Disagree"
                                    Width="140"
                                    Height="40"
                                    FontWeight="SemiBold"
                                    Margin="0,0,12,0" />
                            <Button x:Name="AgreeButton"
                                    Content="Agree"
                                    Width="140"
                                    Height="40"
                                    FontWeight="Bold" />
                        </StackPanel>
                    </Grid>
                </Border>
            </Grid>

            <Grid x:Name="CompleteView" Visibility="Collapsed" Margin="24">
                <Border CornerRadius="24"
                        Background="White"
                        Padding="36"
                        HorizontalAlignment="Center"
                        VerticalAlignment="Center"
                        MaxWidth="620">
                    <StackPanel>
                        <TextBlock Text="Installation Finished"
                                   FontSize="30"
                                   FontWeight="Bold"
                                   Foreground="#222222"
                                   HorizontalAlignment="Center" />
                        <TextBlock x:Name="CompleteMessage"
                                   Margin="0,18,0,0"
                                   FontSize="15"
                                   TextWrapping="Wrap"
                                   TextAlignment="Center"
                                   Foreground="#444444" />
                        <Button x:Name="CloseButton"
                                Content="Close"
                                Width="150"
                                Height="42"
                                FontWeight="Bold"
                                HorizontalAlignment="Center"
                                Margin="0,28,0,0" />
                    </StackPanel>
                </Border>
            </Grid>

            <Grid x:Name="DeclinedView" Visibility="Collapsed" Margin="24">
                <Border CornerRadius="24"
                        Background="White"
                        Padding="36"
                        HorizontalAlignment="Center"
                        VerticalAlignment="Center"
                        MaxWidth="620">
                    <StackPanel>
                        <TextBlock Text="Installation Cancelled"
                                   FontSize="30"
                                   FontWeight="Bold"
                                   Foreground="#222222"
                                   HorizontalAlignment="Center" />
                        <TextBlock Text="You did not agree to the terms. You may close this window."
                                   Margin="0,18,0,0"
                                   FontSize="15"
                                   TextWrapping="Wrap"
                                   TextAlignment="Center"
                                   Foreground="#444444" />
                        <Button x:Name="DeclinedCloseButton"
                                Content="Close"
                                Width="150"
                                Height="42"
                                FontWeight="Bold"
                                HorizontalAlignment="Center"
                                Margin="0,28,0,0" />
                    </StackPanel>
                </Border>
            </Grid>
        </Grid>
    </Grid>
</Window>
"@

    $reader = New-Object System.Xml.XmlNodeReader ([xml]$xaml)
    $window = [Windows.Markup.XamlReader]::Load($reader)

    $headerBar = $window.FindName('HeaderBar')
    $headerRow = $window.FindName('HeaderRow')
    $headerBar.Background = $accentBrush
    if (Test-Path -LiteralPath $appIconPath) {
        $window.Icon = [Uri]::new($appIconPath)
    }
    $headerTitle = $window.FindName('HeaderTitle')
    $headerTitle.Text = $config.VoicebankName
    $headerSubtitle = $window.FindName('HeaderSubtitle')
    $headerSubtitle.Text = $config.CharacterName

    $splashView = $window.FindName('SplashView')
    $installerView = $window.FindName('InstallerView')
    $termsView = $window.FindName('TermsView')
    $completeView = $window.FindName('CompleteView')
    $declinedView = $window.FindName('DeclinedView')
    $introVideo = $window.FindName('IntroVideo')
    $skipVideoButton = $window.FindName('SkipVideoButton')
    $characterImage = $window.FindName('CharacterImage')
    $infoAuthor = $window.FindName('InfoAuthor')
    $infoName = $window.FindName('InfoName')
    $infoDescription = $window.FindName('InfoDescription')
    $installPathTextBox = $window.FindName('InstallPathTextBox')
    $browseButton = $window.FindName('BrowseButton')
    $installStatus = $window.FindName('InstallStatus')
    $installButton = $window.FindName('InstallButton')
    $termsTextBox = $window.FindName('TermsTextBox')
    $agreeButton = $window.FindName('AgreeButton')
    $disagreeButton = $window.FindName('DisagreeButton')
    $completeMessage = $window.FindName('CompleteMessage')
    $closeButton = $window.FindName('CloseButton')
    $declinedCloseButton = $window.FindName('DeclinedCloseButton')

    $skipVideoButton.Background = $lightAccentBrush
    $skipVideoButton.Foreground = [System.Windows.Media.Brushes]::White
    $skipVideoButton.BorderBrush = $accentBrush
    $browseButton.Background = $lightAccentBrush
    $browseButton.Foreground = [System.Windows.Media.Brushes]::White
    $browseButton.BorderBrush = $accentBrush
    $agreeButton.Background = $accentBrush
    $agreeButton.Foreground = [System.Windows.Media.Brushes]::White
    $agreeButton.BorderBrush = $accentBrush
    $disagreeButton.Background = $lightAccentBrush
    $disagreeButton.Foreground = [System.Windows.Media.Brushes]::White
    $disagreeButton.BorderBrush = $accentBrush
    $installButton.Background = $accentBrush
    $installButton.Foreground = [System.Windows.Media.Brushes]::White
    $installButton.BorderBrush = $accentBrush
    $closeButton.Background = $accentBrush
    $closeButton.Foreground = [System.Windows.Media.Brushes]::White
    $closeButton.BorderBrush = $accentBrush
    $declinedCloseButton.Background = $accentBrush
    $declinedCloseButton.Foreground = [System.Windows.Media.Brushes]::White
    $declinedCloseButton.BorderBrush = $accentBrush

    $infoName.Text = $config.VoicebankName
    $infoAuthor.Text = "Character: $($config.CharacterName)`nCreator: $($config.CreatorName)"
    $infoDescription.Text = $config.Description
    $installPathTextBox.Text = $defaultInstallPath

    if (Test-Path -LiteralPath $characterImagePath) {
        $bitmap = New-Object System.Windows.Media.Imaging.BitmapImage
        $bitmap.BeginInit()
        $bitmap.UriSource = [Uri]::new($characterImagePath)
        $bitmap.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
        $bitmap.EndInit()
        $characterImage.Source = $bitmap
    }

    if ($config.HasTermsOfService -and (Test-Path -LiteralPath $termsPath)) {
        $termsTextBox.Text = Read-TextFileUtf8 -Path $termsPath
    }

    $showInstaller = {
        $introVideo.Stop()
        $window.Title = $config.WindowTitle
        $window.Topmost = $false
        $window.WindowState = [System.Windows.WindowState]::Normal
        $window.WindowStyle = [System.Windows.WindowStyle]::SingleBorderWindow
        $window.ResizeMode = [System.Windows.ResizeMode]::CanMinimize
        $window.Width = 980
        $window.Height = 700
        $window.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#F6F6F8')
        $workArea = [System.Windows.SystemParameters]::WorkArea
        $window.Left = $workArea.Left + (($workArea.Width - $window.Width) / 2)
        $window.Top = $workArea.Top + (($workArea.Height - $window.Height) / 2)
        $headerRow.Height = [System.Windows.GridLength]::Auto
        $headerBar.Visibility = [System.Windows.Visibility]::Visible
        $splashView.Visibility = [System.Windows.Visibility]::Collapsed
        $termsView.Visibility = [System.Windows.Visibility]::Collapsed
        $installerView.Visibility = [System.Windows.Visibility]::Visible
        $completeView.Visibility = [System.Windows.Visibility]::Collapsed
        $declinedView.Visibility = [System.Windows.Visibility]::Collapsed
    }

    $showCompleteView = {
        param($finalPath)

        $installerView.Visibility = [System.Windows.Visibility]::Collapsed
        $termsView.Visibility = [System.Windows.Visibility]::Collapsed
        $completeView.Visibility = [System.Windows.Visibility]::Visible
        $declinedView.Visibility = [System.Windows.Visibility]::Collapsed
        $completeMessage.Text = "The voicebank was installed successfully to:`n$finalPath`n`nYou can close this window now."
    }

    $showTermsOrInstaller = {
        $introVideo.Stop()
        $window.Title = $config.WindowTitle
        $window.Topmost = $false
        $window.WindowState = [System.Windows.WindowState]::Normal
        $window.WindowStyle = [System.Windows.WindowStyle]::SingleBorderWindow
        $window.ResizeMode = [System.Windows.ResizeMode]::CanMinimize
        $window.Width = 980
        $window.Height = 700
        $window.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#F6F6F8')
        $workArea = [System.Windows.SystemParameters]::WorkArea
        $window.Left = $workArea.Left + (($workArea.Width - $window.Width) / 2)
        $window.Top = $workArea.Top + (($workArea.Height - $window.Height) / 2)
        $headerRow.Height = [System.Windows.GridLength]::Auto
        $headerBar.Visibility = [System.Windows.Visibility]::Visible
        $splashView.Visibility = [System.Windows.Visibility]::Collapsed
        $completeView.Visibility = [System.Windows.Visibility]::Collapsed
        $declinedView.Visibility = [System.Windows.Visibility]::Collapsed
        if ($config.HasTermsOfService) {
            $termsView.Visibility = [System.Windows.Visibility]::Visible
            $installerView.Visibility = [System.Windows.Visibility]::Collapsed
        }
        else {
            $termsView.Visibility = [System.Windows.Visibility]::Collapsed
            $installerView.Visibility = [System.Windows.Visibility]::Visible
        }
    }

    $skipVideoButton.Add_Click($showTermsOrInstaller)
    $introVideo.Add_MediaEnded($showTermsOrInstaller)
    $introVideo.Add_MediaFailed({
        $window.Dispatcher.InvokeAsync($showTermsOrInstaller, [System.Windows.Threading.DispatcherPriority]::Background) | Out-Null
    })
    $agreeButton.Add_Click({
        & $showInstaller
    })
    $disagreeButton.Add_Click({
        $termsView.Visibility = [System.Windows.Visibility]::Collapsed
        $installerView.Visibility = [System.Windows.Visibility]::Collapsed
        $completeView.Visibility = [System.Windows.Visibility]::Collapsed
        $declinedView.Visibility = [System.Windows.Visibility]::Visible
    })
    $closeButton.Add_Click({
        $window.Close()
    })
    $declinedCloseButton.Add_Click({
        $window.Close()
    })

    $skipTimer = [System.Windows.Threading.DispatcherTimer]::new()
    $skipTimer.Interval = [TimeSpan]::FromSeconds(3)
    $skipTimer.Add_Tick({
        $skipTimer.Stop()
        $skipVideoButton.Visibility = [System.Windows.Visibility]::Visible
    })

    $browseButton.Add_Click({
        try {
            $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
            $dialog.Description = 'Select the folder to install the voicebank into.'
            $dialog.ShowNewFolderButton = $true

            if (-not [string]::IsNullOrWhiteSpace($installPathTextBox.Text) -and (Test-Path -LiteralPath $installPathTextBox.Text)) {
                $dialog.SelectedPath = $installPathTextBox.Text
            }

            if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                $installPathTextBox.Text = $dialog.SelectedPath
            }
        }
        catch {
            Show-ErrorDialog -Message $_.Exception.Message
        }
    })

    $installButton.Add_Click({
        $destinationPath = $installPathTextBox.Text.Trim()

        if ([string]::IsNullOrWhiteSpace($destinationPath)) {
            Show-ErrorDialog -Message 'Please choose an install folder first.'
            return
        }

        try {
            $installButton.IsEnabled = $false
            $browseButton.IsEnabled = $false
            $installStatus.Text = 'Installing voicebank...'
            $window.Dispatcher.Invoke([Action] {}, [System.Windows.Threading.DispatcherPriority]::Render)

            $installFolderPath = Join-Path $destinationPath $config.DefaultFolderName
            [System.IO.Directory]::CreateDirectory($installFolderPath) | Out-Null
            Expand-Archive -LiteralPath $voicebankArchive -DestinationPath $installFolderPath -Force

            $installedItems = Get-ChildItem -LiteralPath $installFolderPath -Force -ErrorAction SilentlyContinue
            if (-not $installedItems) {
                throw 'The archive did not extract any files to the selected folder.'
            }

            $installStatus.Text = "Install complete: $installFolderPath"
            & $showCompleteView $installFolderPath
        }
        catch {
            $installStatus.Text = 'Installation failed.'
            Show-ErrorDialog -Message $_.Exception.Message
        }
        finally {
            $installButton.IsEnabled = $true
            $browseButton.IsEnabled = $true
        }
    })

    if ($config.HasIntroVideo -and $videoPath -and (Test-Path -LiteralPath $videoPath)) {
        $headerRow.Height = [System.Windows.GridLength]::new(0)
        $headerBar.Visibility = [System.Windows.Visibility]::Collapsed
        $introVideo.Source = [Uri]::new($videoPath)
        $skipTimer.Start()
        $introVideo.Play()
    }
    else {
        & $showTermsOrInstaller
    }

    [void]$window.ShowDialog()
}
catch {
    Show-ErrorDialog -Message $_.Exception.Message
}
'@

    return $template.Replace('__CONFIG_BASE64__', $configBase64)
}

function New-LauncherVbsContent {
    return @'
Set shell = CreateObject("WScript.Shell")
scriptPath = Replace(WScript.ScriptFullName, "LaunchInstaller.vbs", "RunInstaller.ps1")
command = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -STA -File " & Chr(34) & scriptPath & Chr(34)
shell.Run command, 0, True
'@
}

function New-IExpressSedContent {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceDirectory,

        [Parameter(Mandatory = $true)]
        [string]$OutputExePath,

        [Parameter(Mandatory = $true)]
        [string]$FriendlyName,

        [Parameter(Mandatory = $true)]
        [string]$CharacterImageFileName,

        [string]$IntroVideoFileName,

        [string]$AppIconFileName
    )

    $escapedSourceDirectory = $SourceDirectory.TrimEnd('\') + '\'
    $escapedOutputExePath = $OutputExePath

    return @"
[Version]
Class=IEXPRESS
SEDVersion=3
[Options]
PackagePurpose=InstallApp
ShowInstallProgramWindow=0
HideExtractAnimation=1
UseLongFileName=1
InsideCompressed=1
CAB_FixedSize=0
CAB_ResvCodeSigning=0
RebootMode=N
InstallPrompt=
DisplayLicense=
FinishMessage=
TargetName=$escapedOutputExePath
FriendlyName=$FriendlyName
AppLaunched=wscript.exe LaunchInstaller.vbs
PostInstallCmd=<None>
AdminQuietInstCmd=
UserQuietInstCmd=
SourceFiles=SourceFiles
[Strings]
FILE0=LaunchInstaller.vbs
FILE1=RunInstaller.ps1
FILE2=voicebank.zip
FILE3=$CharacterImageFileName
FILE4=$IntroVideoFileName
FILE5=terms.txt
FILE6=$AppIconFileName
[SourceFiles]
SourceFiles0=$escapedSourceDirectory
[SourceFiles0]
%FILE0%=
%FILE1%=
%FILE2%=
%FILE3%=
%FILE4%=
%FILE5%=
%FILE6%=
"@
}

function New-VoicebankInstallerPackage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$VoicebankZipPath,

        [Parameter(Mandatory = $true)]
        [string]$CharacterImagePath,

        [string]$IntroVideoPath,

        [string]$TermsTextPath,

        [Parameter(Mandatory = $true)]
        [string]$OutputExePath,

        [Parameter(Mandatory = $true)]
        [string]$VoicebankName,

        [Parameter(Mandatory = $true)]
        [string]$CharacterName,

        [Parameter(Mandatory = $true)]
        [string]$CreatorName,

        [Parameter(Mandatory = $true)]
        [string]$Description,

        [string]$AccentColor = '#2D5C88',

        [string]$ProgressFilePath,

        [string]$LogFilePath
    )

    function Write-BuildProgress {
        param(
            [int]$Percent,
            [string]$Message
        )

        if ($ProgressFilePath) {
            @{ percent = $Percent; message = $Message } | ConvertTo-Json -Compress | Set-Content -LiteralPath $ProgressFilePath -Encoding UTF8
        }

        if ($LogFilePath) {
            $timestamp = Get-Date -Format 'HH:mm:ss'
            Add-Content -LiteralPath $LogFilePath -Value "[$timestamp] $Message"
        }
    }

    Write-BuildProgress -Percent 5 -Message 'Validating selected files...'

    if (-not (Test-Path -LiteralPath $VoicebankZipPath -PathType Leaf)) {
        throw "Voicebank archive not found: $VoicebankZipPath"
    }

    if (-not (Test-Path -LiteralPath $CharacterImagePath -PathType Leaf)) {
        throw "Character image not found: $CharacterImagePath"
    }

    if (-not [string]::IsNullOrWhiteSpace($IntroVideoPath) -and -not (Test-Path -LiteralPath $IntroVideoPath -PathType Leaf)) {
        throw "Intro video not found: $IntroVideoPath"
    }

    if (-not [string]::IsNullOrWhiteSpace($TermsTextPath) -and -not (Test-Path -LiteralPath $TermsTextPath -PathType Leaf)) {
        throw "Terms of service file not found: $TermsTextPath"
    }

    if ([string]::IsNullOrWhiteSpace($AccentColor)) {
        $AccentColor = '#2D5C88'
    }

    if ([string]::IsNullOrWhiteSpace($VoicebankName)) {
        throw 'Voicebank name is required.'
    }

    if ([string]::IsNullOrWhiteSpace($CharacterName)) {
        throw 'Character name is required.'
    }

    if ([string]::IsNullOrWhiteSpace($CreatorName)) {
        throw 'Creator name is required.'
    }

    if (-not (Test-HexColor -Value $AccentColor)) {
        throw 'Accent color must use the format #RRGGBB.'
    }

    $outputDirectory = Split-Path -Parent $OutputExePath
    if ([string]::IsNullOrWhiteSpace($outputDirectory)) {
        throw 'Please choose a valid output path for the installer exe.'
    }

    [System.IO.Directory]::CreateDirectory($outputDirectory) | Out-Null

    $buildRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("UtauVoicebankInstallerMaker_" + [guid]::NewGuid().ToString('N'))
    [System.IO.Directory]::CreateDirectory($buildRoot) | Out-Null

    try {
        Write-BuildProgress -Percent 12 -Message 'Preparing temporary build workspace...'
        $imageExtension = [System.IO.Path]::GetExtension($CharacterImagePath)
        $hasIntroVideo = -not [string]::IsNullOrWhiteSpace($IntroVideoPath)
        $hasTermsOfService = -not [string]::IsNullOrWhiteSpace($TermsTextPath)
        $videoExtension = if ($hasIntroVideo) { [System.IO.Path]::GetExtension($IntroVideoPath) } else { '.txt' }
        $imageFileName = "character_image$imageExtension"
        $videoFileName = "intro_video$videoExtension"
        $appIconFileName = 'utacore-icon.ico'

        Write-BuildProgress -Percent 22 -Message 'Copying voicebank archive and media into the build workspace...'
        Copy-Item -LiteralPath $VoicebankZipPath -Destination (Join-Path $buildRoot 'voicebank.zip') -Force
        Copy-Item -LiteralPath $CharacterImagePath -Destination (Join-Path $buildRoot $imageFileName) -Force
        if (Test-Path -LiteralPath $UtacoreIconPath -PathType Leaf) {
            Copy-Item -LiteralPath $UtacoreIconPath -Destination (Join-Path $buildRoot $appIconFileName) -Force
        }
        else {
            Set-Content -LiteralPath (Join-Path $buildRoot $appIconFileName) -Value '' -Encoding UTF8
        }
        if ($hasIntroVideo) {
            Copy-Item -LiteralPath $IntroVideoPath -Destination (Join-Path $buildRoot $videoFileName) -Force
        }
        else {
            Set-Content -LiteralPath (Join-Path $buildRoot $videoFileName) -Value '' -Encoding UTF8
        }

        if ($hasTermsOfService) {
            Copy-Item -LiteralPath $TermsTextPath -Destination (Join-Path $buildRoot 'terms.txt') -Force
        }
        else {
            Set-Content -LiteralPath (Join-Path $buildRoot 'terms.txt') -Value '' -Encoding UTF8
        }

        Write-BuildProgress -Percent 38 -Message 'Generating installer configuration...'
        $installerConfig = @{
            WindowTitle       = 'UTACORE Installer'
            VoicebankName     = $VoicebankName
            CharacterName     = $CharacterName
            CreatorName       = $CreatorName
            Description       = $Description
            AccentColor       = $AccentColor
            DefaultFolderName = Get-DefaultInstallFolderName -VoicebankName $VoicebankName
            CharacterImageFileName = $imageFileName
            IntroVideoFileName = $videoFileName
            HasIntroVideo = $hasIntroVideo
            HasTermsOfService = $hasTermsOfService
        }

        $launcherVbsPath = Join-Path $buildRoot 'LaunchInstaller.vbs'
        $installerScriptPath = Join-Path $buildRoot 'RunInstaller.ps1'
        $sedPath = Join-Path $buildRoot 'package.sed'

        if (Test-Path -LiteralPath $OutputExePath -PathType Leaf) {
            Remove-Item -LiteralPath $OutputExePath -Force
        }

        Write-BuildProgress -Percent 52 -Message 'Writing launcher and installer files...'
        $utf8Bom = New-Object System.Text.UTF8Encoding($true)

        [System.IO.File]::WriteAllText($launcherVbsPath, (New-LauncherVbsContent), [System.Text.Encoding]::ASCII)
        [System.IO.File]::WriteAllText($installerScriptPath, (New-InstallerScriptContent -Config $installerConfig), $utf8Bom)
        [System.IO.File]::WriteAllText(
            $sedPath,
            (New-IExpressSedContent `
                -SourceDirectory $buildRoot `
                -OutputExePath $OutputExePath `
                -FriendlyName "UTACORE Installer" `
                -CharacterImageFileName $imageFileName `
                -IntroVideoFileName $videoFileName `
                -AppIconFileName $appIconFileName),
            [System.Text.Encoding]::ASCII
        )

        Write-BuildProgress -Percent 68 -Message 'Running IExpress to package the final installer exe...'
        & iexpress.exe /N /Q $sedPath

        for ($attempt = 0; $attempt -lt 240; $attempt++) {
            if ((Test-Path -LiteralPath $OutputExePath -PathType Leaf) -and ((Get-Item -LiteralPath $OutputExePath).Length -gt 0)) {
                break
            }

            if (($attempt % 10) -eq 0) {
                $percent = [Math]::Min(95, 72 + [int]($attempt / 4))
                Write-BuildProgress -Percent $percent -Message 'Waiting for the packaged installer exe to finish writing...'
            }
            Start-Sleep -Milliseconds 500
        }

        if (-not (Test-Path -LiteralPath $OutputExePath -PathType Leaf)) {
            throw 'The installer build completed without producing the expected exe.'
        }

        Write-BuildProgress -Percent 100 -Message 'Build complete.'
        return $OutputExePath
    }
    finally {
        Remove-Item -LiteralPath $buildRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Show-MakerForm {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'UTACORE'
    $form.Size = New-Object System.Drawing.Size(960, 780)
    $form.StartPosition = 'CenterScreen'
    $form.BackColor = [System.Drawing.Color]::FromArgb(246, 246, 248)
    if (Test-Path -LiteralPath $UtacoreIconPath -PathType Leaf) {
        $form.Icon = New-Object System.Drawing.Icon($UtacoreIconPath)
    }

    $titleLabel = New-Object System.Windows.Forms.Label
    $titleLabel.Text = 'UTACORE'
    $titleLabel.Font = New-Object System.Drawing.Font('Segoe UI', 18, [System.Drawing.FontStyle]::Bold)
    $titleLabel.AutoSize = $true
    $titleLabel.Location = New-Object System.Drawing.Point(24, 18)
    [void]$form.Controls.Add($titleLabel)

    if (Test-Path -LiteralPath $UtacoreLogoPngPath -PathType Leaf) {
        $logoPanel = New-Object System.Windows.Forms.Panel
        $logoPanel.Location = New-Object System.Drawing.Point(736, 10)
        $logoPanel.Size = New-Object System.Drawing.Size(196, 96)
        $logoPanel.BackColor = [System.Drawing.Color]::Transparent

        $logoPictureBox = New-Object System.Windows.Forms.PictureBox
        $logoPictureBox.Location = New-Object System.Drawing.Point(12, 2)
        $logoPictureBox.Size = New-Object System.Drawing.Size(172, 92)
        $logoPictureBox.SizeMode = 'Zoom'
        $logoPictureBox.Image = [System.Drawing.Image]::FromFile($UtacoreLogoPngPath)

        [void]$logoPanel.Controls.Add($logoPictureBox)
        [void]$form.Controls.Add($logoPanel)
    }

    $subtitleLabel = New-Object System.Windows.Forms.Label
    $subtitleLabel.Text = 'Build reusable UTAU voicebank installers with optional intro video, terms screen, and custom branding.'
    $subtitleLabel.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)
    $subtitleLabel.AutoSize = $true
    $subtitleLabel.Location = New-Object System.Drawing.Point(28, 58)
    [void]$form.Controls.Add($subtitleLabel)

    $panel = New-Object System.Windows.Forms.Panel
    $panel.Location = New-Object System.Drawing.Point(24, 92)
    $panel.Size = New-Object System.Drawing.Size(896, 628)
    $panel.BackColor = [System.Drawing.Color]::White
    $panel.BorderStyle = 'FixedSingle'
    $panel.AutoScroll = $true
    [void]$form.Controls.Add($panel)

    $script:MakerCurrentTop = 24

    function Add-FieldLabel {
        param([string]$Text)

        $label = New-Object System.Windows.Forms.Label
        $label.Text = $Text
        $label.Font = New-Object System.Drawing.Font('Segoe UI', 9.5, [System.Drawing.FontStyle]::Bold)
        $label.AutoSize = $true
        $label.Location = New-Object System.Drawing.Point(24, $script:MakerCurrentTop)
        [void]$panel.Controls.Add($label)
        $script:MakerCurrentTop = [int]$script:MakerCurrentTop + 24
    }

    function Add-TextField {
        param(
            [string]$DefaultValue = '',
            [int]$Width = 620
        )

        $textbox = New-Object System.Windows.Forms.TextBox
        $textbox.Text = $DefaultValue
        $textbox.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)
        $textbox.Size = New-Object System.Drawing.Size($Width, 28)
        $textbox.Location = New-Object System.Drawing.Point(24, $script:MakerCurrentTop)
        [void]$panel.Controls.Add($textbox)
        return $textbox
    }

    function Add-BrowseButton {
        param(
            [string]$Text,
            [int]$Left
        )

        $button = New-Object System.Windows.Forms.Button
        $button.Text = $Text
        $button.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
        $button.Size = New-Object System.Drawing.Size(124, 28)
        $button.Location = New-Object System.Drawing.Point($Left, $script:MakerCurrentTop)
        [void]$panel.Controls.Add($button)
        return $button
    }

    Add-FieldLabel 'Compressed Voicebank Folder (.zip)'
    $zipTextBox = Add-TextField
    $zipBrowseButton = Add-BrowseButton -Text 'Choose Zip' -Left 748
    $script:MakerCurrentTop = [int]$script:MakerCurrentTop + 42

    Add-FieldLabel 'Character Image'
    $imageTextBox = Add-TextField
    $imageBrowseButton = Add-BrowseButton -Text 'Choose Image' -Left 748
    $script:MakerCurrentTop = [int]$script:MakerCurrentTop + 42

    Add-FieldLabel 'Intro Video (Optional)'
    $videoTextBox = Add-TextField
    $videoBrowseButton = Add-BrowseButton -Text 'Choose Video' -Left 748
    $script:MakerCurrentTop = [int]$script:MakerCurrentTop + 42

    Add-FieldLabel 'Terms of Service Text File (Optional)'
    $termsTextBox = Add-TextField
    $termsBrowseButton = Add-BrowseButton -Text 'Choose TXT' -Left 748
    $script:MakerCurrentTop = [int]$script:MakerCurrentTop + 42

    Add-FieldLabel 'Output Installer EXE'
    $outputTextBox = Add-TextField
    $outputBrowseButton = Add-BrowseButton -Text 'Save As...' -Left 748
    $script:MakerCurrentTop = [int]$script:MakerCurrentTop + 42

    Add-FieldLabel 'Voicebank Name'
    $voicebankNameTextBox = Add-TextField -Width 364
    $voicebankNameTextBox.Location = New-Object System.Drawing.Point(24, $script:MakerCurrentTop)

    $characterNameLabel = New-Object System.Windows.Forms.Label
    $characterNameLabel.Text = 'Character Name'
    $characterNameLabel.Font = New-Object System.Drawing.Font('Segoe UI', 9.5, [System.Drawing.FontStyle]::Bold)
    $characterNameLabel.AutoSize = $true
    $characterNameLabel.Location = New-Object System.Drawing.Point(420, ([int]$script:MakerCurrentTop - 24))
    [void]$panel.Controls.Add($characterNameLabel)

    $characterNameTextBox = Add-TextField -Width 364
    $characterNameTextBox.Location = New-Object System.Drawing.Point(420, $script:MakerCurrentTop)
    $script:MakerCurrentTop = [int]$script:MakerCurrentTop + 42

    Add-FieldLabel 'Creator / Author'
    $creatorTextBox = Add-TextField -Width 364
    $script:MakerCurrentTop = [int]$script:MakerCurrentTop + 42

    Add-FieldLabel 'Installer Description / Voicebank Info'
    $descriptionTextBox = New-Object System.Windows.Forms.TextBox
    $descriptionTextBox.Multiline = $true
    $descriptionTextBox.ScrollBars = 'Vertical'
    $descriptionTextBox.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)
    $descriptionTextBox.Size = New-Object System.Drawing.Size(768, 140)
    $descriptionTextBox.Location = New-Object System.Drawing.Point(24, $script:MakerCurrentTop)
    [void]$panel.Controls.Add($descriptionTextBox)
    $script:MakerCurrentTop = [int]$script:MakerCurrentTop + 162

    $colorCheckBox = New-Object System.Windows.Forms.CheckBox
    $colorCheckBox.Text = 'Use custom installer accent color'
    $colorCheckBox.Font = New-Object System.Drawing.Font('Segoe UI', 9.5, [System.Drawing.FontStyle]::Bold)
    $colorCheckBox.AutoSize = $true
    $colorCheckBox.Location = New-Object System.Drawing.Point(24, $script:MakerCurrentTop)
    [void]$panel.Controls.Add($colorCheckBox)

    $colorTextBox = New-Object System.Windows.Forms.TextBox
    $colorTextBox.Text = '#2D5C88'
    $colorTextBox.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)
    $colorTextBox.Size = New-Object System.Drawing.Size(120, 28)
    $colorTextBox.Location = New-Object System.Drawing.Point(304, ([int]$script:MakerCurrentTop - 2))
    $colorTextBox.Enabled = $false
    [void]$panel.Controls.Add($colorTextBox)
    $script:MakerCurrentTop = [int]$script:MakerCurrentTop + 54

    $statusLabel = New-Object System.Windows.Forms.Label
    $statusLabel.Text = 'Ready.'
    $statusLabel.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)
    $statusLabel.AutoSize = $true
    $statusLabel.Location = New-Object System.Drawing.Point(24, $script:MakerCurrentTop)
    [void]$panel.Controls.Add($statusLabel)

    $buildButtonTop = [int]$script:MakerCurrentTop + 28

    $buildButton = New-Object System.Windows.Forms.Button
    $buildButton.Text = 'Build Installer EXE'
    $buildButton.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
    $buildButton.Size = New-Object System.Drawing.Size(190, 40)
    $buildButton.Location = New-Object System.Drawing.Point(602, $buildButtonTop)
    $buildButton.BackColor = [System.Drawing.Color]::FromArgb(45, 92, 136)
    $buildButton.ForeColor = [System.Drawing.Color]::White
    $buildButton.FlatStyle = 'Flat'
    [void]$panel.Controls.Add($buildButton)

    $progressBar = New-Object System.Windows.Forms.ProgressBar
    $progressBar.Location = New-Object System.Drawing.Point(24, ($buildButtonTop + 6))
    $progressBar.Size = New-Object System.Drawing.Size(560, 24)
    $progressBar.Minimum = 0
    $progressBar.Maximum = 100
    $progressBar.Value = 0
    [void]$panel.Controls.Add($progressBar)

    $logToggleButton = New-Object System.Windows.Forms.Button
    $logToggleButton.Text = 'Show Build Log'
    $logToggleButton.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
    $logToggleButton.Size = New-Object System.Drawing.Size(140, 28)
    $logToggleButton.Location = New-Object System.Drawing.Point(652, ($buildButtonTop + 4))
    [void]$panel.Controls.Add($logToggleButton)

    $logTextBox = New-Object System.Windows.Forms.TextBox
    $logTextBox.Multiline = $true
    $logTextBox.ScrollBars = 'Vertical'
    $logTextBox.ReadOnly = $true
    $logTextBox.Font = New-Object System.Drawing.Font('Consolas', 9)
    $logTextBox.Size = New-Object System.Drawing.Size(768, 170)
    $logTextBox.Location = New-Object System.Drawing.Point(24, ($buildButtonTop + 42))
    $logTextBox.Visible = $false
    [void]$panel.Controls.Add($logTextBox)

    $panel.AutoScrollMinSize = New-Object System.Drawing.Size(0, ($buildButtonTop + 84))

    function Add-BuildLogLine {
        param([string]$Message)

        $timestamp = Get-Date -Format 'HH:mm:ss'
        $line = "[$timestamp] $Message"
        if ([string]::IsNullOrWhiteSpace($logTextBox.Text)) {
            $logTextBox.Text = $line
        }
        else {
            $logTextBox.AppendText([Environment]::NewLine + $line)
        }
    }

    $logToggleButton.Add_Click({
        $logTextBox.Visible = -not $logTextBox.Visible
        if ($logTextBox.Visible) {
            $logToggleButton.Text = 'Hide Build Log'
            $panel.AutoScrollMinSize = New-Object System.Drawing.Size(0, ($buildButtonTop + 240))
        }
        else {
            $logToggleButton.Text = 'Show Build Log'
            $panel.AutoScrollMinSize = New-Object System.Drawing.Size(0, ($buildButtonTop + 84))
        }
    })

    $buildTimer = New-Object System.Windows.Forms.Timer
    $buildTimer.Interval = 500
    $script:buildProcess = $null
    $script:buildConfigPath = $null
    $script:buildProgressPath = $null
    $script:buildLogPath = $null
    $script:lastLogLength = 0

    function Clear-BuildTempFiles {
        foreach ($path in @($script:buildConfigPath, $script:buildProgressPath, $script:buildLogPath)) {
            if (-not [string]::IsNullOrWhiteSpace($path) -and (Test-Path -LiteralPath $path)) {
                Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
            }
        }
        $script:buildConfigPath = $null
        $script:buildProgressPath = $null
        $script:buildLogPath = $null
        $script:lastLogLength = 0
        $script:buildProcess = $null
    }

    $buildTimer.Add_Tick({
        try {
            if ($script:buildProgressPath -and (Test-Path -LiteralPath $script:buildProgressPath)) {
                $progressInfo = Get-Content -LiteralPath $script:buildProgressPath -Raw | ConvertFrom-Json
                $safePercent = [Math]::Max(0, [Math]::Min(100, [int]$progressInfo.percent))
                $progressBar.Value = $safePercent
                if ($progressInfo.message) {
                    $statusLabel.Text = [string]$progressInfo.message
                }
            }

            if ($script:buildLogPath -and (Test-Path -LiteralPath $script:buildLogPath)) {
                $logContent = Get-Content -LiteralPath $script:buildLogPath -Raw
                if ($logContent.Length -ne $script:lastLogLength) {
                    $logTextBox.Text = $logContent.TrimEnd()
                    $logTextBox.SelectionStart = $logTextBox.TextLength
                    $logTextBox.ScrollToCaret()
                    $script:lastLogLength = $logContent.Length
                }
            }

            if (-not $script:buildProcess) {
                return
            }

            if (-not $script:buildProcess.HasExited) {
                return
            }

            $buildTimer.Stop()
            $buildButton.Enabled = $true

            if ($script:buildProcess.ExitCode -eq 0 -and (Test-Path -LiteralPath $outputTextBox.Text.Trim() -PathType Leaf)) {
                $progressBar.Value = 100
                $statusLabel.Text = "Finished: $($outputTextBox.Text.Trim())"
                [System.Windows.Forms.MessageBox]::Show(
                    "Installer exe created successfully:`n$($outputTextBox.Text.Trim())",
                    'Build Complete',
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Information
                ) | Out-Null
            }
            else {
                $errorMessage = 'The installer build failed.'
                if ($script:buildLogPath -and (Test-Path -LiteralPath $script:buildLogPath)) {
                    $lines = Get-Content -LiteralPath $script:buildLogPath
                    if ($lines) {
                        $errorMessage = $lines[-1]
                    }
                }
                $statusLabel.Text = 'Build failed.'
                [System.Windows.Forms.MessageBox]::Show(
                    $errorMessage,
                    'Build Error',
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Error
                ) | Out-Null
            }
        }
        finally {
            if ($script:buildProcess -and $script:buildProcess.HasExited) {
                Clear-BuildTempFiles
            }
        }
    })

    $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $saveFileDialog = New-Object System.Windows.Forms.SaveFileDialog
    $saveFileDialog.Filter = 'Executable (*.exe)|*.exe'
    $saveFileDialog.DefaultExt = 'exe'
    $saveFileDialog.AddExtension = $true

    $colorCheckBox.Add_CheckedChanged({
        $colorTextBox.Enabled = $colorCheckBox.Checked
    })

    $zipBrowseButton.Add_Click({
        $openFileDialog.Filter = 'Zip archive (*.zip)|*.zip'
        if ($openFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $zipTextBox.Text = $openFileDialog.FileName
        }
    })

    $imageBrowseButton.Add_Click({
        $openFileDialog.Filter = 'Image files (*.png;*.jpg;*.jpeg;*.bmp)|*.png;*.jpg;*.jpeg;*.bmp'
        if ($openFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $imageTextBox.Text = $openFileDialog.FileName
        }
    })

    $videoBrowseButton.Add_Click({
        $openFileDialog.Filter = 'Video files (*.mp4;*.wmv;*.avi)|*.mp4;*.wmv;*.avi'
        if ($openFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $videoTextBox.Text = $openFileDialog.FileName
        }
    })

    $termsBrowseButton.Add_Click({
        $openFileDialog.Filter = 'Text files (*.txt)|*.txt'
        if ($openFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $termsTextBox.Text = $openFileDialog.FileName
        }
    })

    $outputBrowseButton.Add_Click({
        if (-not [string]::IsNullOrWhiteSpace($voicebankNameTextBox.Text)) {
            $saveFileDialog.FileName = (Get-DefaultInstallFolderName -VoicebankName $voicebankNameTextBox.Text) + '_UTACORE.exe'
        }

        if ($saveFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $outputTextBox.Text = $saveFileDialog.FileName
        }
    })

    $buildButton.Add_Click({
        if ($script:buildProcess -and -not $script:buildProcess.HasExited) {
            return
        }

        $buildButton.Enabled = $false
        $progressBar.Value = 0
        $logTextBox.Clear()
        Add-BuildLogLine -Message 'Build started.'
        $statusLabel.Text = 'Starting installer build...'
        $form.Refresh()

        try {
            $accentColor = if ($colorCheckBox.Checked) { $colorTextBox.Text.Trim() } else { '#2D5C88' }
            $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("UtauVoicebankMakerRun_" + [guid]::NewGuid().ToString('N'))
            [System.IO.Directory]::CreateDirectory($tempRoot) | Out-Null

            $script:buildConfigPath = Join-Path $tempRoot 'build.json'
            $script:buildProgressPath = Join-Path $tempRoot 'progress.json'
            $script:buildLogPath = Join-Path $tempRoot 'build.log'
            $script:lastLogLength = 0

            $buildConfig = @{
                voicebankZipPath = $zipTextBox.Text.Trim()
                characterImagePath = $imageTextBox.Text.Trim()
                introVideoPath = $videoTextBox.Text.Trim()
                termsTextPath = $termsTextBox.Text.Trim()
                outputExePath = $outputTextBox.Text.Trim()
                voicebankName = $voicebankNameTextBox.Text.Trim()
                characterName = $characterNameTextBox.Text.Trim()
                creatorName = $creatorTextBox.Text.Trim()
                description = $descriptionTextBox.Text.Trim()
                accentColor = $accentColor
                progressFilePath = $script:buildProgressPath
                logFilePath = $script:buildLogPath
            }

            if (-not $logTextBox.Visible) {
                $logToggleButton.PerformClick()
            }

            $buildConfig | ConvertTo-Json | Set-Content -LiteralPath $script:buildConfigPath -Encoding UTF8

            $startInfo = New-Object System.Diagnostics.ProcessStartInfo
            $startInfo.FileName = 'powershell.exe'
            $startInfo.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSCommandPath`" -ConfigPath `"$script:buildConfigPath`""
            $startInfo.UseShellExecute = $false
            $startInfo.CreateNoWindow = $true

            $script:buildProcess = New-Object System.Diagnostics.Process
            $script:buildProcess.StartInfo = $startInfo
            [void]$script:buildProcess.Start()
            $buildTimer.Start()
        }
        catch {
            $statusLabel.Text = 'Build failed.'
            Add-BuildLogLine -Message ("Build failed before packaging started: " + $_.Exception.Message)
            Clear-BuildTempFiles
            $buildButton.Enabled = $true
            [System.Windows.Forms.MessageBox]::Show(
                $_.Exception.Message,
                'Build Error',
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            ) | Out-Null
        }
    })

    [void]$form.ShowDialog()
}

if ($ConfigPath) {
    try {
        $config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
        $progressFilePath = if ($config.PSObject.Properties['progressFilePath']) { [string]$config.progressFilePath } else { $null }
        $logFilePath = if ($config.PSObject.Properties['logFilePath']) { [string]$config.logFilePath } else { $null }
        $termsTextPath = if ($config.PSObject.Properties['termsTextPath']) { [string]$config.termsTextPath } else { $null }
        $resultPath = New-VoicebankInstallerPackage `
            -VoicebankZipPath $config.voicebankZipPath `
            -CharacterImagePath $config.characterImagePath `
            -IntroVideoPath $config.introVideoPath `
            -TermsTextPath $termsTextPath `
            -OutputExePath $config.outputExePath `
            -VoicebankName $config.voicebankName `
            -CharacterName $config.characterName `
            -CreatorName $config.creatorName `
            -Description $config.description `
            -AccentColor $config.accentColor `
            -ProgressFilePath $progressFilePath `
            -LogFilePath $logFilePath
        Write-Output $resultPath
        exit 0
    }
    catch {
        if ($logFilePath) {
            $timestamp = Get-Date -Format 'HH:mm:ss'
            Add-Content -LiteralPath $logFilePath -Value "[$timestamp] Build failed: $($_.Exception.Message)"
        }
        Write-Error $_.Exception.Message
        exit 1
    }
}
else {
    Show-MakerForm
}
