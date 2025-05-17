function helptext ($script) {# Show help sections from a script or offer available PSM1/PS1 files if none provided.
$powershell = Split-Path $profile

if ($script -eq "helptext") {$script = $PSCommandPath}

function scripthelp ($section) {# (Internal) Generate the help sections from the comments section of the script.
""; Write-Host -ForegroundColor Yellow ("-" * 100); $pattern = "(?ims)^## ($section.*?)(##|\z)"; $match = [regex]::Match($scripthelp, $pattern); $lines = $match.Groups[1].Value.TrimEnd() -split "`r?`n", 2; Write-Host $lines[0] -ForegroundColor Yellow; Write-Host -ForegroundColor Yellow ("-" * 100)
if ($lines.Count -gt 1) {$lines[1] | Out-String | Out-Host -Paging}; Write-Host -ForegroundColor Yellow ("-" * 100)}

# Present a menu of help-enabled scripts if no parameter was provided.
if (-not $script) {$basedir = Split-Path -Parent $profile; $profileFile = Get-Item -Path $PROFILE -ErrorAction SilentlyContinue; $found = @()
if ($profileFile -and (Get-Content -Raw $profileFile.FullName -ErrorAction SilentlyContinue) -match '##>\s*$') {$found += $profileFile}
$found += Get-ChildItem -Path $basedir -Recurse -Include *.ps1,*.psm1 -ErrorAction SilentlyContinue | Where-Object {($_ | Get-Content -Raw -ErrorAction SilentlyContinue) -match '##>\s*$'}
if (-not $found) {""; return}
Write-Host "`nAvailable Help-Enabled Scripts:`n" -ForegroundColor Cyan
for ($i = 0; $i -lt $found.Count; $i++) {"{0}: {1}" -f ($i + 1), ([System.IO.Path]::GetFileNameWithoutExtension($found[$i].FullName))}
$choice = Read-Host "`nEnter the number of the script to view"
if ($choice -match '^\d+$') {$index = [int]$choice; if ($index -ge 1 -and $index -le $found.Count) {$script = $found[$index - 1].FullName} else {"" ; return}} else {"" ; return}}

# Call the help menu.
$resolved = Resolve-Path $script -ErrorAction SilentlyContinue
if (-not $resolved -or $resolved -notmatch ".psm?1") {$basename = $script; $found = Get-ChildItem -Path $powershell -Recurse -File -Include *.ps1, *.psm1 -ErrorAction SilentlyContinue | Where-Object {[System.IO.Path]::GetFileNameWithoutExtension($_.Name) -ieq $basename}
if ($found.Count -eq 1) {$script = $found[0].FullName} else {""; return}}

if (-not (Resolve-Path $script -ErrorAction SilentlyContinue)) {return}
$scripthelp = Get-Content -Raw -Path $script; $sections = [regex]::Matches($scripthelp, "(?im)^## (.+?)(?=\r?\n)")
if (-not $sections) {Write-Host -f cyan "`nThis is not a HelpText enabled file.`n"; return}
if ($sections.Count -eq 1) {cls; Write-Host "$([System.IO.Path]::GetFileNameWithoutExtension($script)) Help:" -ForegroundColor Cyan; scripthelp $sections[0].Groups[1].Value; ""; return}
$selection = $null
do {cls; Write-Host "$([System.IO.Path]::GetFileNameWithoutExtension($script)) Help Sections:`n" -ForegroundColor Cyan; for ($i = 0; $i -lt $sections.Count; $i++) {
"{0}: {1}" -f ($i + 1), $sections[$i].Groups[1].Value}
if ($selection) {scripthelp $sections[$selection - 1].Groups[1].Value}
$input = Read-Host "`nEnter a section number to view"
if ($input -match '^\d+$') {$index = [int]$input
if ($index -ge 1 -and $index -le $sections.Count) {$selection = $index}
else {$selection = $null}} else {""; return}}
while ($true); return}

Export-ModuleMember -Function helptext

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
## Self-Contained Edition
If however, you want to keep the help menu completely self-contained, perhaps because you want to share your script publicly, then use this body for the help script, instead:

if ($help) {function scripthelp ($section) {# (Internal) Generate the help sections from the comments section of the script.
""; Write-Host -ForegroundColor Yellow ("-" * 100); $pattern = "(?ims)^# # ($section.*?)(# #|\z)"; $match = [regex]::Match($scripthelp, $pattern); $lines = $match.Groups[1].Value.TrimEnd() -split "`r?`n", 2; Write-Host $lines[0] -ForegroundColor Yellow; Write-Host -ForegroundColor Yellow ("-" * 100)
if ($lines.Count -gt 1) {$lines[1] | Out-String | Out-Host -Paging}; Write-Host -ForegroundColor Yellow ("-" * 100)}
$scripthelp = Get-Content -Raw -Path $PSCommandPath; $sections = [regex]::Matches($scripthelp, "(?im)^# # (.+?)(?=\r?\n)")
if ($sections.Count -eq 1) {cls; Write-Host "$([System.IO.Path]::GetFileNameWithoutExtension($PSCommandPath)) Help:" -ForegroundColor Cyan; scripthelp $sections[0].Groups[1].Value; ""; return}
$selection = $null
do {cls; Write-Host "$([System.IO.Path]::GetFileNameWithoutExtension($PSCommandPath)) Help Sections:`n" -ForegroundColor Cyan; for ($i = 0; $i -lt $sections.Count; $i++) {
"{0}: {1}" -f ($i + 1), $sections[$i].Groups[1].Value}
if ($selection) {scripthelp $sections[$selection - 1].Groups[1].Value}
$input = Read-Host "`nEnter a section number to view"
if ($input -match '^\d+$') {$index = [int]$input
if ($index -ge 1 -and $index -le $sections.Count) {$selection = $index}
else {$selection = $null}} else {""; return}}
while ($true); return}

Please note that in the expanded version of the script above, there are extra spaces between the hashtags "#", in order to prevent them from breaking this help screen formatting.
You will need to remove those spaces in order to make it work.
## Help Section Design
You will then place your help sections at the very bottom of the script file inside an extended comments section like this:

< #
# # Overview

Details...
# # Additional sections

Add as many sections as you need, separated by the double hashes for each new title.
# # >

Remember to close with two hashes and a ">" at the end of the file and do not add spaces around the hashes, which are shown here only to prevent the script from breaking.
##>
