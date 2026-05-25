# CombDir - Combine Directory Files into Single Text File
# Combdir combines all your code files to make a single llms.txt file 
# for easy upload to your favorite AI service. Recommended for Google AI Studio.
# Version: 1.4

param(
    [Parameter(Position=0)]
    [string]$Path = ".",
    
    [Parameter(Position=1)]
    [string]$Output = "",
    
    [Alias("r")]
    [switch]$Recursive,
    
    [Alias("h")]
    [switch]$Help,
    
    [string]$Include = "*.*",
    
    [string]$Exclude = "*.config,*.env,.env*",
    
    [switch]$AddTimestamp,
    
    [int]$MaxFileSize = 0,
    
    [switch]$IgnoreBinary,
    
    [switch]$SkipNodeModules,
    
    [switch]$GitIgnore,

    # Skip any folder that contains more than this many files (0 = no limit).
    # Useful for ignoring large UI component libraries like components/ui.
    [int]$MaxFilesPerFolder = 0,

    # Comma-separated list of folder names to always skip regardless of file count.
    # Matched against every path segment, not just the leaf folder.
    # Example: -SkipFolders "ui,icons,generated"
    [string]$SkipFolders = ""
)

function Show-Help {
    Write-Host @"

    ----------------------------------------------
 ██████╗ ██████╗ ███╗   ███╗██████╗ ██████╗ ██╗██████╗ 
██╔════╝██╔═══██╗████╗ ████║██╔══██╗██╔══██╗██║██╔══██╗
██║     ██║   ██║██╔████╔██║██████╔╝██║  ██║██║██████╔╝
██║     ██║   ██║██║╚██╔╝██║██╔══██╗██║  ██║██║██╔══██╗
╚██████╗╚██████╔╝██║ ╚═╝ ██║██████╔╝██████╔╝██║██║  ██║
 ╚═════╝ ╚═════╝ ╚═╝     ╚═╝╚═════╝ ╚═════╝ ╚═╝╚═╝  ╚═╝
      ----------------------------------------------

CombDir - Combine Directory Files into Single Text File
========================================================

Combdir combines all your code files to make a single llms.txt file 
for easy upload to your favorite AI service. Recommended for Google AI Studio.

USAGE:
    combdir [Path] [Output] [Options]

PARAMETERS:
    Path              Directory path to process (default: current directory)
    Output            Output file path (default: combined_YYYYMMDD_HHMMSS.txt)

OPTIONS:
    -r, -Recursive         Include files from subdirectories
                          (also prints folder structure at top)
    -h, -Help             Show this help message
    
    -Include <pattern>     File pattern to include (default: *.*)
                          Examples: "*.dart", "*.cs,*.js", "*.txt"
    
    -Exclude <pattern>     File pattern to exclude
                          Examples: ".env", "*.exe", "*.dll,*.bin"
    
    -GitIgnore            Use .gitignore file to determine exclusions
                          (automatically includes .git folder)
    
    -AddTimestamp         Add timestamp to each file entry
    -MaxFileSize <KB>     Skip files larger than specified KB (0 = no limit)
    -IgnoreBinary         Skip binary files automatically
    -SkipNodeModules      Skip node_modules folder and its contents
    -MaxFilesPerFolder <N> Skip any folder containing more than N files (0 = no limit)
                          Great for shadcn/ui style component libraries
    -SkipFolders <names>  Comma-separated folder names to always skip
                          Matched against every segment in the path
                          Examples: "ui", "ui,icons", "generated,dist"

NOTE:
    Image files, hidden files (starting with '.'), and folders whose name
    starts with '.' (e.g. .next, .turbo, .git, .cache) are automatically excluded.

EXAMPLES:
    # Combine all files in current directory
    combdir
    
    # Combine lib folder with subdirectories (includes folder tree)
    combdir .\lib -r
    
    # Use .gitignore to exclude files
    combdir . -GitIgnore -r
    
    # Combine with .gitignore and specific output
    combdir .\src llms.txt -GitIgnore -r
    
    # Combine specific file types
    combdir .\src llms.txt -Include "*.cs,*.js" -r
    
    # Exclude certain files
    combdir . -Exclude *.exe,*.dll -r
    
    # Custom output location with timestamp
    combdir .\project C:\output\llms.txt -AddTimestamp -r
    
    # Skip large files
    combdir . -MaxFileSize 500 -IgnoreBinary -r
    
    # Skip node_modules folder
    combdir . -SkipNodeModules -r
    
    # Skip any folder with more than 10 files (e.g. shadcn components/ui)
    combdir . -MaxFilesPerFolder 10 -r
    
    # Always skip specific folder names wherever they appear in the tree
    combdir . -SkipFolders "ui,icons" -r
    
    # Combine both: skip dense folders AND named folders
    combdir . -MaxFilesPerFolder 10 -SkipFolders "generated" -r

OUTPUT FORMAT:
    <------ Start filename.ext ------>
    code content
    code content
    ...
    <------ End filename.ext ------>

"@ -ForegroundColor Cyan
    exit
}

function Test-BinaryFile {
    param([string]$FilePath)
    
    $bytes = [System.IO.File]::ReadAllBytes($FilePath)
    $sampleSize = [Math]::Min(8000, $bytes.Length)
    
    for ($i = 0; $i -lt $sampleSize; $i++) {
        if ($bytes[$i] -eq 0) {
            return $true
        }
    }
    return $false
}

function Test-ImageFile {
    param([string]$FilePath)
    
    $imageExtensions = @('.jpg', '.jpeg', '.png', '.gif', '.bmp', '.tiff', '.tif', '.ico', '.svg', '.webp', '.heic', '.heif', '.raw', '.cr2', '.nef', '.arw')
    $extension = [System.IO.Path]::GetExtension($FilePath).ToLower()
    
    return $imageExtensions -contains $extension
}

function Test-HiddenFile {
    param([string]$FileName)
    
    return $FileName.StartsWith('.')
}

# NEW: Returns $true if any directory segment in the path starts with '.'
# e.g. catches .next\chunks\foo.js, .turbo\bar.js, etc.
function Test-InHiddenDirectory {
    param(
        [string]$FullFilePath,
        [string]$BasePath
    )

    # Strip the base path to get the relative portion, then split into segments
    $relative = $FullFilePath.Substring($BasePath.Length).TrimStart('\', '/')
    $segments  = $relative -split '[\\/]'

    # Check every segment except the last one (which is the filename itself)
    for ($i = 0; $i -lt ($segments.Length - 1); $i++) {
        if ($segments[$i].StartsWith('.')) {
            return $true
        }
    }
    return $false
}

# Returns $true if any directory segment in the path matches a name in $SkipList.
# e.g. -SkipFolders "ui,icons" will catch components\ui\button.tsx anywhere in the tree.
function Test-InSkippedFolder {
    param(
        [string]$FullFilePath,
        [string]$BasePath,
        [string[]]$SkipList
    )

    if ($SkipList.Count -eq 0) { return $false }

    $relative = $FullFilePath.Substring($BasePath.Length).TrimStart('\', '/')
    $segments  = $relative -split '[\\/]'

    # Check every directory segment (skip the last, which is the filename)
    for ($i = 0; $i -lt ($segments.Length - 1); $i++) {
        if ($SkipList -contains $segments[$i]) {
            return $true
        }
    }
    return $false
}

function Get-FolderTree {
    param(
        [string]$FolderPath,
        [string[]]$GitIgnorePatterns = @(),
        [bool]$UseGitIgnore = $false,
        [bool]$SkipNodeMods = $false
    )
    
    Write-Host "Generating folder structure..." -ForegroundColor Yellow
    
    try {
        if ($UseGitIgnore -or $SkipNodeMods) {
            # Build custom tree
            $tree = New-Object System.Text.StringBuilder
            $tree.AppendLine($FolderPath) | Out-Null
            
            function Add-TreeLevel {
                param(
                    [string]$Path,
                    [string]$Prefix = "",
                    [bool]$IsLast = $true
                )
                
                $items = Get-ChildItem -Path $Path -Force | Where-Object {
                    $item = $_
                    
                    # Skip hidden files/folders (starting with '.')
                    if ($item.Name.StartsWith('.')) {
                        return $false
                    }
                    
                    # Skip node_modules
                    if ($SkipNodeMods -and $item.Name -eq "node_modules") {
                        return $false
                    }
                    
                    # Skip gitignored items
                    if ($UseGitIgnore -and $GitIgnorePatterns.Count -gt 0) {
                        if (Test-GitIgnoreMatch -FilePath $item.FullName -BasePath $FolderPath -Patterns $GitIgnorePatterns) {
                            return $false
                        }
                    }
                    
                    return $true
                }
                
                for ($i = 0; $i -lt $items.Count; $i++) {
                    $item = $items[$i]
                    $isLastItem = ($i -eq $items.Count - 1)
                    $branch = if ($isLastItem) { "└── " } else { "├── " }
                    
                    $tree.AppendLine("$Prefix$branch$($item.Name)") | Out-Null
                    
                    if ($item.PSIsContainer) {
                        $newPrefix = $Prefix + $(if ($isLastItem) { "    " } else { "│   " })
                        Add-TreeLevel -Path $item.FullName -Prefix $newPrefix -IsLast $isLastItem
                    }
                }
            }
            
            Add-TreeLevel -Path $FolderPath
            return $tree.ToString()
        } else {
            # Use tree command
            $treeOutput = tree $FolderPath /F | Out-String
            return $treeOutput
        }
    } catch {
        return "Unable to generate folder tree: $($_.Exception.Message)"
    }
}

function Get-GitIgnorePatterns {
    param([string]$BasePath)
    
    $gitignorePath = Join-Path $BasePath ".gitignore"
    
    if (-not (Test-Path $gitignorePath)) {
        Write-Host "No .gitignore file found at: $gitignorePath" -ForegroundColor Yellow
        return @()
    }
    
    Write-Host "Loading .gitignore patterns from: $gitignorePath" -ForegroundColor Cyan
    
    $patterns = @()
    $lines = Get-Content $gitignorePath
    
    foreach ($line in $lines) {
        # Skip empty lines and comments
        $line = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith('#')) {
            continue
        }
        
        # Convert gitignore pattern to PowerShell wildcard pattern
        $pattern = $line
        
        # Remove leading slash
        if ($pattern.StartsWith('/')) {
            $pattern = $pattern.Substring(1)
        }
        
        # Convert ** to *
        $pattern = $pattern -replace '\*\*', '*'
        
        $patterns += $pattern
    }
    
    # Always exclude .git folder
    $patterns += ".git"
    $patterns += ".git/*"
    
    Write-Host "Loaded $($patterns.Count) ignore patterns" -ForegroundColor Green
    
    return $patterns
}

function Test-GitIgnoreMatch {
    param(
        [string]$FilePath,
        [string]$BasePath,
        [string[]]$Patterns
    )
    
    # Get relative path
    $relativePath = $FilePath.Substring($BasePath.Length).TrimStart('\', '/')
    $relativePath = $relativePath -replace '\\', '/'
    
    foreach ($pattern in $Patterns) {
        $pattern = $pattern -replace '\\', '/'
        
        # Directory pattern (ends with /)
        if ($pattern.EndsWith('/')) {
            $dirPattern = $pattern.TrimEnd('/')
            if ($relativePath -like "$dirPattern/*" -or $relativePath -eq $dirPattern) {
                return $true
            }
        }
        # File or directory pattern
        else {
            # Exact match or wildcard match
            if ($relativePath -like $pattern -or $relativePath -like "*/$pattern") {
                return $true
            }
            
            # Check if any parent directory matches
            $parts = $relativePath -split '/'
            for ($i = 0; $i -lt $parts.Length; $i++) {
                $partialPath = ($parts[0..$i] -join '/')
                if ($partialPath -like $pattern) {
                    return $true
                }
            }
        }
    }
    
    return $false
}

# Show help if requested
if ($Help) {
    Show-Help
}

# Set default output file with timestamp
if ([string]::IsNullOrEmpty($Output)) {
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $Output = "combined_$timestamp.txt"
}

# Resolve full paths
$Path = Resolve-Path $Path -ErrorAction Stop
$Output = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Output)

# Get absolute path for output file (for comparison during filtering)
$outputFullPath = [System.IO.Path]::GetFullPath($Output)

# Parse include patterns
$includePatterns = $Include -split ','

# Parse exclude patterns
$excludePatterns = if ($Exclude) { $Exclude -split ',' } else { @() }

# Parse SkipFolders into a trimmed list
$skipFolderList = if ($SkipFolders) {
    ($SkipFolders -split ',') | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
} else { @() }

# Load .gitignore patterns if requested
$gitignorePatterns = @()
if ($GitIgnore) {
    $gitignorePatterns = Get-GitIgnorePatterns -BasePath $Path
}

# Get files
Write-Host " ██████╗ ██████╗ ███╗   ███╗██████╗ ██████╗ ██╗██████╗ 
██╔════╝██╔═══██╗████╗ ████║██╔══██╗██╔══██╗██║██╔══██╗
██║     ██║   ██║██╔████╔██║██████╔╝██║  ██║██║██████╔╝
██║     ██║   ██║██║╚██╔╝██║██╔══██╗██║  ██║██║██╔══██╗
╚██████╗╚██████╔╝██║ ╚═╝ ██║██████╔╝██████╔╝██║██║  ██║
 ╚═════╝ ╚═════╝ ╚═╝     ╚═╝╚═════╝ ╚═════╝ ╚═╝╚═╝  ╚═╝
                                                            
        Scanning directory: $Path" -ForegroundColor Yellow

$getChildItemParams = @{
    Path = $Path
    File = $true
}

if ($Recursive) {
    $getChildItemParams.Recurse = $true
}

# Get all files and filter
$allFiles = Get-ChildItem @getChildItemParams

# Track skip reasons
$skipStats = @{
    'gitignore'    = 0
    'node_modules' = 0
    'hidden'       = 0
    'hidden_dir'   = 0
    'skip_folder'  = 0
    'dense_folder' = 0
    'image'        = 0
    'large'        = 0
    'binary'       = 0
    'self'         = 0
}

$files = $allFiles | Where-Object {
    $file = $_
    
    # Skip the output file itself and the script file
    if ($file.FullName -eq $outputFullPath) {
        $skipStats['self']++
        return $false
    }
    
    # Skip this script file
    if ($file.Name -eq "combdir.ps1" -or $file.Name -like "combined_*.txt") {
        $skipStats['self']++
        return $false
    }
    
    # Check .gitignore patterns first
    if ($GitIgnore -and $gitignorePatterns.Count -gt 0) {
        if (Test-GitIgnoreMatch -FilePath $file.FullName -BasePath $Path -Patterns $gitignorePatterns) {
            $skipStats['gitignore']++
            return $false
        }
    }
    
    # Skip node_modules folder if flag is set
    if ($SkipNodeModules -and $file.FullName -match '\\node_modules\\') {
        $skipStats['node_modules']++
        return $false
    }
    
    # Skip hidden files (files whose own name starts with '.')
    if (Test-HiddenFile $file.Name) {
        $skipStats['hidden']++
        return $false
    }

    # NEW: Skip files that live inside a hidden directory (.next, .turbo, .git, .cache, etc.)
    if (Test-InHiddenDirectory -FullFilePath $file.FullName -BasePath $Path) {
        $skipStats['hidden_dir']++
        return $false
    }

    # Skip files inside explicitly named folders (-SkipFolders "ui,icons,generated")
    if ($skipFolderList.Count -gt 0 -and (Test-InSkippedFolder -FullFilePath $file.FullName -BasePath $Path -SkipList $skipFolderList)) {
        $skipStats['skip_folder']++
        return $false
    }
    
    # Skip image files
    if (Test-ImageFile $file.FullName) {
        $skipStats['image']++
        return $false
    }
    
    $matchesInclude = $false
    
    # Check include patterns
    foreach ($pattern in $includePatterns) {
        if ($file.Name -like $pattern.Trim()) {
            $matchesInclude = $true
            break
        }
    }
    
    if (-not $matchesInclude) { return $false }
    
    # Check exclude patterns
    foreach ($pattern in $excludePatterns) {
        if ($file.Name -like $pattern.Trim()) {
            return $false
        }
    }
    
    # Check file size
    if ($MaxFileSize -gt 0 -and ($file.Length / 1KB) -gt $MaxFileSize) {
        $skipStats['large']++
        return $false
    }
    
    # Check if binary
    if ($IgnoreBinary -and (Test-BinaryFile $file.FullName)) {
        $skipStats['binary']++
        return $false
    }
    
    return $true
}

# --- MaxFilesPerFolder: group by immediate parent dir, drop dense folders ---
if ($MaxFilesPerFolder -gt 0) {
    $grouped = $files | Group-Object { $_.DirectoryName }
    $denseFolders = @{}

    foreach ($group in $grouped) {
        if ($group.Count -gt $MaxFilesPerFolder) {
            $denseFolders[$group.Name] = $group.Count
        }
    }

    if ($denseFolders.Count -gt 0) {
        Write-Host "`nFolders skipped (more than $MaxFilesPerFolder files):" -ForegroundColor DarkYellow
        foreach ($folder in $denseFolders.GetEnumerator() | Sort-Object Name) {
            $rel = $folder.Name.Substring([Math]::Min($Path.Length + 1, $folder.Name.Length))
            Write-Host "  $rel  ($($folder.Value) files)" -ForegroundColor DarkGray
            $skipStats['dense_folder'] += $folder.Value
        }
        Write-Host ""
    }

    $files = $files | Where-Object { -not $denseFolders.ContainsKey($_.DirectoryName) }
}

$total = $files.Count

# Display skip statistics
if ($skipStats['gitignore'] -gt 0) {
    Write-Host "Skipped (gitignore): $($skipStats['gitignore']) files" -ForegroundColor DarkGray
}
if ($skipStats['node_modules'] -gt 0) {
    Write-Host "Skipped (node_modules): $($skipStats['node_modules']) files" -ForegroundColor DarkGray
}
if ($skipStats['hidden'] -gt 0) {
    Write-Host "Skipped (hidden files): $($skipStats['hidden']) files" -ForegroundColor DarkGray
}
if ($skipStats['hidden_dir'] -gt 0) {
    Write-Host "Skipped (hidden dirs like .next/.turbo): $($skipStats['hidden_dir']) files" -ForegroundColor DarkGray
}
if ($skipStats['skip_folder'] -gt 0) {
    Write-Host "Skipped (-SkipFolders '$SkipFolders'): $($skipStats['skip_folder']) files" -ForegroundColor DarkGray
}
if ($skipStats['dense_folder'] -gt 0) {
    Write-Host "Skipped (-MaxFilesPerFolder $MaxFilesPerFolder, see folders above): $($skipStats['dense_folder']) files" -ForegroundColor DarkGray
}
if ($skipStats['image'] -gt 0) {
    Write-Host "Skipped (image): $($skipStats['image']) files" -ForegroundColor DarkGray
}
if ($skipStats['large'] -gt 0) {
    Write-Host "Skipped (too large): $($skipStats['large']) files" -ForegroundColor DarkGray
}
if ($skipStats['binary'] -gt 0) {
    Write-Host "Skipped (binary): $($skipStats['binary']) files" -ForegroundColor DarkGray
}
if ($skipStats['self'] -gt 0) {
    Write-Host "Skipped (output/script): $($skipStats['self']) files" -ForegroundColor DarkGray
}

Write-Host "Found $total files to combine`n" -ForegroundColor Green

# Clear output file and write header (after file discovery to avoid self-inclusion)
if (Test-Path $Output) {
    Remove-Item $Output -Force
}

# Write header
$header = @"
----------
CombDir Output - Generated on $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
GitIgnore: $($GitIgnore.ToString())

"@
Add-Content -Path $Output -Value $header

# Add folder structure if recursive
if ($Recursive) {
    $folderTree = Get-FolderTree -FolderPath $Path -GitIgnorePatterns $gitignorePatterns -UseGitIgnore $GitIgnore -SkipNodeMods $SkipNodeModules
    $treeSection = @"

----------
FOLDER STRUCTURE
----------
$folderTree
----------

"@
    Add-Content -Path $Output -Value $treeSection
}

$counter = 0
$skipped = 0

foreach ($file in $files) {
    $counter++
    $percentComplete = [math]::Round(($counter / $total) * 100)
    
    # Get relative path
    $relativePath = $file.FullName.Substring($Path.Length + 1)
    
    Write-Progress -Activity "Combining Files" -Status "Processing: $relativePath" -PercentComplete $percentComplete
    Write-Host "[$counter/$total] Processing: $relativePath" -ForegroundColor Cyan
    
    try {
        # Build file header
        $header = "<------ Start $relativePath ------>"
        
        if ($AddTimestamp) {
            $header += "`nModified: $($file.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))"
            $header += "`nSize: $([math]::Round($file.Length / 1KB, 2)) KB"
        }
        
        Add-Content -Path $Output -Value $header
        Add-Content -Path $Output -Value ""
        
        # Read and write content
        $content = Get-Content -Path $file.FullName -Raw -ErrorAction Stop
        Add-Content -Path $Output -Value $content
        
        # Write footer
        Add-Content -Path $Output -Value ""
        Add-Content -Path $Output -Value "<------ End $relativePath ------>"
        Add-Content -Path $Output -Value "`n"
        
    } catch {
        $skipped++
        $errorMsg = "[Error reading file: $($_.Exception.Message)]"
        Add-Content -Path $Output -Value $errorMsg
        Add-Content -Path $Output -Value "`n"
        Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Progress -Activity "Combining Files" -Completed

# Summary
$summary = @"

----------
SUMMARY
----------
Total Files Processed: $counter
Files Skipped/Errors: $skipped
Output File: $Output
Output Size: $([math]::Round((Get-Item $Output).Length / 1KB, 2)) KB
----------
"@

Add-Content -Path $Output -Value $summary

Write-Host "`n$summary" -ForegroundColor Green
Write-Host "Done! Combined files saved to: $Output`n" -ForegroundColor Yellow

# SIG # Begin signature block
# MIIFcwYJKoZIhvcNAQcCoIIFZDCCBWACAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU8TgVO4LgWUiMYVVQqFk5Ix3I
# X/KgggMMMIIDCDCCAfCgAwIBAgIQZutI3c2bhbhMtrEVarszeDANBgkqhkiG9w0B
# AQsFADAcMRowGAYDVQQDDBFNeUNvZGVTaWduaW5nQ2VydDAeFw0yNjA1MjMxODMz
# MDhaFw0yNzA1MjMxODUzMDhaMBwxGjAYBgNVBAMMEU15Q29kZVNpZ25pbmdDZXJ0
# MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAy3SqoX7Ulj0/v6nKbOJI
# 7MJZmz8iupeRxJ6MUFCh5sN0n5hDwaSUm4RBxUPJWWSC5EIu0YP80yfMmeojjeqm
# TwerzRwHBObcRbgqQ0m31JMvvxezJYoAbXaTG33kLrJp2Jk4ubtW66Hd3ZYSs7JN
# zw26IyVeprFZ/Wscw9wC3DXVz5FFzZos8kt9ad4jhVu4lJDoYL8CGG/ZFo7eP4DY
# sSGEInX7oCLTzZQPDzmSn/EbfVlPkbnz9Nw2g73PvmmxqyNAjHS0db9CByyuFa3Y
# 5P4BMeW6mvMWcqAAdo+Qf5oY9XxVfyhYjTRLQCApx/Dibrsu33es6EhFOdlRJ9JQ
# MQIDAQABo0YwRDAOBgNVHQ8BAf8EBAMCB4AwEwYDVR0lBAwwCgYIKwYBBQUHAwMw
# HQYDVR0OBBYEFIKSIGY8VH/b8f/lrN7n9zCHnk1gMA0GCSqGSIb3DQEBCwUAA4IB
# AQB2HdcsTYrqthh+8pMDvo0OcWpasW7km6I+pckf/DlrwZ2y7V/B4YOERc8vWAFn
# BGO14oduwdFkSLnKXvcZ4LHAnGO+Q23hfmBTbvH6pcxlr2FzRRcn5gjKoyyhOeYl
# OKWcuCAMVuiJkHU+D57mnKpmkbro3pV8wUukSOjHOZl1DmkUYLIGobQBF7c0pfPt
# N4lOakzJBpKcb98PGytcvUCMWtN69Y7ZHXOJi4hTfgAhDMvNbBPI49SxeAYTwQaB
# hEKsexDQ1XjgAEhPUT2bpPljqq20INx+3E5NU6mYzq8ad3zaxGNfC5OvNQ2L1UKw
# FvOyPR1SpnI+CcDSAlnMIhVZMYIB0TCCAc0CAQEwMDAcMRowGAYDVQQDDBFNeUNv
# ZGVTaWduaW5nQ2VydAIQZutI3c2bhbhMtrEVarszeDAJBgUrDgMCGgUAoHgwGAYK
# KwYBBAGCNwIBDDEKMAigAoAAoQKAADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIB
# BDAcBgorBgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQU
# P//H3dmnWy2/kK7oA6vpg8IelWcwDQYJKoZIhvcNAQEBBQAEggEAowX25RHotzlB
# tJ0IxlnTXVQNu2BbLnXTWQH81jMZijGfkKR5wZpxOA6XsaSQD6TuKaCd8C9VgWmS
# w4WaQ0FE+XsoYnwSUMSe+WUHT1bMJ524aMOTy8SzASPPteboMsU2vPx6qHS1PQc8
# hc0IOP90j1LoBFaA47aWEdbs4lC4bvSl+t94QoGHE3iXVFW5tD1Ee+GonYITlQ3U
# HItOFiiwXzLH6nhqfqHZVdXEhr2WYWOHMVtmMsTrmWVj5HfIGls1Q+BkV5MZU842
# 9BDABu3RHkoozq0zZIIDqR6rkC8bF4z0Bg8n8elvymKg3WnfkdzJMaYabBjmiiCJ
# +Yvh8K7HLg==
# SIG # End signature block
