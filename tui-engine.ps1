# tui-engine.ps1 — Double-buffered TUI render engine for pwshcode installer
# Dot-source: . .\tui-engine.ps1
#
# Designed for flicker-free interactive menus with ANSI escape codes.
# Uses frame-diffing: only lines that changed between frames are re-written.

# ─── Engine state (script-scoped, not exported) ────────────────

$script:TuiEsc = [char]27
$script:TuiPrevLines = @()          # previous frame content (diff base)
$script:TuiBuf = $null              # [System.Text.StringBuilder]

# ─── Color map (exported via module scope) ─────────────────────

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
$TuiC.BgDark  = "$script:TuiEsc[48;2;26;27;38m"    # #1a1b26 Tokyo Night bg
$TuiC.BgBlue  = "$script:TuiEsc[48;2;122;162;247m" # #7aa2f7 accent
$TuiC.FgBlue  = "$script:TuiEsc[38;2;122;162;247m" # #7aa2f7
$TuiC.FgGreen = "$script:TuiEsc[38;2;158;206;106m" # #9ece6a
$TuiC.FgRed   = "$script:TuiEsc[38;2;219;75;75m"   # #db4b4b
$TuiC.FgOrange= "$script:TuiEsc[38;2;255;158;100m" # #ff9e64

# ─── Frame control ─────────────────────────────────────────────

function New-TuiFrame {
    <#
    .SYNOPSIS
        Start a new rendering frame. Clears the internal buffer.
    #>
    $script:TuiBuf = [System.Text.StringBuilder]::new()
}

function Send-TuiFrame {
    <#
    .SYNOPSIS
        Flush buffered output to console using diff-based rendering.
        Only lines that changed since the last frame are re-written.
    #>
    if (-not $script:TuiBuf -or $script:TuiBuf.Length -eq 0) { return }

    $frame = $script:TuiBuf.ToString().TrimEnd("`r", "`n")
    $lines = $frame -split "`n"
    $prev = $script:TuiPrevLines

    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($i -ge $prev.Count -or $lines[$i] -ne $prev[$i]) {
            try {
                $y = $i
                $bh = try { [Console]::BufferHeight } catch { 9999 }
                if ($y -lt $bh) {
                    [Console]::CursorVisible = $false
                    [Console]::SetCursorPosition(0, $y)
                    Write-Host "$script:TuiEsc[2K$($lines[$i])" -NoNewline
                }
            } catch {
                # silent — console may not support cursor ops
            }
        }
    }

    $script:TuiPrevLines = $lines
    try { [Console]::CursorVisible = $true } catch {}
}

# ─── Buffer writing ────────────────────────────────────────────

function Write-TuiBuffer {
    <#
    .SYNOPSIS
        Write text at (x,y) in the current frame buffer.
    .PARAMETER X
        Column position (0-based).
    .PARAMETER Y
        Row position (0-based, absolute console line).
    .PARAMETER Text
        Content to write.
    #>
    param($X = 0, $Y = 0, $Text = "")
    if (-not $script:TuiBuf) { New-TuiFrame }
    # ANSI cursor position is 1-based
    $null = $script:TuiBuf.Append("$script:TuiEsc[$($Y + 1);$($X + 1)H$Text")
}

function Write-TuiLine {
    <#
    .SYNOPSIS
        Write text at (x,y), clearing the entire line first.
    #>
    param($X = 0, $Y = 0, $Text = "")
    if (-not $script:TuiBuf) { New-TuiFrame }
    $null = $script:TuiBuf.Append("$script:TuiEsc[$($Y + 1);$($X + 1)H$script:TuiEsc[2K$Text")
}

function Clear-TuiLine {
    <#
    .SYNOPSIS
        Clear line Y from column X to end.
    #>
    param($Y = 0, $X = 0)
    if (-not $script:TuiBuf) { New-TuiFrame }
    $null = $script:TuiBuf.Append("$script:TuiEsc[$($Y + 1);$($X + 1)H$script:TuiEsc[0K")
}

# ─── Console helpers ───────────────────────────────────────────

function Get-TuiSize {
    <#
    .SYNOPSIS
        Returns console dimensions as @{Width; Height}.
    #>
    try {
        return @{ Width = [Console]::WindowWidth; Height = [Console]::WindowHeight }
    } catch {
        return @{ Width = 80; Height = 25 }
    }
}

function Read-TuiKey {
    <#
    .SYNOPSIS
        Read a single key press safely. Returns @{Key; KeyChar; VirtualKeyCode}.
    #>
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
    <#
    .SYNOPSIS
        Draw a box with optional title at (x,y).
    #>
    param($X = 0, $Y = 0, $Width = 50, $Title = "", $Color = $TuiC.FgBlue)
    $hChar = "═"
    $top = "╔$($hChar * ($Width - 2))╗"
    $mid = "║$(' ' * ($Width - 2))║"
    $bot = "╚$($hChar * ($Width - 2))╝"

    $hline = "$Color$top$($TuiC.Reset)"
    if ($Title) {
        $pad = $Width - $Title.Length - 4
        $leftPad = [Math]::Max(1, [Math]::Floor($pad / 2))
        $rightPad = [Math]::Max(0, $pad - $leftPad)
        $hline = "$Color╔$('═' * $leftPad) $Title $('═' * $rightPad)╗$($TuiC.Reset)"
    }

    Write-TuiLine -X $X -Y $Y -Text $hline
    for ($r = 1; $r -lt $Height - 1; $r++) {
        Write-TuiLine -X $X -Y ($Y + $r) -Text "$Color$mid$($TuiC.Reset)"
    }
    Write-TuiLine -X $X -Y ($Y + $Height - 1) -Text "$Color$bot$($TuiC.Reset)"
}

# ─── Widget: Progress bar ─────────────────────────────────────

function Show-TuiProgress {
    <#
    .SYNOPSIS
        Render a progress bar at (x,y). Percentage and optional label.
    #>
    param($X = 0, $Y = 0, $Percent = 0, $Label = "", $Width = 40)
    $px = [Math]::Max(0, [Math]::Min(100, $Percent))
    $filled = [Math]::Floor($Width * $px / 100)
    $empty = $Width - $filled
    $barFilled = if ($filled -gt 0) { "$($TuiC.FgGreen)$('█' * $filled)$($TuiC.Reset)" } else { "" }
    $barEmpty  = if ($empty -gt 0)  { "$($TuiC.Grey)$('░' * $empty)$($TuiC.Reset)" } else { "" }
    $pct = "$($TuiC.FgBlue)$([Math]::Floor($px))%$($TuiC.Reset)"
    Write-TuiLine -X $X -Y $Y -Text "$barFilled$barEmpty $pct $Label"
}

# ─── Widget: Menu Radio ────────────────────────────────────────

function Show-TuiMenuRadio {
    <#
    .SYNOPSIS
        Radio-button menu. ↑↓/j/k/PgUp/PgDn/Home/End + Enter.
        Returns selected index.
    #>
    param($Title = "", $Options = @(), $DefaultIndex = 0)

    $sel = $DefaultIndex
    $opts = @($Options)
    $scrollOff = 0
    $boxColor = $TuiC.FgBlue

    # Calculate box width
    $labels = $opts | ForEach-Object { if ($_ -is [hashtable]) { $_.label } else { $_ } }
    $maxLabel = ($labels | Measure-Object -Maximum Length).Maximum
    $maxLabel = [Math]::Max($maxLabel, $Title.Length)
    $boxW = $maxLabel + 8
    $availH = (try { [Console]::WindowHeight } catch { 25 }) - 10
    $maxVis = [Math]::Max(3, [Math]::Min($opts.Count, $availH))

    Write-Host ""
    for ($i = 0; $i -lt $maxVis + 3; $i++) { Write-Host "" }
    $top = (try { [Console]::CursorTop } catch { 0 }) - $maxVis - 3

    try { [Console]::CursorVisible = $false } catch {}
    try {
        while ($true) {
            # Clamp scroll offset
            if ($sel -lt $scrollOff) { $scrollOff = $sel }
            if ($sel -ge $scrollOff + $maxVis) { $scrollOff = $sel - $maxVis + 1 }

            New-TuiFrame

            # Title line
            $titleBar = " $Title "
            $paddedTitle = "$boxColor╔$('═' * [Math]::Max(1, $boxW - $titleBar.Length - 2)) $titleBar $('═' * 1)╗$($TuiC.Reset)"
            Write-TuiLine -X 3 -Y $top -Text $paddedTitle

            # Menu items
            $endVis = [Math]::Min($scrollOff + $maxVis, $opts.Count)
            for ($vi = $scrollOff; $vi -lt $endVis; $vi++) {
                $y = $top + 1 + ($vi - $scrollOff)
                $mark = if ($vi -eq $sel) { "$($TuiC.Cyan)◉$($TuiC.Reset)" } else { "$($TuiC.Grey)○$($TuiC.Reset)" }
                $label = if ($opts[$vi] -is [hashtable]) { $opts[$vi].label } else { $opts[$vi] }
                if ($vi -eq $sel) {
                    $line = "║ $mark $($TuiC.Reverse)$label$($TuiC.Reset)$(' ' * ($boxW - $label.Length - 6))║"
                } else {
                    $line = "║ $mark $($TuiC.Grey)$label$($TuiC.Reset)$(' ' * ($boxW - $label.Length - 6))║"
                }
                Write-TuiLine -X 3 -Y $y -Text "$boxColor$line$($TuiC.Reset)"
            }

            # Empty lines if list shorter than box
            for ($vi = $endVis; $vi -lt $scrollOff + $maxVis; $vi++) {
                $y = $top + 1 + ($vi - $scrollOff)
                Write-TuiLine -X 3 -Y $y -Text "$boxColor║$(' ' * $boxW)║$($TuiC.Reset)"
            }

            # Bottom border with scroll indicator
            $scrollTxt = ""
            if ($opts.Count -gt $maxVis) {
                $pct = [Math]::Floor(($scrollOff + $endVis) / $opts.Count * 100)
                $scrollTxt = " ↑ $($scrollOff + 1)-$endVis/$($opts.Count) ↓"
            }
            $botBar = "╚$('═' * ($boxW - 2))╝"
            if ($scrollTxt) {
                $botBar = "╚$('═' * ($boxW - 4 - $scrollTxt.Length))$scrollTxt $('═')╝"
            }
            Write-TuiLine -X 3 -Y ($top + $maxVis + 1) -Text "$boxColor$botBar$($TuiC.Reset)"

            # Help bar
            $help = " ═══ ↑↓/j/k navigate  PgUp/PgDn  Home/End  Enter OK ═══"
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
    <#
    .SYNOPSIS
        Checkbox menu. ↑↓/j/k + Space + Enter. Returns array of bool.
    #>
    param($Title = "", $Options = @())

    $states = @($Options | ForEach-Object { $true })
    $idx = 0
    $opts = @($Options)
    $scrollOff = 0
    $boxColor = $TuiC.FgBlue

    # Calculate box width
    $labels = $opts | ForEach-Object { if ($_ -is [hashtable]) { $_.label } else { $_ } }
    $maxLabel = ($labels | Measure-Object -Maximum Length).Maximum
    $maxLabel = [Math]::Max($maxLabel, $Title.Length)
    $boxW = $maxLabel + 18
    $availH = (try { [Console]::WindowHeight } catch { 25 }) - 10
    $maxVis = [Math]::Max(3, [Math]::Min($opts.Count, $availH))

    Write-Host ""
    for ($i = 0; $i -lt $maxVis + 3; $i++) { Write-Host "" }
    $top = (try { [Console]::CursorTop } catch { 0 }) - $maxVis - 3

    try { [Console]::CursorVisible = $false } catch {}
    try {
        while ($true) {
            if ($idx -lt $scrollOff) { $scrollOff = $idx }
            if ($idx -ge $scrollOff + $maxVis) { $scrollOff = $idx - $maxVis + 1 }

            New-TuiFrame

            # Title line
            $titleBar = " $Title "
            $paddedTitle = "$boxColor╔$('═' * [Math]::Max(1, $boxW - $titleBar.Length - 2)) $titleBar $('═' * 1)╗$($TuiC.Reset)"
            Write-TuiLine -X 3 -Y $top -Text $paddedTitle

            # Menu items
            $endVis = [Math]::Min($scrollOff + $maxVis, $opts.Count)
            for ($vi = $scrollOff; $vi -lt $endVis; $vi++) {
                $y = $top + 1 + ($vi - $scrollOff)
                $box = if ($states[$vi]) { "$($TuiC.FgGreen)☑$($TuiC.Reset)" } else { "$($TuiC.Grey)☐$($TuiC.Reset)" }
                $label = if ($opts[$vi] -is [hashtable]) { $opts[$vi].label } else { $opts[$vi] }
                $desc = if ($opts[$vi] -is [hashtable] -and $opts[$vi].desc) { " $($TuiC.Dim)$($opts[$vi].desc)$($TuiC.Reset)" } else { "" }
                $innerW = $boxW - 4
                if ($vi -eq $idx) {
                    $line = "║ $box $($TuiC.Reverse)$label$($TuiC.Reset)$desc$(' ' * [Math]::Max(0, $innerW - $label.Length - $desc.Length - 4 - 2))║"
                } else {
                    $line = "║ $box $label$desc$(' ' * [Math]::Max(0, $innerW - $label.Length - $desc.Length - 4 - 2))║"
                }
                # Strip ANSI for width calculation
                $cleanDesc = if ($opts[$vi] -is [hashtable] -and $opts[$vi].desc) { $opts[$vi].desc } else { "" }
                $totalStrLen = $label.Length + 4 + 2 + $cleanDesc.Length
                $padding = [Math]::Max(0, $innerW - $totalStrLen)
                if ($vi -eq $idx) {
                    $line = "║ $box $($TuiC.Reverse)$label$($TuiC.Reset)$desc$(' ' * $padding)║"
                } else {
                    $line = "║ $box $label$desc$(' ' * $padding)║"
                }
                Write-TuiLine -X 3 -Y $y -Text "$boxColor$line$($TuiC.Reset)"
            }

            # Empty lines if list shorter than box
            for ($vi = $endVis; $vi -lt $scrollOff + $maxVis; $vi++) {
                $y = $top + 1 + ($vi - $scrollOff)
                Write-TuiLine -X 3 -Y $y -Text "$boxColor║$(' ' * $boxW)║$($TuiC.Reset)"
            }

            # Bottom border with scroll indicator
            $scrollTxt = ""
            if ($opts.Count -gt $maxVis) {
                $endTxt = $endVis
                $scrollTxt = " ↑ $($scrollOff + 1)-$endTxt/$($opts.Count) ↓"
            }
            $botBar = "╚$('═' * ($boxW - 2))╝"
            if ($scrollTxt) {
                $botBar = "╚$('═' * ($boxW - 4 - $scrollTxt.Length))$scrollTxt $('═')╝"
            }
            Write-TuiLine -X 3 -Y ($top + $maxVis + 1) -Text "$boxColor$botBar$($TuiC.Reset)"

            # Help bar
            $help = " ═══ Space toggle  ↑↓/j/k navigate  PgUp/PgDn  Enter OK ═══"
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
    <#
    .SYNOPSIS
        Renders the pwshcode ASCII banner.
    #>
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

# ─── Module export (all functions are already in global scope after dot-source) ──
