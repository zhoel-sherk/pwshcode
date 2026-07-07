# tui-engine.ps1 — Double-buffered TUI render engine for pwshcode installer
# Dot-source: . .\tui-engine.ps1
#
# Drawing and fallback techniques inspired by PSYamlTUI
# (https://github.com/dan-metzler/PSYamlTUI) — MIT license, Dan Metzler.
#
# Uses frame-diffing: only lines that changed between frames are re-written.

# ─── Terminal capability detection ──────────────────────────────

$script:TuiAnsiSupported = $false
$script:TuiUseUnicode = $true
$script:TuiScreenCleared = $false
try {
    if (-not [Console]::IsOutputRedirected -and $Host.UI.SupportsVirtualTerminal) {
        $script:TuiAnsiSupported = $true
    }
} catch {}
try {
    if ([Console]::IsOutputRedirected) { $script:TuiUseUnicode = $false }
} catch {}

# ─── Character set (Unicode or ASCII fallback) ──────────────────

$script:TuiChars = @{}
$script:TuiChars.Horiz  = if ($script:TuiUseUnicode) { '═' } else { '=' }
$script:TuiChars.Vert   = if ($script:TuiUseUnicode) { '║' } else { '|' }
$script:TuiChars.TL     = if ($script:TuiUseUnicode) { '╔' } else { '+' }
$script:TuiChars.TR     = if ($script:TuiUseUnicode) { '╗' } else { '+' }
$script:TuiChars.BL     = if ($script:TuiUseUnicode) { '╚' } else { '+' }
$script:TuiChars.BR     = if ($script:TuiUseUnicode) { '╝' } else { '+' }
$script:TuiChars.RadioOff = if ($script:TuiUseUnicode) { '○' } else { '( )' }
$script:TuiChars.CheckOn  = if ($script:TuiUseUnicode) { '✓' } else { '[x]' }
$script:TuiChars.CheckOff = if ($script:TuiUseUnicode) { '○' } else { '[ ]' }
$script:TuiChars.BarFill  = if ($script:TuiUseUnicode) { '█' } else { '#' }
$script:TuiChars.BarEmpty = if ($script:TuiUseUnicode) { '░' } else { '.' }
$script:TuiChars.ArrowUp  = if ($script:TuiUseUnicode) { '↑' } else { '^' }
$script:TuiChars.ArrowDn  = if ($script:TuiUseUnicode) { '↓' } else { 'v' }

# ─── Engine state ───────────────────────────────────────────────

$script:TuiEsc = [char]27
$script:TuiPrevLines = @()
$script:TuiBuf = $null

# ─── Color map ──────────────────────────────────────────────────

$TuiC = @{}
$TuiC.Reset   = "$script:TuiEsc[0m"
$TuiC.Bold    = "$script:TuiEsc[1m"
$TuiC.Dim     = "$script:TuiEsc[2m"
$TuiC.Reverse = "$script:TuiEsc[7m"
$TuiC.Red     = "$script:TuiEsc[91m"
$TuiC.Green   = "$script:TuiEsc[92m"
$TuiC.Yellow  = "$script:TuiEsc[93m"
$TuiC.Blue    = "$script:TuiEsc[94m"
$TuiC.Magenta = "$script:TuiEsc[95m"
$TuiC.Cyan    = "$script:TuiEsc[96m"
$TuiC.White   = "$script:TuiEsc[97m"
$TuiC.Grey    = "$script:TuiEsc[90m"
$TuiC.BgDark  = "$script:TuiEsc[48;2;26;27;38m"
$TuiC.BgBlue  = "$script:TuiEsc[48;2;122;162;247m"
$TuiC.FgBlue  = "$script:TuiEsc[38;2;122;162;247m"
$TuiC.FgGreen = "$script:TuiEsc[38;2;158;206;106m"
$TuiC.FgRed   = "$script:TuiEsc[38;2;219;75;75m"
$TuiC.FgOrange= "$script:TuiEsc[38;2;255;158;100m"

# ─── ANSI helpers ───────────────────────────────────────────────

$script:TuiAnsiRx = [regex]'\x1b\[[0-9;]*[a-zA-Z]'

function Strip-ANSI {
    param($Text)
    if (-not $Text) { return '' }
    return $script:TuiAnsiRx.Replace($Text, '')
}

# ─── Frame control ──────────────────────────────────────────────

function New-TuiFrame {
    $script:TuiBuf = New-Object System.Text.StringBuilder
    if (-not $script:TuiScreenCleared -and $script:TuiAnsiSupported) {
        $null = $script:TuiBuf.Append("${script:TuiEsc}[3J${script:TuiEsc}[H")
        $script:TuiScreenCleared = $true
    }
}

function Send-TuiFrame {
    if (-not $script:TuiBuf -or $script:TuiBuf.Length -eq 0) { return }

    $frame = $script:TuiBuf.ToString().TrimEnd("`r", "`n")
    $lines = $frame -split "`n"
    $prev = $script:TuiPrevLines
    $bh = try { [Console]::BufferHeight } catch { 9999 }

    try { [Console]::CursorVisible = $false } catch {}

    if ($script:TuiAnsiSupported) {
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($i -ge $prev.Count -or $lines[$i] -ne $prev[$i]) {
                try {
                    if ($i -lt $bh) {
                        [Console]::SetCursorPosition(0, $i)
                        Write-Host "${script:TuiEsc}[2K$($lines[$i])" -NoNewline
                    }
                } catch {}
            }
        }
        if ($lines.Count -lt $prev.Count) {
            try {
                [Console]::SetCursorPosition(0, [Math]::Max(0, $lines.Count))
                Write-Host "${script:TuiEsc}[J" -NoNewline
            } catch {}
        }
    } else {
        try { $blank = ' ' * [Console]::WindowWidth } catch { $blank = ' ' * 80 }
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($i -ge $prev.Count -or $lines[$i] -ne $prev[$i]) {
                try {
                    if ($i -lt $bh) {
                        [Console]::SetCursorPosition(0, $i)
                        $clean = Strip-ANSI $lines[$i]
                        Write-Host "$blank`r$clean" -NoNewline
                    }
                } catch {}
            }
        }
        if ($lines.Count -lt $prev.Count) {
            try {
                [Console]::SetCursorPosition(0, [Math]::Max(0, $lines.Count))
                Write-Host "$blank" -NoNewline
            } catch {}
        }
    }

    $script:TuiPrevLines = $lines
    try { [Console]::CursorVisible = $true } catch {}
}

# ─── Buffer writing ────────────────────────────────────────────

function Write-TuiBuffer {
    param($X = 0, $Y = 0, $Text = "")
    if (-not $script:TuiBuf) { New-TuiFrame }
    $null = $script:TuiBuf.Append("$script:TuiEsc[$($Y + 1);$($X + 1)H$Text")
}

function Write-TuiLine {
    param($X = 0, $Y = 0, $Text = "")
    if (-not $script:TuiBuf) { New-TuiFrame }
    $null = $script:TuiBuf.Append("$script:TuiEsc[$($Y + 1);$($X + 1)H$script:TuiEsc[2K$Text")
}

function Clear-TuiLine {
    param($Y = 0, $X = 0)
    if (-not $script:TuiBuf) { New-TuiFrame }
    $null = $script:TuiBuf.Append("$script:TuiEsc[$($Y + 1);$($X + 1)H$script:TuiEsc[0K")
}

# ─── Console helpers ───────────────────────────────────────────

function Get-TuiSize {
    try {
        return @{ Width = [Console]::WindowWidth; Height = [Console]::WindowHeight }
    } catch {
        return @{ Width = 80; Height = 25 }
    }
}

function Read-TuiKey {
    try {
        $k = [Console]::ReadKey($true)
        return @{
            Key = $k.Key
            KeyChar = $k.KeyChar
            VirtualKeyCode = $k.VirtualKeyCode
            Modifiers = $k.Modifiers
        }
    } catch {
        return @{ Key = 'Enter'; KeyChar = "`r"; VirtualKeyCode = 13; Modifiers = 0 }
    }
}

# ─── Widget: Box ───────────────────────────────────────────────

function Show-TuiBox {
    param($X = 0, $Y = 0, $Width = 50, $Height = 3, $Title = "", $Color = $TuiC.FgBlue)
    $C = $script:TuiChars
    $termW = try { [Console]::WindowWidth } catch { 80 }
    $maxW = [Math]::Max(20, [Math]::Min($termW - 4, 96))
    $Width = [Math]::Max(20, [Math]::Min($maxW, $Width))

    $top = "$($C.TL)$($C.Horiz * ($Width - 2))$($C.TR)"
    $mid = "$($C.Vert)$(' ' * ($Width - 2))$($C.Vert)"
    $bot = "$($C.BL)$($C.Horiz * ($Width - 2))$($C.BR)"

    $hline = "$Color$top$($TuiC.Reset)"
    if ($Title) {
        $pad = $Width - $Title.Length - 4
        $leftPad = [Math]::Max(1, [Math]::Floor($pad / 2))
        $rightPad = [Math]::Max(0, $pad - $leftPad)
        $hline = "$Color$($C.TL)$($C.Horiz * $leftPad) $Title $($C.Horiz * $rightPad)$($C.TR)$($TuiC.Reset)"
    }

    Write-TuiLine -X $X -Y $Y -Text $hline
    for ($r = 1; $r -lt $Height - 1; $r++) {
        Write-TuiLine -X $X -Y ($Y + $r) -Text "$Color$mid$($TuiC.Reset)"
    }
    Write-TuiLine -X $X -Y ($Y + $Height - 1) -Text "$Color$bot$($TuiC.Reset)"
}

# ─── Widget: Progress bar ─────────────────────────────────────

function Show-TuiProgress {
    param($X = 0, $Y = 0, $Percent = 0, $Label = "", $Width = 40)
    $C = $script:TuiChars
    $termW = try { [Console]::WindowWidth } catch { 80 }
    $maxW = [Math]::Min(60, $termW - $X - 2)
    $Width = [Math]::Max(10, [Math]::Min($maxW, $Width))

    $px = [Math]::Max(0, [Math]::Min(100, $Percent))
    $filled = [Math]::Floor($Width * $px / 100)
    $empty = $Width - $filled
    $barFilled = if ($filled -gt 0) { "$($TuiC.FgGreen)$($C.BarFill * $filled)$($TuiC.Reset)" } else { "" }
    $barEmpty  = if ($empty -gt 0)  { "$($TuiC.Grey)$($C.BarEmpty * $empty)$($TuiC.Reset)" } else { "" }
    $pct = "$($TuiC.FgBlue)$([Math]::Floor($px))%$($TuiC.Reset)"
    Write-TuiLine -X $X -Y $Y -Text "$barFilled$barEmpty $pct $Label"
}

# ─── Widget: Menu Radio ────────────────────────────────────────

function Show-TuiMenuRadio {
    param($Title = "", $Options = @(), $DefaultIndex = 0)
    $C = $script:TuiChars
    $sel = $DefaultIndex
    $opts = @($Options)
    $scrollOff = 0
    $boxColor = $TuiC.FgBlue

    $labels = $opts | ForEach-Object { if ($_ -is [hashtable]) { $_.label } else { $_ } }
    $maxObj = $labels | Measure-Object -Property Length -Maximum; $maxLabel = if ($maxObj) { $maxObj.Maximum } else { 0 }
    $maxLabel = [Math]::Max($maxLabel, $Title.Length)
    $boxW = $maxLabel + 8

    $winH = try { [Console]::WindowHeight } catch { 25 }
    $termW = try { [Console]::WindowWidth } catch { 80 }
    $maxW = [Math]::Max(30, [Math]::Min($termW - 6, 96))
    $boxW = [Math]::Max(30, [Math]::Min($maxW, $boxW))

    $availH = $winH - 10
    $maxVis = [Math]::Max(3, [Math]::Min($opts.Count, $availH))

    Write-Host ""
    for ($i = 0; $i -lt $maxVis + 3; $i++) { Write-Host "" }
    try { $cursorTop = [Console]::CursorTop } catch { $cursorTop = 0 }
    $top = $cursorTop - $maxVis - 3

    try { [Console]::CursorVisible = $false } catch {}
    try {
        while ($true) {
            if ($sel -lt $scrollOff) { $scrollOff = $sel }
            if ($sel -ge $scrollOff + $maxVis) { $scrollOff = $sel - $maxVis + 1 }

            New-TuiFrame

            $titleBar = " $Title "
            $padLen = [Math]::Max(1, $boxW - $titleBar.Length - 2)
            $paddedTitle = "$boxColor$($C.TL)$($C.Horiz * $padLen)$titleBar$($C.Horiz) $($C.TR)$($TuiC.Reset)"
            Write-TuiLine -X 3 -Y $top -Text $paddedTitle

            $endVis = [Math]::Min($scrollOff + $maxVis, $opts.Count)
            for ($vi = $scrollOff; $vi -lt $endVis; $vi++) {
                $y = $top + 1 + ($vi - $scrollOff)
                $mark = if ($vi -eq $sel) { "$($TuiC.Cyan)$($C.RadioOff)$($TuiC.Reset)" } else { "$($TuiC.Grey)$($C.RadioOff)$($TuiC.Reset)" }
                $label = if ($opts[$vi] -is [hashtable]) { $opts[$vi].label } else { $opts[$vi] }
                $cleanLabel = Strip-ANSI $label
                $pad = [Math]::Max(0, $boxW - $cleanLabel.Length - 6)
                if ($vi -eq $sel) {
                    $line = "$($C.Vert) $mark $($TuiC.Reverse)$label$($TuiC.Reset)$(' ' * $pad)$($C.Vert)"
                } else {
                    $line = "$($C.Vert) $mark $($TuiC.Grey)$label$($TuiC.Reset)$(' ' * $pad)$($C.Vert)"
                }
                Write-TuiLine -X 3 -Y $y -Text "$boxColor$line$($TuiC.Reset)"
            }

            for ($vi = $endVis; $vi -lt $scrollOff + $maxVis; $vi++) {
                $y = $top + 1 + ($vi - $scrollOff)
                Write-TuiLine -X 3 -Y $y -Text "$boxColor$($C.Vert)$(' ' * $boxW)$($C.Vert)$($TuiC.Reset)"
            }

            $scrollTxt = ""
            if ($opts.Count -gt $maxVis) {
                $pct = [Math]::Floor(($scrollOff + $endVis) / $opts.Count * 100)
                $scrollTxt = " $($C.ArrowUp) $($scrollOff + 1)-$endVis/$($opts.Count) $($C.ArrowDn)"
            }
            $innerW = $boxW - 2
            if ($scrollTxt) {
                $leftPad = [Math]::Max(1, $innerW - $scrollTxt.Length - 1)
                $botBar = "$($C.BL)$($C.Horiz * $leftPad)$scrollTxt $($C.Horiz)$($C.BR)"
            } else {
                $botBar = "$($C.BL)$($C.Horiz * $innerW)$($C.BR)"
            }
            Write-TuiLine -X 3 -Y ($top + $maxVis + 1) -Text "$boxColor$botBar$($TuiC.Reset)"

            $help = " $($C.Horiz * 3) $($C.ArrowUp)$($C.ArrowDn)/j/k nav  PgUp/PgDn  Home/End  Enter OK $($C.Horiz * 3)"
            Write-TuiLine -X 3 -Y ($top + $maxVis + 2) -Text "$($TuiC.Dim)$help$($TuiC.Reset)"

            Send-TuiFrame

            $key = Read-TuiKey
            if ($key.Key -eq 'UpArrow' -or $key.KeyChar -eq 'k') { if ($sel -gt 0) { $sel-- } }
            elseif ($key.Key -eq 'DownArrow' -or $key.KeyChar -eq 'j') { if ($sel -lt $opts.Count - 1) { $sel++ } }
            elseif ($key.Key -eq 'PageUp') { $sel = [Math]::Max(0, $sel - $maxVis) }
            elseif ($key.Key -eq 'PageDown') { $sel = [Math]::Min($opts.Count - 1, $sel + $maxVis) }
            elseif ($key.Key -eq 'Home') { $sel = 0 }
            elseif ($key.Key -eq 'End') { $sel = $opts.Count - 1 }
            elseif ($key.Key -eq 'Enter') { break }
        }
    } finally {
        try { [Console]::CursorVisible = $true } catch {}
    }
    Write-Host ""
    return $sel
}

# ─── Widget: Menu Checkbox ─────────────────────────────────────

function Show-TuiMenuCheckbox {
    param($Title = "", $Options = @())

    $C = $script:TuiChars
    $states = @($Options | ForEach-Object { $true })
    $idx = 0
    $opts = @($Options)
    $scrollOff = 0
    $boxColor = $TuiC.FgBlue

    $labels = $opts | ForEach-Object { if ($_ -is [hashtable]) { $_.label } else { $_ } }
    $maxObj = $labels | Measure-Object -Property Length -Maximum; $maxLabel = if ($maxObj) { $maxObj.Maximum } else { 0 }
    $maxLabel = [Math]::Max($maxLabel, $Title.Length)
    $boxW = $maxLabel + 18

    $winH = try { [Console]::WindowHeight } catch { 25 }
    $termW = try { [Console]::WindowWidth } catch { 80 }
    $maxW = [Math]::Max(30, [Math]::Min($termW - 6, 96))
    $boxW = [Math]::Max(30, [Math]::Min($maxW, $boxW))

    $availH = $winH - 10
    $maxVis = [Math]::Max(3, [Math]::Min($opts.Count, $availH))

    Write-Host ""
    for ($i = 0; $i -lt $maxVis + 3; $i++) { Write-Host "" }
    try { $cursorTop = [Console]::CursorTop } catch { $cursorTop = 0 }
    $top = $cursorTop - $maxVis - 3

    try { [Console]::CursorVisible = $false } catch {}
    try {
        while ($true) {
            if ($idx -lt $scrollOff) { $scrollOff = $idx }
            if ($idx -ge $scrollOff + $maxVis) { $scrollOff = $idx - $maxVis + 1 }

            New-TuiFrame

            $titleBar = " $Title "
            $padLen = [Math]::Max(1, $boxW - $titleBar.Length - 2)
            $paddedTitle = "$boxColor$($C.TL)$($C.Horiz * $padLen)$titleBar$($C.Horiz) $($C.TR)$($TuiC.Reset)"
            Write-TuiLine -X 3 -Y $top -Text $paddedTitle

            $endVis = [Math]::Min($scrollOff + $maxVis, $opts.Count)
            for ($vi = $scrollOff; $vi -lt $endVis; $vi++) {
                $y = $top + 1 + ($vi - $scrollOff)
                $box = if ($states[$vi]) { "$($TuiC.FgGreen)$($C.CheckOn)$($TuiC.Reset)" } else { "$($TuiC.Grey)$($C.CheckOff)$($TuiC.Reset)" }
                $label = if ($opts[$vi] -is [hashtable]) { $opts[$vi].label } else { $opts[$vi] }
                $desc = if ($opts[$vi] -is [hashtable] -and $opts[$vi].desc) { " $($TuiC.Dim)$($opts[$vi].desc)$($TuiC.Reset)" } else { "" }
                $cleanDesc = if ($opts[$vi] -is [hashtable] -and $opts[$vi].desc) { $opts[$vi].desc } else { "" }
                $innerW = $boxW - 4
                if ($cleanDesc) {
                    $padding = [Math]::Max(0, $innerW - $label.Length - $cleanDesc.Length - 2)
                } else {
                    $padding = [Math]::Max(0, $innerW - $label.Length - 1)
                }
                if ($vi -eq $idx) {
                    $line = "$($C.Vert) $box $($TuiC.Reverse)$label$($TuiC.Reset)$desc$(' ' * $padding)$($C.Vert)"
                } else {
                    $line = "$($C.Vert) $box $label$desc$(' ' * $padding)$($C.Vert)"
                }
                Write-TuiLine -X 3 -Y $y -Text "$boxColor$line$($TuiC.Reset)"
            }

            for ($vi = $endVis; $vi -lt $scrollOff + $maxVis; $vi++) {
                $y = $top + 1 + ($vi - $scrollOff)
                Write-TuiLine -X 3 -Y $y -Text "$boxColor$($C.Vert)$(' ' * $boxW)$($C.Vert)$($TuiC.Reset)"
            }

            $scrollTxt = ""
            if ($opts.Count -gt $maxVis) {
                $endTxt = $endVis
                $scrollTxt = " $($C.ArrowUp) $($scrollOff + 1)-$endTxt/$($opts.Count) $($C.ArrowDn)"
            }
            $innerW = $boxW - 2
            if ($scrollTxt) {
                $leftPad = [Math]::Max(1, $innerW - $scrollTxt.Length - 1)
                $botBar = "$($C.BL)$($C.Horiz * $leftPad)$scrollTxt $($C.Horiz)$($C.BR)"
            } else {
                $botBar = "$($C.BL)$($C.Horiz * $innerW)$($C.BR)"
            }
            Write-TuiLine -X 3 -Y ($top + $maxVis + 1) -Text "$boxColor$botBar$($TuiC.Reset)"

            $help = " $($C.Horiz * 3) Space toggle  $($C.ArrowUp)$($C.ArrowDn)/j/k nav  PgUp/PgDn  Enter OK $($C.Horiz * 3)"
            Write-TuiLine -X 3 -Y ($top + $maxVis + 2) -Text "$($TuiC.Dim)$help$($TuiC.Reset)"

            Send-TuiFrame

            $key = Read-TuiKey
            if ($key.Key -eq 'UpArrow' -or $key.KeyChar -eq 'k') { if ($idx -gt 0) { $idx-- } }
            elseif ($key.Key -eq 'DownArrow' -or $key.KeyChar -eq 'j') { if ($idx -lt $opts.Count - 1) { $idx++ } }
            elseif ($key.Key -eq 'PageUp') { $idx = [Math]::Max(0, $idx - $maxVis) }
            elseif ($key.Key -eq 'PageDown') { $idx = [Math]::Min($opts.Count - 1, $idx + $maxVis) }
            elseif ($key.Key -eq 'Home') { $idx = 0 }
            elseif ($key.Key -eq 'End') { $idx = $opts.Count - 1 }
            elseif ($key.Key -eq 'Spacebar') { $states[$idx] = -not $states[$idx] }
            elseif ($key.Key -eq 'Enter') { break }
        }
    } finally {
        try { [Console]::CursorVisible = $true } catch {}
    }
    Write-Host ""
    return $states
}

# ─── Widget: Banner ────────────────────────────────────────────

function Show-TuiBanner {
    $banner = @"
$($TuiC.Magenta)
     ██████╗ ██╗    ██╗███████╗██╗  ██╗ ██████╗ ██████╗ ██████╗ ███████╗
     ██╔══██╗██║    ██║██╔════╝██║  ██║██╔════╝██╔═══██╗██╔══██╗██╔════╝
     ██████╔╝██║ █╗ ██║███████╗███████║██║     ██║   ██║██║  ██║█████╗
     ██╔═══╝ ██║███╗██║╚════██║██╔══██║██║     ██║   ██║██║  ██║██╔══╝
     ██║     ╚███╔███╔╝███████║██║  ██║╚██████╗╚██████╔╝██████╔╝███████╗
     ╚═╝      ╚══╝╚══╝ ╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚═════╝ ╚═════╝ ╚══════╝
$($TuiC.Reset)
$($TuiC.Dim)  PowerShell 7 + opencode skills installer$($TuiC.Reset)
$($TuiC.Dim)  https://github.com/zhoel-sherk/pwshcode$($TuiC.Reset)
"@
    Write-Host $banner
}
