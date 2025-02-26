# dotr

A simple dotfile manager for personal usage.

## Features

- **Command Sequences**: Run series of predefined commands from a configuration file
- **Symlink Management**: Easily link and unlink configuration files to their proper locations
- **Secure Encryption**: Built-in support for age encryption for sensitive files
- **Shell Command Execution**: Execute shell commands directly from your configuration file
- **Shell Command Execution**: Execute shell commands directly from your configuration file
- **Configuration Inclusion**: Include other configuration files for modular and reusable setups

## Usage

```
$ dotr -h
usage: dotr [flags] [filename]

The default filename is `dotfile`

flags:
  -r, --reverse        Reverse the commands (Link → Unlink, Encrypt → Decrypt)
  -v, --verbose        Verbose mode
  --version            Show version information
  -h, --help           Show this help message
```

## `dotfile` syntax

- Lines starts with `#` are comments.
- One command per line.
- All lines follows the syntax that: `COMMAND arg1:arg2:arg3...`.
- The command is case insensitive.
- The arguments is separated by `:`.

Example:

```
### This is a comment

link src_file : dst_file
encrypt src_file : dst_file
decrypt src_file : dst_file
sh command
include another_dot_file
```
