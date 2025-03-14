# dotr

A simple dotfile manager for personal use.

(use at your own risk)

## Features

- **Symlink Management**: Link and unlink files
- **Encryption**: Secure sensitive files with age encryption
- **Shell Commands**: Run shell commands from your configuration file
- **Modular Setup**: Include other configuration files
- **Undo**: Reverse actions when needed

## Usage

```
$ dotr -h
usage: dotr [flags] [shell command]

<command>              
  run                  Run the default dotfile or the file indicated by -f flag
  shell-command        A convenient way to run shell commands in the directory where dotfile exists

flags:
  -f, --file           Specify config file (default: 'dotfile')
  -r, --reverse        Reverse actions (link → unlink, encrypt → decrypt)
  -v, --verbose        Show detailed output
  --version            Display version
  -h, --help           Show help
```

### Configuration File

dotr looks for configuration in this order:
1. File specified by `--file` flag
2. File specified by `DOTR_FILE` environment variable
3. `dotfile` in current directory

You can also run shell command directly, which executes in the same directory as your dotfile. Combined with the DOTR_FILE environment variable, this makes it convenient to run tasks from any directory (e.g., dotr git diff to check git changes in your dotfiles repository).

## Configuration Syntax

- Lines starting with `#` are comments
- One action per line
- Format: `ACTION arg1:arg2:arg3...`
- Actions are case insensitive
- Arguments are separated by `:`

### Available Actions

#### Link
```
link src_file:dst_file
```
Creates a symbolic link. Reverse: unlink.

#### Encrypt
```
encrypt src_file:dst_file
```
Encrypts a file using age (passphrase only). Reverse: decrypt.

#### Decrypt
```
decrypt src_file:dst_file
```
Decrypts a file using age (passphrase only). Reverse: encrypt.

#### Shell
```
sh command arg1 arg2 ...
```
Runs a shell command.

#### Include
```
include some_other_file
```
Includes another configuration file.

For examples, see [waynezhang/configurations](https://github.com/waynezhang/configurations/tree/main/dotfiles).
