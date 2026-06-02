# combdir

A PowerShell script that combines all files in a directory into a single markdown file for easy upload to AI services like Google AI Studio, Claude, or ChatGPT.

---

## What you need to have

- Windows OS
- PowerShell 5.1 or later (already comes with Windows 10/11)
- Script execution policy that allows local scripts (see [Troubleshooting](#troubleshooting))

---

## Quick Install (PowerShell)

Paste this into PowerShell to download the script to your `Scripts` folder:

```powershell
$target="$env:USERPROFILE\Scripts"; New-Item -ItemType Directory -Force -Path $target; Invoke-WebRequest https://raw.githubusercontent.com/himanshubalani/combdir/main/combdir.ps1 -OutFile "$target\combdir.ps1"
```

Then paste this to add the `Scripts` folder to your PATH so you can run `combdir` from anywhere:

```powershell
$fp="$env:USERPROFILE\Scripts";$p=[Environment]::GetEnvironmentVariable("PATH","User");if(-not ($p.Split(";") -contains $fp)){[Environment]::SetEnvironmentVariable("PATH","$p;$fp","User")}
```

Restart your terminal after running the above.

---

## Manual Install

To use the script from any folder on your system, follow these steps:

1. **Download the script**: [combdir.ps1](https://raw.githubusercontent.com/himanshubalani/combdir/main/combdir.ps1)
2. **Move the script**: Place it in a directory of your choice (e.g., `C:\Users\<YourUsername>\Scripts`)
3. **Add the directory to your PATH**: This allows you to run `combdir` from any terminal window. (see [Environment Variables](https://learn.microsoft.com/en-us/previous-versions/office/developer/sharepoint-2010/ee537574(v=office.14)))
    - Press Win + S and search for "Environment Variables"
    - Click "Edit the system environment variables"
    - In the System Properties window, click "Environment Variables"
    - Under "User variables", find and select Path, then click Edit
    - Click New and add the path to your Scripts folder (e.g., `C:\Users\<YourUsername>\Scripts`)
    - Click OK to save and close all dialogs

---

## Usage

```powershell
combdir [Path] [Output] [Options]
```

### Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `Path` | Directory to process | Current directory |
| `Output` | Output file path | `combined_YYYYMMDD_HHMMSS.txt` |

### Options

| Flag | Description |
|------|-------------|
| `-r`, `-Recursive` | Include files from subdirectories. Also prints a folder tree at the top of the output. |
| `-h`, `-Help` | Show help message |
| `-txt`, `-Plain` | Output in plain text format with .txt extension (takes more tokens)
| `-Include <pattern>` | File pattern(s) to include, comma-separated. Default: `*.*` |
| `-Exclude <pattern>` | File pattern(s) to exclude, comma-separated. Default: `*.config,*.env,.env*` |
| `-GitIgnore` | Use the project's `.gitignore` file to determine exclusions |
| `-AddTimestamp` | Add last-modified time and size to each file entry |
| `-MaxFileSize <KB>` | Skip files larger than the given size in KB. `0` means no limit. |
| `-IgnoreBinary` | Skip binary files automatically |
| `-SkipNodeModules` | Skip the `node_modules` folder |
| `-MaxFilesPerFolder <N>` | Skip any folder containing more than N files. Useful for large UI component libraries like shadcn/ui. `0` means no limit. |
| `-SkipFolders <names>` | Comma-separated folder names to always skip, matched anywhere in the path. Example: `"ui,icons, assets, generated"` |

### Always excluded automatically

- Image files (`.jpg`, `.png`, `.svg`, `.webp`, and more)
- DotfIles files (filenames starting with `.`)
- Folders whose name starts with `.` (e.g. `.next`, `.turbo`, `.git`, `.cache`)
- The script file itself (`combdir.ps1`)
- Any previously generated output files matching `combined_*.*`

---

## Examples

```powershell
# Combine all files in the current directory
combdir

# Combine with subdirectories (includes folder tree in output)
combdir . -r

# Use .gitignore rules to filter files
combdir . -GitIgnore -r

# Output in Plaintext (.txt file)
combdir . -r -txt

# Combine only TypeScript and JS files
combdir .\src llms.txt -Include "*.ts,*.tsx,*.js" -r

# Skip folders with more than 10 files (great for components/ui)
combdir . -MaxFilesPerFolder 10 -r

# Always skip specific folders by name
combdir . -SkipFolders "ui,icons,generated" -r

# Skip node_modules, binary files, and anything over 500 KB
combdir . -SkipNodeModules -IgnoreBinary -MaxFileSize 500 -r

# Full example for a React/Next.js project
combdir . -GitIgnore -SkipNodeModules -MaxFilesPerFolder 10 -SkipFolders "ui" -r
```

---

## Output Formats

#### markdown:
    ## `src/app/page.tsx`
    ```tsx
    code content
    ```

#### plain txt:
    <------ Start filename.ext ------>
    code content
    <------ End filename.ext ------>


When `-Recursive` is used, a folder tree is printed at the top of the file. A summary at the bottom shows how many files were processed, skipped, and the final output size.

---

## How It Works

1. Scans the given directory (recursively if `-r` is passed)
2. Applies all exclusion filters: gitignore, hidden dirs, node_modules, named folders, dense folders, binary files, size limits
3. Groups surviving files by folder — if a folder exceeds `-MaxFilesPerFolder`, the entire folder is dropped and reported
4. Reads each remaining file and writes it to the output with fenced code blocks (or start/end markers in plain text mode)
5. Estimates token count by dividing total character count by 4 — shown in the summary alongside output size
6. Appends a summary with total files processed and output size

---

## Troubleshooting

- **"Running scripts is disabled on this system"**  
  PowerShell's execution policy is blocking the script. Allow local scripts with:
  ```powershell
  Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
  ```

- **Output is still too large**  
  Try combining several flags:
  ```powershell
  combdir . -GitIgnore -MaxFilesPerFolder 10 -IgnoreBinary -MaxFileSize 200 -r
  ```
  The skip summary printed to the console will show exactly which categories contributed the most files so you can target them.

- **A folder I want is being skipped by `-MaxFilesPerFolder`**  
  That flag drops the entire folder if it exceeds the threshold. Use `-SkipFolders` to target specific folder names instead, which gives you more precise control.

- **`.gitignore` patterns are not working as expected**  
  The `-GitIgnore` flag supports most common patterns but has two known limitations: negation patterns (`!`) are silently ignored, and `**` is treated as a single-level wildcard (`*`) rather than matching any depth. For most projects this is not an issue, but deeply nested build output folders may slip through.

---

## Tip

For Next.js or React projects, a reliable starting command is:

```powershell
combdir . -GitIgnore -SkipNodeModules -MaxFilesPerFolder 10 -r 
```

This respects your existing ignore rules, skips `node_modules`, and automatically drops large component library folders like `components/ui` that an AI doesn't need to read in full.
