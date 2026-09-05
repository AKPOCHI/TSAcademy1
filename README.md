# Assignment 1 — Linux Diagnostic Toolkit

A small collection of Bash scripts that collect system information, check disk
usage, and perform basic network connectivity checks. Every script logs its
activity to the `logs/` directory.

## Structure

```
assignment-1/
├── README.md
├── system-info.sh
├── disk-check.sh
├── network-check.sh
├── grade.sh
└── logs/
    └── .gitkeep
```

## Scripts

### `system-info.sh`

Prints a snapshot of the current system, gathered live at runtime:

- Hostname
- Current user
- Date / time
- Operating system
- Kernel version
- Uptime
- CPU information
- Memory information
- Current working directory

Usage:

```bash
./system-info.sh
```

### `disk-check.sh`

Checks disk usage for a given path against a threshold percentage.

```bash
./disk-check.sh <threshold> [path]
```

- `threshold` — required integer from 1 to 100.
- `path` — optional, defaults to `/`.

Behavior:

- Prints the current disk usage percentage for the path.
- Exits `0` if usage is **below** the threshold.
- Exits `1` if usage is **at or above** the threshold.
- Exits `2` if the input is invalid (bad threshold, missing args, bad path).

### `network-check.sh`

Performs basic network diagnostics for a host, and optionally a port.

```bash
./network-check.sh <hostname-or-ip> [port]
```

- Validates the host argument.
- Resolves the host and displays the resolved address.
- Performs a basic connectivity check (ping).
- Displays local network interface information.
- If a port is supplied (must be 1–65535), checks TCP connectivity to it.
- Invalid input returns a non-zero exit code without crashing the script.

### Logging

Every script writes timestamped entries describing what it did to a file
under `logs/` (one log file per script: `logs/system-info.log`,
`logs/disk-check.log`, `logs/network-check.log`).

### `grade.sh`

The supplied Assignment 1 grader. Checks required files, Bash syntax,
executable permissions, `system-info.sh` output, disk-check argument
validation, network validation, logging, and basic Git history.

```bash
chmod +x grade.sh *.sh
./grade.sh
```

## Git

This project's history includes multiple meaningful commits and a
non-main feature branch (`feature/diagnostic-scripts`) that was merged
into `main`.
