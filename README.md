# DevManager

A modern, native macOS application to manage and switch local Java and Node.js versions.

## Features
- **Modern UI**: Elegant Sidebar design with card-style layout using SwiftUI.
- **Java Management**: Auto-discovery of JDKs via `/usr/libexec/java_home`.
- **Node.js Management**: Support for Homebrew and NVM installed Node versions.
- **Shell Integration**: Lightweight configuration via generated shell scripts.

## Requirements
- macOS 13.0 or later

## How to Run

1. Build the project:
   ```bash
   swift build
   ```

2. Run the application:
   ```bash
   swift run
   ```

## Setup (One-time)

To make the version selection effective in your terminal, add the following lines to your shell configuration file (e.g., `~/.zshrc`, `~/.bash_profile`):

```bash
# Java
[ -f ~/.config/devmanager/java_env.sh ] && source ~/.config/devmanager/java_env.sh

# Node.js
[ -f ~/.config/devmanager/node_env.sh ] && source ~/.config/devmanager/node_env.sh
```

After adding these lines, restart your terminal or run `source ~/.zshrc`.
