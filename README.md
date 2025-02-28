# dotr

A simple dotfile manager for personal usage.

(use it at your own risk)

## Features

- **Symlink Management**: Easily link and unlink configuration files to their proper locations
- **Secure Encryption**: Built-in support for age encryption for sensitive files
- **Shell Command Execution**: Execute shell commands directly from your configuration file
- **Configuration Inclusion**: Include other configuration files for modular and reusable setups
- **Undo**: Limited support for undo(reverse)

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

### Commands

#### Link

Create symbol link for files. Reverse action is unlink.

```
link src_file : dst_file
```

#### Encrypt

Encrypt file with age. Only passphrase is supported. Reverse action is decryption.

```
encrypt src_file : dst_file
```

#### Decrypt

Decrypt file with age. Only passphrase is supported. Reverse action is encryption.

```
decrypt src_file : dst_file
```

#### Shell

Run shell command.

```
sh command arg1 arg2 ...
```

#### Include

Include another configuration file.

```
include some_other_file
```

Check [waynezhang/configurations](https://github.com/waynezhang/configurations/tree/main/dotfiles) for examples in action.
