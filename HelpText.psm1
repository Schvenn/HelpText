function helptext ($script) {# Show help sections from a script or offer available PSM1/PS1 files if none provided.
$powershell = Split-Path $profile

if ($script -eq "helptext") {$script = $PSCommandPath}

# Modify fields sent to it with proper word wrapping.
function wordwrap ($field, $maximumlinelength) {if ($null -eq $field) {return $null}
$breakchars = ',.;?!\/ '; $wrapped = @()
if (-not $maximumlinelength) {[int]$maximumlinelength = (100, $Host.UI.RawUI.WindowSize.Width | Measure-Object -Maximum).Maximum}
if ($maximumlinelength -lt 60) {[int]$maximumlinelength = 60}
if ($maximumlinelength -gt $Host.UI.RawUI.BufferSize.Width) {[int]$maximumlinelength = $Host.UI.RawUI.BufferSize.Width}
foreach ($line in $field -split "`n", [System.StringSplitOptions]::None) {if ($line -eq "") {$wrapped += ""; continue}
$remaining = $line
while ($remaining.Length -gt $maximumlinelength) {$segment = $remaining.Substring(0, $maximumlinelength); $breakIndex = -1
foreach ($char in $breakchars.ToCharArray()) {$index = $segment.LastIndexOf($char)
if ($index -gt $breakIndex) {$breakIndex = $index}}
if ($breakIndex -lt 0) {$breakIndex = $maximumlinelength - 1}
$chunk = $segment.Substring(0, $breakIndex + 1); $wrapped += $chunk; $remaining = $remaining.Substring($breakIndex + 1)}
if ($remaining.Length -gt 0 -or $line -eq "") {$wrapped += $remaining}}
return ($wrapped -join "`n")}

# Display a horizontal line.
function line ($colour, $length, [switch]$pre, [switch]$post, [switch]$double) {if (-not $length) {[int]$length = (100, $Host.UI.RawUI.WindowSize.Width | Measure-Object -Maximum).Maximum}
if ($length) {if ($length -lt 60) {[int]$length = 60}
if ($length -gt $Host.UI.RawUI.BufferSize.Width) {[int]$length = $Host.UI.RawUI.BufferSize.Width}}
if ($pre) {Write-Host ""}
$character = if ($double) {"="} else {"-"}
Write-Host -f $colour ($character * $length)
if ($post) {Write-Host ""}}

# Present a menu of help-enabled scripts if no parameter was provided.
if (-not $script) {$basedir = Split-Path -Parent $profile; $profileFile = Get-Item -Path $PROFILE -ErrorAction SilentlyContinue; $found = @()
if ($profileFile -and (Get-Content -Raw $profileFile.FullName -ErrorAction SilentlyContinue) -match '##>\s*$') {$found += $profileFile}
$found += Get-ChildItem -Path $basedir -Recurse -Include *.ps1,*.psm1 -ErrorAction SilentlyContinue | Where-Object {($_ | Get-Content -Raw -ErrorAction SilentlyContinue) -match '##>\s*$'}
if (-not $found) {""; return}
Write-Host "`nAvailable Help-Enabled Modules:`n" -f cyan
for ($i = 0; $i -lt $found.Count; $i++) {"{0}: {1}" -f ($i + 1), ([System.IO.Path]::GetFileNameWithoutExtension($found[$i].FullName))}
$choice = Read-Host "`nEnter the number of the module to view"
if ($choice -match '^\d+$') {$index = [int]$choice; if ($index -ge 1 -and $index -le $found.Count) {$script = $found[$index - 1].FullName} else {"" ; return}} else {"" ; return}}

# Find the help menu from an alias or function.
$target = Get-Command -Name $script -ErrorAction SilentlyContinue
if ($target) {if ($target.CommandType -in 'Alias', 'Function') {if ($target.Module -and $target.Module.Path) {$script = $target.Module.Path}
elseif ($target.ScriptBlock.File) {$script = $target.ScriptBlock.File}
elseif ($target.ResolvedCommand -and $target.ResolvedCommand.Source) {$script = $target.ResolvedCommand.Source}
else {return}}}

# Find the help menu from a script or module path.
$resolved = Resolve-Path $script -ErrorAction SilentlyContinue
if (-not $resolved -or $resolved -notmatch ".psm?1") {$basename = $script; $found = Get-ChildItem -Path $powershell -Recurse -File -Include *.ps1, *.psm1 -ErrorAction SilentlyContinue | Where-Object {[System.IO.Path]::GetFileNameWithoutExtension($_.Name) -ieq $basename}
if ($found.Count -eq 1) {$script = $found[0].FullName} else {""; return}}

# Present help menu for selected script.
function help {# Inline help.
# Select content.
$scripthelp = Get-Content -Raw -Path $PSCommandPath; $sections = [regex]::Matches($scripthelp, "(?im)^## (.+?)(?=\r?\n)"); $selection = $null; $lines = @(); $wrappedLines = @(); $position = 0; $pageSize = 30; $inputBuffer = ""

function scripthelp ($section) {$pattern = "(?ims)^## ($([regex]::Escape($section)).*?)(?=^##|\z)"; $match = [regex]::Match($scripthelp, $pattern); $lines = $match.Groups[1].Value.TrimEnd() -split "`r?`n", 2; if ($lines.Count -gt 1) {$wrappedLines = (wordwrap $lines[1] 100) -split "`n", [System.StringSplitOptions]::None}
else {$wrappedLines = @()}
$position = 0}

# Display Table of Contents.
while ($true) {cls; Write-Host -f cyan "$(Get-ChildItem (Split-Path $PSCommandPath) | Where-Object { $_.FullName -ieq $PSCommandPath } | Select-Object -ExpandProperty BaseName) Help Sections:`n"

if ($sections.Count -gt 7) {$half = [Math]::Ceiling($sections.Count / 2)
for ($i = 0; $i -lt $half; $i++) {$leftIndex = $i; $rightIndex = $i + $half; $leftNumber  = "{0,2}." -f ($leftIndex + 1); $leftLabel   = " $($sections[$leftIndex].Groups[1].Value)"; $leftOutput  = [string]::Empty

if ($rightIndex -lt $sections.Count) {$rightNumber = "{0,2}." -f ($rightIndex + 1); $rightLabel  = " $($sections[$rightIndex].Groups[1].Value)"; Write-Host -f cyan $leftNumber -n; Write-Host -f white $leftLabel -n; $pad = 40 - ($leftNumber.Length + $leftLabel.Length)
if ($pad -gt 0) {Write-Host (" " * $pad) -n}; Write-Host -f cyan $rightNumber -n; Write-Host -f white $rightLabel}
else {Write-Host -f cyan $leftNumber -n; Write-Host -f white $leftLabel}}}

else {for ($i = 0; $i -lt $sections.Count; $i++) {Write-Host -f cyan ("{0,2}. " -f ($i + 1)) -n; Write-Host -f white "$($sections[$i].Groups[1].Value)"}}

# Display Header.
line yellow 100
if ($lines.Count -gt 0) {Write-Host  -f yellow $lines[0]}
else {Write-Host "Choose a section to view." -f darkgray}
line yellow 100

# Display content.
$end = [Math]::Min($position + $pageSize, $wrappedLines.Count)
for ($i = $position; $i -lt $end; $i++) {Write-Host -f white $wrappedLines[$i]}

# Pad display section with blank lines.
for ($j = 0; $j -lt ($pageSize - ($end - $position)); $j++) {Write-Host ""}

# Display menu options.
line yellow 100; Write-Host -f white "[↑/↓]  [PgUp/PgDn]  [Home/End]  |  [#] Select section  |  [Q] Quit  " -n; if ($inputBuffer.length -gt 0) {Write-Host -f cyan "section: $inputBuffer" -n}; $key = [System.Console]::ReadKey($true)

# Define interaction.
switch ($key.Key) {'UpArrow' {if ($position -gt 0) { $position-- }; $inputBuffer = ""}
'DownArrow' {if ($position -lt ($wrappedLines.Count - $pageSize)) { $position++ }; $inputBuffer = ""}
'PageUp' {$position -= 30; if ($position -lt 0) {$position = 0}; $inputBuffer = ""}
'PageDown' {$position += 30; $maxStart = [Math]::Max(0, $wrappedLines.Count - $pageSize); if ($position -gt $maxStart) {$position = $maxStart}; $inputBuffer = ""}
'Home' {$position = 0; $inputBuffer = ""}
'End' {$maxStart = [Math]::Max(0, $wrappedLines.Count - $pageSize); $position = $maxStart; $inputBuffer = ""}

'Enter' {if ($inputBuffer -eq "") {"`n"; return}
elseif ($inputBuffer -match '^\d+$') {$index = [int]$inputBuffer
if ($index -ge 1 -and $index -le $sections.Count) {$selection = $index; $pattern = "(?ims)^## ($([regex]::Escape($sections[$selection-1].Groups[1].Value)).*?)(?=^##|\z)"; $match = [regex]::Match($scripthelp, $pattern); $block = $match.Groups[1].Value.TrimEnd(); $lines = $block -split "`r?`n", 2
if ($lines.Count -gt 1) {$wrappedLines = (wordwrap $lines[1] 100) -split "`n", [System.StringSplitOptions]::None}
else {$wrappedLines = @()}
$position = 0}}
$inputBuffer = ""}

default {$char = $key.KeyChar
if ($char -match '^[Qq]$') {"`n"; return}
elseif ($char -match '^\d$') {$inputBuffer += $char}
else {$inputBuffer = ""}}}}}

help $script}

Export-ModuleMember -Function helptext

# Helptext.

<#
## Overview
This function displays help sections embedded in script comments and has three methods of use:

• If you run it at the command line without a parameter, it will present you with a menu of all help-enabled scripts in and below the $profile directory.

• You can also run it at the command line by passing it a script name, which will load that scripts help menu, if one is configured.

• Finally, you can use it natively, inside a script, as it was originally intended.

If you use it inside a script, you need to add the following content to that script:

     param ([switch]$help)
     if ($help) {helptext $PSCommandPath}

The parameter allows -help to be an option for the script and the "if" section ensures this function is called to handle the workload.
## Self-Contained Edition (pre-requisites)
If you want to keep the help menu completely self-contained within your module then add a help parameter to the module or script:

param ([switch]$help)

You should also include the wordwrap and line functions for proper formatting:

# Modify fields sent to it with proper word wrapping.
function wordwrap ($field, $maximumlinelength) {if ($null -eq $field) {return $null}
$breakchars = ',.;?!\/ '; $wrapped = @()
if (-not $maximumlinelength) {[int]$maximumlinelength = (100, $Host.UI.RawUI.WindowSize.Width | Measure-Object -Maximum).Maximum}
if ($maximumlinelength -lt 60) {[int]$maximumlinelength = 60}
if ($maximumlinelength -gt $Host.UI.RawUI.BufferSize.Width) {[int]$maximumlinelength = $Host.UI.RawUI.BufferSize.Width}
foreach ($line in $field -split "`n", [System.StringSplitOptions]::None) {if ($line -eq "") {$wrapped += ""; continue}
$remaining = $line
while ($remaining.Length -gt $maximumlinelength) {$segment = $remaining.Substring(0, $maximumlinelength); $breakIndex = -1
foreach ($char in $breakchars.ToCharArray()) {$index = $segment.LastIndexOf($char)
if ($index -gt $breakIndex) {$breakIndex = $index}}
if ($breakIndex -lt 0) {$breakIndex = $maximumlinelength - 1}
$chunk = $segment.Substring(0, $breakIndex + 1); $wrapped += $chunk; $remaining = $remaining.Substring($breakIndex + 1)}
if ($remaining.Length -gt 0 -or $line -eq "") {$wrapped += $remaining}}
return ($wrapped -join "`n")}

# Display a horizontal line.
function line ($colour, $length, [switch]$pre, [switch]$post, [switch]$double) {if (-not $length) {[int]$length = (100, $Host.UI.RawUI.WindowSize.Width | Measure-Object -Maximum).Maximum}
if ($length) {if ($length -lt 60) {[int]$length = 60}
if ($length -gt $Host.UI.RawUI.BufferSize.Width) {[int]$length = $Host.UI.RawUI.BufferSize.Width}}
if ($pre) {Write-Host ""}
$character = if ($double) {"="} else {"-"}
Write-Host -f $colour ($character * $length)
if ($post) {Write-Host ""}}
## Self-Contained Edition (simple version)
This is the simplified version, which features a dynamically set window height and no scrolling.

if ($help) {# Inline help.
function scripthelp ($section) {# (Internal) Generate the help sections from the comments section of the script.
""; Write-Host -f yellow ("-" * 100); $pattern = "(?ims)^## ($section.*?)(##|\z)"; $match = [regex]::Match($scripthelp, $pattern); $lines = $match.Groups[1].Value.TrimEnd() -split "`r?`n", 2; Write-Host $lines[0] -f yellow; Write-Host -f yellow ("-" * 100)
if ($lines.Count -gt 1) {wordwrap $lines[1] 100| Out-String | Out-Host -Paging}; Write-Host -f yellow ("-" * 100)}
$scripthelp = Get-Content -Raw -Path $PSCommandPath; $sections = [regex]::Matches($scripthelp, "(?im)^## (.+?)(?=\r?\n)")
if ($sections.Count -eq 1) {cls; Write-Host "$([System.IO.Path]::GetFileNameWithoutExtension($PSCommandPath)) Help:" -f cyan; scripthelp $sections[0].Groups[1].Value; ""; return}

$selection = $null
do {cls; Write-Host "$([System.IO.Path]::GetFileNameWithoutExtension($PSCommandPath)) Help Sections:`n" -f cyan; for ($i = 0; $i -lt $sections.Count; $i++) {
"{0}: {1}" -f ($i + 1), $sections[$i].Groups[1].Value}
if ($selection) {scripthelp $sections[$selection - 1].Groups[1].Value}
$input = Read-Host "`nEnter a section number to view"
if ($input -match '^\d+$') {$index = [int]$input
if ($index -ge 1 -and $index -le $sections.Count) {$selection = $index}
else {$selection = $null}} else {""; return}}
while ($true); return}

# External call to help.
if ($help) {help; return}
## Self-Contained Edition (with scrolling)
This is the full-featured version which includes scrolling and fixed window length:

param ([switch]$help)

function help {# Inline help.
# Select content.
$scripthelp = Get-Content -Raw -Path $PSCommandPath; $sections = [regex]::Matches($scripthelp, "(?im)^## (.+?)(?=\r?\n)"); $selection = $null; $lines = @(); $wrappedLines = @(); $position = 0; $pageSize = 30; $inputBuffer = ""

function scripthelp ($section) {$pattern = "(?ims)^## ($([regex]::Escape($section)).*?)(?=^##|\z)"; $match = [regex]::Match($scripthelp, $pattern); $lines = $match.Groups[1].Value.TrimEnd() -split "`r?`n", 2; if ($lines.Count -gt 1) {$wrappedLines = (wordwrap $lines[1] 100) -split "`n", [System.StringSplitOptions]::None}
else {$wrappedLines = @()}
$position = 0}

# Display Table of Contents.
while ($true) {cls; Write-Host -f cyan "$([System.IO.Path]::GetFileNameWithoutExtension($PSCommandPath)) Help Sections:`n"
if ($sections.Count -gt 7) {$half = [Math]::Ceiling($sections.Count / 2)
for ($i = 0; $i -lt $half; $i++) {$leftIndex = $i; $rightIndex = $i + $half; $leftText = ("{0,2}. {1}" -f ($leftIndex + 1), $sections[$leftIndex].Groups[1].Value)
if ($rightIndex -lt $sections.Count) {$rightText = ("{0,2}. {1}" -f ($rightIndex + 1), $sections[$rightIndex].Groups[1].Value); Write-Host -f cyan ("{0,-40}" -f $leftText) -n; Write-Host -f cyan ("{0}" -f $rightText)}
else {Write-Host -f cyan $leftText}}}
else {for ($i = 0; $i -lt $sections.Count; $i++) {Write-Host -f cyan ("{0,2}." -f ($i + 1)) -n; Write-Host -f white " $($sections[$i].Groups[1].Value)"}}

# Display Header.
line yellow 100
if ($lines.Count -gt 0) {Write-Host  -f yellow $lines[0]}
else {Write-Host "Choose a section to view." -f darkgray}
line yellow 100

# Display content.
$end = [Math]::Min($position + $pageSize, $wrappedLines.Count)
for ($i = $position; $i -lt $end; $i++) {Write-Host -f white $wrappedLines[$i]}

# Pad display section with blank lines.
for ($j = 0; $j -lt ($pageSize - ($end - $position)); $j++) {Write-Host ""}

# Display menu options.
line yellow 100; Write-Host -f white "[↑/↓]  [PgUp/PgDn]  [Home/End]  |  [#] Select section  |  [Q] Quit  " -n; Write-Host -f cyan $inputBuffer -n; $key = [System.Console]::ReadKey($true)

# Define interaction.
switch ($key.Key) {'UpArrow' {if ($position -gt 0) {$position--}; $inputBuffer = ""}
'DownArrow' {if ($position -lt ($wrappedLines.Count - $pageSize)) {$position++}; $inputBuffer = ""}
'PageUp' {$position -= 30; if ($position -lt 0) {$position = 0}; $inputBuffer = ""}
'PageDown' {$position += 30; $maxStart = [Math]::Max(0, $wrappedLines.Count - $pageSize); if ($position -gt $maxStart) {$position = $maxStart}; $inputBuffer = ""}
'Home' {$position = 0; $inputBuffer = ""}
'End' {$maxStart = [Math]::Max(0, $wrappedLines.Count - $pageSize); $position = $maxStart; $inputBuffer = ""}

'Enter' {if ($inputBuffer -eq "") {"`n"; return}
elseif ($inputBuffer -match '^\d+$') {$index = [int]$inputBuffer
if ($index -ge 1 -and $index -le $sections.Count) {$selection = $index; $pattern = "(?ims)^## ($([regex]::Escape($sections[$selection-1].Groups[1].Value)).*?)(?=^##|\z)"; $match = [regex]::Match($scripthelp, $pattern); $block = $match.Groups[1].Value.TrimEnd(); $lines = $block -split "`r?`n", 2
if ($lines.Count -gt 1) {$wrappedLines = (wordwrap $lines[1] 100) -split "`n", [System.StringSplitOptions]::None}
else {$wrappedLines = @()}
$position = 0}}
$inputBuffer = ""}

default {$char = $key.KeyChar
if ($char -match '^[Qq]$') {"`n"; return}
elseif ($char -match '^\d$') {$inputBuffer += $char}
else {$inputBuffer = ""}}}}}

# External call to help.
if ($help) {help; return}
## Help Section Design
You will then place your help sections at the very bottom of the script file inside an extended comments section like this:

<#
## Overview

Details...
## Additional sections

Add as many sections as you need, separated by the double hashes for each new title.
##>

Remember to close with "##>" at the end of the file.
## License
MIT License

Copyright © 2025 Craig Plath

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell 
copies of the Software, and to permit persons to whom the Software is 
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in 
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE 
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, 
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN 
THE SOFTWARE.
##>
