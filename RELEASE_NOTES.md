# CombDir Release Notes

## Version 1.5 - Initial Release

### 🎉 Overview
CombDir is a powerful PowerShell script that combines all files in a directory into a single text file for easy upload to AI services like Google AI Studio, Claude, and ChatGPT.

### ✨ Key Features

#### Core Functionality
- **Combine Multiple Files**: Consolidate all code files from a directory into a single markdown or plain text file
- **Recursive Directory Processing**: Include files from subdirectories with optional folder tree visualization
- **Format Flexibility**: Choose between markdown (default) or plain text output formats
- **AI-Ready Output**: Generates files optimized for token limits and context windows of LLMs

#### Advanced Filtering & Exclusions
- **GitIgnore Support**: Automatically respects `.gitignore` patterns to exclude files
- **Include/Exclude Patterns**: Customize which file types to include or exclude
- **Folder Skipping**: Skip specific folders by name or limit files per folder
- **Node Modules Support**: Built-in flag to skip `node_modules` directories
- **Binary File Detection**: Automatically skip binary files
- **File Size Limits**: Exclude files exceeding a specified size threshold

#### Smart File Management
- **Automatic Exclusions**: Automatically excludes image files, hidden files, and hidden directories
- **Code Language Detection**: Automatically detects file types and adds appropriate syntax highlighting in markdown output
- **Timestamp Support**: Optionally include file modification times and sizes
- **Dense Folder Handling**: Skip entire folders containing too many files (useful for large UI component libraries)
- **Token Estimation**: Provides estimated token count for AI context windows

#### Output Enhancements
- **Folder Structure**: Optional tree view of the directory structure in recursive mode
- **Detailed Summary**: Reports files processed, skipped, estimated tokens, and output size
- **Proper Syntax Highlighting**: Markdown output includes syntax hints for 30+ programming languages
- **Error Handling**: Gracefully handles read errors and reports them in output

### 🚀 Quick Start

**Basic Usage:**
```powershell
combdir
```

**With Subdirectories:**
```powershell
combdir . -r
```

**For Next.js/React Projects:**
```powershell
combdir . -GitIgnore -SkipNodeModules -MaxFilesPerFolder 10 -r
```

### 📋 Supported Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `Path` | Directory to process | Current directory |
| `Output` | Output file path | `combined_YYYYMMDD_HHMMSS.md` |
| `-r`, `-Recursive` | Include subdirectories | Disabled |
| `-txt`, `-Plain` | Output as plain text | Markdown format |
| `-Include <pattern>` | File patterns to include | `*.*` |
| `-Exclude <pattern>` | File patterns to exclude | `*.config,*.env,.env*` |
| `-GitIgnore` | Use .gitignore rules | Disabled |
| `-AddTimestamp` | Add file metadata | Disabled |
| `-MaxFileSize <KB>` | Skip files larger than KB | No limit |
| `-IgnoreBinary` | Skip binary files | Disabled |
| `-SkipNodeModules` | Skip node_modules folder | Disabled |
| `-MaxFilesPerFolder <N>` | Skip dense folders | No limit |
| `-SkipFolders <names>` | Comma-separated folder names | None |

### 📊 Supported Languages

Includes syntax highlighting for 30+ languages including:
- **Web**: TypeScript, JavaScript, JSX, HTML, CSS, SCSS, LESS
- **Backend**: Python, C#, Go, Rust, Java, PHP, Ruby
- **Data**: JSON, YAML, SQL, XML, TOML
- **Infrastructure**: PowerShell, Bash, HCL (Terraform), Prisma
- **And more**: Kotlin, Swift, Dart, Lua, GraphQL, Protobuf

### ⚙️ System Requirements

- **OS**: Windows 10/11 or later
- **PowerShell**: Version 5.1 or later (built-in with Windows)
- **Permissions**: Execution policy allowing local scripts (see documentation for setup)

### 🔧 Installation Options

**Option 1 - Quick PowerShell Install:**
```powershell
$target="$env:USERPROFILE\Scripts"; New-Item -ItemType Directory -Force -Path $target; Invoke-WebRequest https://raw.githubusercontent.com/himanshubalani/combdir/main/combdir.ps1 -OutFile "$target\combdir.ps1"
```

**Option 2 - Manual Download:**
Download `combdir.ps1` and place in your Scripts folder or add to PATH.

### 📝 Output Examples

**Markdown Format (default):**
```
## `src/app/page.tsx`
```tsx
code content here
```
```

**Plain Text Format:**
```
<------ Start src/app/page.tsx ------>
code content here
<------ End src/app/page.tsx ------>
```

### 🎯 Use Cases

- **AI Code Review**: Prepare entire projects for Claude or ChatGPT analysis
- **Documentation**: Generate comprehensive code documentation files
- **Codebase Sharing**: Share large codebases with limited context windows
- **Learning Resources**: Create consolidated code examples for training
- **Code Analysis**: Enable AI tools to analyze complete project structures

### 🆘 Troubleshooting

Common issues and solutions included in documentation:
- Script execution policy errors
- Digital signature requirements
- Output file size optimization
- `.gitignore` pattern limitations
- Dense folder handling for UI libraries

### 📚 Documentation

Complete documentation available in `README.md` with:
- Detailed installation instructions
- Comprehensive parameter guide
- Real-world usage examples
- Troubleshooting section
- Performance optimization tips

### 📄 License

GNU General Public License v3.0 (GPL-3.0)

### 🙏 Support

For issues, questions, or feature requests, please visit the [GitHub Issues](https://github.com/himanshubalani/combdir/issues) page.

---

**Version**: 1.5  
**Release Date**: June 3, 2026  
**Repository**: [himanshubalani/combdir](https://github.com/himanshubalani/combdir)
