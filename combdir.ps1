# CombDir - Combine Directory Files into Single Markdown File
# Combdir combines all your code files to make a single .md file 
# for easy upload to your favorite AI service. Recommended for Google AI Studio, Claude, ChatGPT
# Version: 0.1.7

param(
    [Parameter(Position=0)]
    [string]$Path = ".",
    
    [Parameter(Position=1)]
    [string]$Output = "",
    
    [Alias("r")]
    [switch]$Recursive,
    
    [Alias("h")]
    [switch]$Help,

    # Output only files changed since last commit (git diff HEAD + untracked).
    # Skips folder tree — use mid-session when AI already has full context.
    [Alias("d")]
    [switch]$Diff,
    
    [string]$Include = "*.*",
    
    [string]$Exclude = "*.config,*.env,.env*",
    
    [switch]$AddTimestamp,
    
    [int]$MaxFileSize = 0,
    
    [switch]$IgnoreBinary,
    
    [switch]$SkipNodeModules,
    
    [switch]$GitIgnore,

    [int]$MaxFilesPerFolder = 0,

    [string]$SkipFolders = "",

    # Output in plain text format with simple start/end delimiters instead of Markdown.
    # Default output is Markdown. Use this flag to get a .txt file instead.
    [Alias("txt")]
    [switch]$Plain
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

CombDir - Combine Directory Files into Single Markdown File
===========================================================

USAGE:
    combdir [Path] [Output] [Options]

PARAMETERS:
    Path              Directory path to process (default: current directory)
    Output            Output file path (default: combined_YYYYMMDD_HHMMSS.md)

OPTIONS:
    -r, -Recursive         Include files from subdirectories
    -h, -Help              Show this help message
    -d, -Diff              Only include files changed since last commit
                           Ideal for mid-session AI updates (git required)
    -txt, -Plain           Output in plain text format with .txt extension
    
    -Include <pattern>     File pattern to include (default: *.*)
    -Exclude <pattern>     File pattern to exclude
    -GitIgnore             Use .gitignore file to determine exclusions
    -AddTimestamp          Add timestamp to each file entry
    -MaxFileSize <KB>      Skip files larger than specified KB (0 = no limit)
    -IgnoreBinary          Skip binary files automatically
    -SkipNodeModules       Skip node_modules folder
    -MaxFilesPerFolder <N> Skip folders with more than N files (0 = no limit)
    -SkipFolders <names>   Comma-separated folder names to always skip

NOTE:
    Image files, hidden files (starting with '.'), and folders whose name
    starts with '.' (e.g. .next, .turbo, .git, .cache) are automatically excluded.

EXAMPLES:
    combdir
    combdir .\lib -r
    combdir . -GitIgnore -r
    combdir . -txt -r
    combdir . -d
    combdir . -GitIgnore -SkipNodeModules -MaxFilesPerFolder 10 -r
    combdir .\src llms.md -Include "*.cs,*.js" -r
    combdir . -SkipFolders "ui,icons" -r

OUTPUT FORMAT (default - markdown):
    ## `src/app/page.tsx`
    ```tsx
    code content
    ```

OUTPUT FORMAT (-txt plain):
    <------ Start filename.ext ------>
    code content
    <------ End filename.ext ------>

"@ -ForegroundColor Cyan
    exit
}

function Convert-GlobToRegex {
    param([string]$Pattern)
    $escaped = [regex]::Escape($Pattern)
    $escaped = $escaped -replace '\\\*', '.*'
    $escaped = $escaped -replace '\\\?', '.'
    return "^$escaped$"
}

function Get-LanguageFromExtension {
    param([string]$FilePath)
    $ext = [System.IO.Path]::GetExtension($FilePath).ToLower()
    $map = @{
        '.ts'      = 'typescript'
        '.tsx'     = 'tsx'
        '.js'      = 'javascript'
        '.jsx'     = 'jsx'
        '.mjs'     = 'javascript'
        '.cjs'     = 'javascript'
        '.py'      = 'python'
        '.cs'      = 'csharp'
        '.go'      = 'go'
        '.rs'      = 'rust'
        '.java'    = 'java'
        '.cpp'     = 'cpp'
        '.cc'      = 'cpp'
        '.c'       = 'c'
        '.h'       = 'c'
        '.html'    = 'html'
        '.css'     = 'css'
        '.scss'    = 'scss'
        '.sass'    = 'sass'
        '.less'    = 'less'
        '.json'    = 'json'
        '.jsonc'   = 'json'
        '.yaml'    = 'yaml'
        '.yml'     = 'yaml'
        '.md'      = 'markdown'
        '.mdx'     = 'mdx'
        '.sh'      = 'bash'
        '.bash'    = 'bash'
        '.zsh'     = 'bash'
        '.ps1'     = 'powershell'
        '.psm1'    = 'powershell'
        '.sql'     = 'sql'
        '.xml'     = 'xml'
        '.toml'    = 'toml'
        '.ini'     = 'ini'
        '.env'     = 'bash'
        '.dart'    = 'dart'
        '.kt'      = 'kotlin'
        '.swift'   = 'swift'
        '.rb'      = 'ruby'
        '.php'     = 'php'
        '.r'       = 'r'
        '.lua'     = 'lua'
        '.vim'     = 'vim'
        '.graphql' = 'graphql'
        '.proto'   = 'protobuf'
        '.tf'      = 'hcl'
        '.prisma'  = 'prisma'
        '.txt'     = 'text'
    }
    if ($map.ContainsKey($ext)) { return $map[$ext] }
    return ''
}

function Test-BinaryFile {
    param([string]$FilePath)
    $bytes = [System.IO.File]::ReadAllBytes($FilePath)
    $sampleSize = [Math]::Min(8000, $bytes.Length)
    for ($i = 0; $i -lt $sampleSize; $i++) {
        if ($bytes[$i] -eq 0) { return $true }
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

function Test-InHiddenDirectory {
    param([string]$FullFilePath, [string]$BasePath)
    $relative = $FullFilePath.Substring($BasePath.Length).TrimStart('\', '/')
    $segments  = $relative -split '[\\/]'
    for ($i = 0; $i -lt ($segments.Length - 1); $i++) {
        if ($segments[$i].StartsWith('.')) { return $true }
    }
    return $false
}

function Test-InSkippedFolder {
    param([string]$FullFilePath, [string]$BasePath, [string[]]$SkipList)
    if ($SkipList.Count -eq 0) { return $false }
    $relative = $FullFilePath.Substring($BasePath.Length).TrimStart('\', '/')
    $segments  = $relative -split '[\\/]'
    for ($i = 0; $i -lt ($segments.Length - 1); $i++) {
        if ($SkipList -contains $segments[$i]) { return $true }
    }
    return $false
}

function Get-GitDiffFiles {
    param([string]$BasePath)

    # Verify git is available and path is a repo
    $null = git -C "$BasePath" rev-parse --git-dir 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Not a git repository (or git is not installed)." -ForegroundColor Red
        Write-Host "       -Diff requires git." -ForegroundColor Red
        exit 1
    }

    # Modified + staged tracked files vs HEAD (excludes deleted)
    $changed = @(git -C "$BasePath" diff HEAD --name-only --diff-filter=ACMR 2>$null |
        Where-Object { $_ -ne "" })

    # Staged new files (subset of $changed, needed for annotation)
    $addedInIndex = @(git -C "$BasePath" diff HEAD --name-only --diff-filter=A 2>$null |
        Where-Object { $_ -ne "" })

    # New untracked files not yet staged
    $untracked = @(git -C "$BasePath" ls-files --others --exclude-standard 2>$null |
        Where-Object { $_ -ne "" })

    # Deleted files — listed at end, no content shown
    $deleted = @(git -C "$BasePath" diff HEAD --name-only --diff-filter=D 2>$null |
        Where-Object { $_ -ne "" })

    # "New" = staged new + untracked (for *(new)* annotation)
    $newFiles = @($addedInIndex + $untracked | Select-Object -Unique)

    # All files to process = changed (tracked) + untracked, deduplicated
    $allChanged = @($changed + $untracked | Select-Object -Unique)

    return @{
        All     = $allChanged
        New     = $newFiles
        Deleted = $deleted
    }
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
            $tree = New-Object System.Text.StringBuilder
            $tree.AppendLine($FolderPath) | Out-Null

            function Add-TreeLevel {
                param([string]$Path, [string]$Prefix = "", [bool]$IsLast = $true)

                $items = try { Get-ChildItem -LiteralPath $Path -Force -ErrorAction Stop } catch { @() }
                $items = $items | Where-Object {
                    $item = $_
                    if ($item.Name -eq "node_modules") { return $false }
                    if ($item.Name.StartsWith('.')) { return $false }
                    if ($UseGitIgnore -and $GitIgnorePatterns.Count -gt 0) {
                        if (Test-GitIgnoreMatch -FilePath $item.FullName -BasePath $FolderPath -Patterns $GitIgnorePatterns) { return $false }
                    }
                    return $true
                }

                for ($i = 0; $i -lt $items.Count; $i++) {
                    $item      = $items[$i]
                    $isLastItem = ($i -eq $items.Count - 1)
                    $branch    = if ($isLastItem) { "└── " } else { "├── " }
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
            return tree $FolderPath /F | Out-String
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
        $line = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith('#')) { continue }
        $pattern = $line
        if ($pattern.StartsWith('/')) { $pattern = $pattern.Substring(1) }
        $pattern = $pattern -replace '\*\*', '*'
        $patterns += $pattern
    }
    $patterns += ".git"
    $patterns += ".git/*"
    Write-Host "Loaded $($patterns.Count) ignore patterns" -ForegroundColor Green
    return $patterns
}

function Test-GitIgnoreMatch {
    param([string]$FilePath, [string]$BasePath, [string[]]$Patterns)
    $relativePath = $FilePath.Substring($BasePath.Length).TrimStart('\', '/')
    $relativePath = $relativePath -replace '\\', '/'
    foreach ($pattern in $Patterns) {
        $pattern = $pattern -replace '\\', '/'
        if ($pattern.EndsWith('/')) {
            $dirPattern = $pattern.TrimEnd('/')
            $regex = Convert-GlobToRegex "$dirPattern/*"
            if ($relativePath -match $regex -or $relativePath -eq $dirPattern) { return $true }
        } else {
            $regex = Convert-GlobToRegex $pattern
            if ($relativePath -match $regex) { return $true }
            $parts = $relativePath -split '/'
            for ($i = 0; $i -lt $parts.Length; $i++) {
                $partialPath = ($parts[0..$i] -join '/')
                if ($partialPath -match $regex) { return $true }
            }
        }
    }
    return $false
}

# ─── Entry point ────────────────────────────────────────────────────────────

if ($Help) { Show-Help }

if ([string]::IsNullOrEmpty($Output)) {
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $ext       = if ($Plain) { "txt" } else { "md" }
    $suffix    = if ($Diff)  { "diff_$timestamp" } else { $timestamp }
    $Output    = "combined_$suffix.$ext"
}

$Path = Resolve-Path $Path -ErrorAction Stop
$Output = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Output)
$outputFullPath = [System.IO.Path]::GetFullPath($Output)

$includePatterns = $Include -split ','
$excludePatterns = if ($Exclude) { $Exclude -split ',' } else { @() }
$skipFolderList  = if ($SkipFolders) {
    ($SkipFolders -split ',') | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
} else { @() }

$gitignorePatterns = @()
if ($GitIgnore) { $gitignorePatterns = Get-GitIgnorePatterns -BasePath $Path }

Write-Host " ██████╗ ██████╗ ███╗   ███╗██████╗ ██████╗ ██╗██████╗ 
██╔════╝██╔═══██╗████╗ ████║██╔══██╗██╔══██╗██║██╔══██╗
██║     ██║   ██║██╔████╔██║██████╔╝██║  ██║██║██████╔╝
██║     ██║   ██║██║╚██╔╝██║██╔══██╗██║  ██║██║██╔══██╗
╚██████╗╚██████╔╝██║ ╚═╝ ██║██████╔╝██████╔╝██║██║  ██║
 ╚═════╝ ╚═════╝ ╚═╝     ╚═╝╚═════╝ ╚═════╝ ╚═╝╚═╝  ╚═╝
                                                            
        Scanning directory: $Path" -ForegroundColor Yellow

# ─── File collection ─────────────────────────────────────────────────────────

$newFileSet   = @()
$deletedFiles = @()

if ($Diff) {

    Write-Host "Mode: Git diff (HEAD)" -ForegroundColor Cyan

    $diffInfo     = Get-GitDiffFiles -BasePath $Path
    $newFileSet   = $diffInfo.New
    $deletedFiles = $diffInfo.Deleted

    if ($diffInfo.All.Count -eq 0 -and $deletedFiles.Count -eq 0) {
        Write-Host "`nNo changes detected since last commit." -ForegroundColor Yellow
        exit 0
    }

    Write-Host "Changed: $($diffInfo.All.Count) file(s)  |  Deleted: $($deletedFiles.Count) file(s)`n" -ForegroundColor Green

    # Resolve relative git paths to FileInfo objects, apply filters
    $files = $diffInfo.All | ForEach-Object {
        $relativePath = $_ -replace '/', '\'
        $fullPath     = Join-Path $Path $relativePath
        if (Test-Path -LiteralPath $fullPath) { Get-Item -LiteralPath $fullPath }
    } | Where-Object { $_ -ne $null } | Where-Object {
        $file = $_
        if ($file.FullName -eq $outputFullPath)             { return $false }
        if (Test-HiddenFile $file.Name)                     { return $false }
        if (Test-InHiddenDirectory $file.FullName $Path)    { return $false }
        if (Test-ImageFile $file.FullName)                  { return $false }
        if ($skipFolderList.Count -gt 0 -and
            (Test-InSkippedFolder $file.FullName $Path $skipFolderList)) { return $false }
        if ($MaxFileSize -gt 0 -and ($file.Length / 1KB) -gt $MaxFileSize) { return $false }
        if ($IgnoreBinary -and (Test-BinaryFile $file.FullName)) { return $false }
        # Honour include/exclude patterns if provided by user
        $matchesInclude = $false
        foreach ($pattern in $includePatterns) {
            if ($file.Name -match (Convert-GlobToRegex $pattern.Trim())) { $matchesInclude = $true; break }
        }
        if (-not $matchesInclude) { return $false }
        foreach ($pattern in $excludePatterns) {
            if ($file.Name -match (Convert-GlobToRegex $pattern.Trim())) { return $false }
        }
        return $true
    }

} else {

    $getChildItemParams = @{ Path = $Path; File = $true }
    if ($Recursive) { $getChildItemParams.Recurse = $true }
    $allFiles = Get-ChildItem @getChildItemParams

    $files = $allFiles | Where-Object {
        $file = $_

        if ($file.FullName -eq $outputFullPath) { return $false }
        if ($file.Name -eq "combdir.ps1" -or
            $file.Name -match (Convert-GlobToRegex "combined_*.*")) { return $false }

        # node_modules — fast path before expensive gitignore loop
        if ($file.FullName -match '\\node_modules\\') {
            if ($SkipNodeModules -or $GitIgnore) { return $false }
        }

        if ($GitIgnore -and $gitignorePatterns.Count -gt 0) {
            if (Test-GitIgnoreMatch -FilePath $file.FullName -BasePath $Path -Patterns $gitignorePatterns) { return $false }
        }

        if (Test-HiddenFile $file.Name)                                         { return $false }
        if (Test-InHiddenDirectory -FullFilePath $file.FullName -BasePath $Path) { return $false }
        if ($skipFolderList.Count -gt 0 -and
            (Test-InSkippedFolder -FullFilePath $file.FullName -BasePath $Path -SkipList $skipFolderList)) { return $false }
        if (Test-ImageFile $file.FullName)                                        { return $false }

        $matchesInclude = $false
        foreach ($pattern in $includePatterns) {
            if ($file.Name -match (Convert-GlobToRegex $pattern.Trim())) { $matchesInclude = $true; break }
        }
        if (-not $matchesInclude) { return $false }

        foreach ($pattern in $excludePatterns) {
            if ($file.Name -match (Convert-GlobToRegex $pattern.Trim())) { return $false }
        }

        if ($MaxFileSize -gt 0 -and ($file.Length / 1KB) -gt $MaxFileSize) { return $false }
        if ($IgnoreBinary -and (Test-BinaryFile $file.FullName))            { return $false }

        return $true
    }

    # MaxFilesPerFolder post-filter
    if ($MaxFilesPerFolder -gt 0) {
        $grouped      = $files | Group-Object { $_.DirectoryName }
        $denseFolders = @{}
        foreach ($group in $grouped) {
            if ($group.Count -gt $MaxFilesPerFolder) { $denseFolders[$group.Name] = $group.Count }
        }
        if ($denseFolders.Count -gt 0) {
            Write-Host "`nFolders skipped (more than $MaxFilesPerFolder files):" -ForegroundColor DarkYellow
            foreach ($folder in $denseFolders.GetEnumerator() | Sort-Object Name) {
                $rel = $folder.Name.Substring([Math]::Min($Path.Length + 1, $folder.Name.Length))
                Write-Host "  $rel  ($($folder.Value) files)" -ForegroundColor DarkGray
            }
            Write-Host ""
        }
        $files = $files | Where-Object { -not $denseFolders.ContainsKey($_.DirectoryName) }
    }
}

$total = $files.Count
if (-not $Diff) { Write-Host "Found $total files to combine`n" -ForegroundColor Green }

if (Test-Path $Output) { Remove-Item $Output -Force }

# ─── Header ──────────────────────────────────────────────────────────────────

if ($Diff) {
    $changedCount = $total
    $deletedCount = $deletedFiles.Count
    $header = @"
# CombDir Diff

Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Base: HEAD
$changedCount changed  ·  $deletedCount deleted

"@
} elseif (-not $Plain) {
    $header = @"
# CombDir Output

Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")  
GitIgnore: $($GitIgnore.ToString())  
Format: Markdown

"@
} else {
    $header = @"
----------
CombDir Output - Generated on $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
GitIgnore: $($GitIgnore.ToString())

"@
}
Add-Content -Path $Output -Value $header

# Folder tree — skipped in diff mode (AI already has full context)
if ($Recursive -and -not $Diff) {
    $folderTree = Get-FolderTree -FolderPath $Path -GitIgnorePatterns $gitignorePatterns -UseGitIgnore $GitIgnore -SkipNodeMods $SkipNodeModules
    if (-not $Plain) {
        $treeSection = @"
## Folder Structure

``````
$folderTree
``````

"@
    } else {
        $treeSection = @"

----------
FOLDER STRUCTURE
----------
$folderTree
----------

"@
    }
    Add-Content -Path $Output -Value $treeSection
}

# ─── File loop ───────────────────────────────────────────────────────────────

$counter    = 0
$skipped    = 0
$totalChars = 0

foreach ($file in $files) {
    $counter++
    $percentComplete = [math]::Round(($counter / $total) * 100)
    $relativePath    = $file.FullName.Substring($Path.Length + 1)

    Write-Progress -Activity "Combining Files" -Status "Processing: $relativePath" -PercentComplete $percentComplete
    Write-Host "[$counter/$total] Processing: $relativePath" -ForegroundColor Cyan

    try {
        $content = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction Stop
        $totalChars += $content.Length

        # Annotate new files in diff mode
        $relativeForward = $relativePath -replace '\\', '/'
        $isNew           = $Diff -and ($newFileSet -contains $relativeForward)
        $annotation      = if ($isNew) { "  *(new)*" } else { "" }

        if (-not $Plain) {
            $lang        = Get-LanguageFromExtension -FilePath $file.FullName
            $fileSection = "## ``$relativePath``$annotation"
            if ($AddTimestamp) {
                $fileSection += "`n> Modified: $($file.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))  Size: $([math]::Round($file.Length / 1KB, 2)) KB"
            }
            $fileSection += "`n`n``````$lang`n$content`n``````"
            Add-Content -Path $Output -Value $fileSection
            Add-Content -Path $Output -Value ""
        } else {
            $fileHeader = "<------ Start $relativePath$annotation ------>"
            if ($AddTimestamp) {
                $fileHeader += "`nModified: $($file.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))"
                $fileHeader += "`nSize: $([math]::Round($file.Length / 1KB, 2)) KB"
            }
            Add-Content -Path $Output -Value $fileHeader
            Add-Content -Path $Output -Value ""
            Add-Content -Path $Output -Value $content
            Add-Content -Path $Output -Value ""
            Add-Content -Path $Output -Value "<------ End $relativePath ------>"
            Add-Content -Path $Output -Value "`n"
        }
    } catch {
        $skipped++
        Add-Content -Path $Output -Value "[Error reading file: $($_.Exception.Message)]`n"
        Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Progress -Activity "Combining Files" -Completed

# ─── Deleted files section (diff mode only) ──────────────────────────────────

if ($Diff -and $deletedFiles.Count -gt 0) {
    if (-not $Plain) {
        $deletedSection  = "`n---`n`n## Deleted`n"
        $deletedSection += ($deletedFiles | ForEach-Object { "`n- ``$_``" }) -join ""
    } else {
        $deletedSection  = "`n----------`nDELETED FILES`n----------"
        $deletedSection += ($deletedFiles | ForEach-Object { "`n  $_" }) -join ""
    }
    Add-Content -Path $Output -Value $deletedSection
}

# ─── Summary ─────────────────────────────────────────────────────────────────

$estimatedTokensMin = [math]::Round($totalChars / 3.5)
$estimatedTokensMax = [math]::Round($totalChars / 2.6)
$tokenDisplayMin    = if ($estimatedTokensMin -ge 1000) { "$([math]::Round($estimatedTokensMin / 1000, 1))k" } else { "$estimatedTokensMin" }
$tokenDisplayMax    = if ($estimatedTokensMax -ge 1000) { "$([math]::Round($estimatedTokensMax / 1000, 1))k" } else { "$estimatedTokensMax" }
$outputSizeKB       = [math]::Round((Get-Item $Output).Length / 1KB, 2)

if (-not $Plain) {
    $summary = @"

---

## Summary

| | |
|---|---|
| Files Processed | $counter |
| Files Skipped/Errors | $skipped |
| Estimated Tokens | $tokenDisplayMin – $tokenDisplayMax |
| Output File | $Output |
| Output Size | $outputSizeKB KB |
"@
} else {
    $summary = @"

----------
SUMMARY
----------
Total Files Processed: $counter
Files Skipped/Errors:  $skipped
Estimated Tokens:      $tokenDisplayMin - $tokenDisplayMax
Output File:           $Output
Output Size:           $outputSizeKB KB
----------
"@
}

Add-Content -Path $Output -Value $summary

Write-Host "`n$summary" -ForegroundColor Green
Write-Host "Done! Combined files saved to: $Output`n" -ForegroundColor Yellow
