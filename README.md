# setup-sight

A GitHub Action that installs the [Sight](https://github.com/jbearak/sight) CLI
from prebuilt release binaries.

**Sight** is a Language Server Protocol implementation and static analyzer for
the Stata programming language. It provides editor features such as diagnostics,
completion, hover, go-to-definition, and a standalone `sight` CLI for use in
CI and other editor integrations.

## Why this action exists

Sight publishes Bun-compiled binaries on
[GitHub Releases](https://github.com/jbearak/sight/releases). Installing one in
CI by hand means detecting the runner OS and architecture, selecting the right
asset, downloading it, verifying its SHA-256 checksum, renaming it to the stable
`sight` command, and adding it to `PATH`.

This action does that install step for you. It downloads the matching release
binary, verifies the published checksum, adds `sight` to `PATH`, and runs
`sight --version` as a smoke test.

It installs only. Beyond the `--version` smoke test, it does not run `sight`
subcommands; your workflow controls which paths and flags to check.

## Usage

```yaml
- uses: actions/checkout@v4
- uses: jbearak/setup-sight@v1
  with:
    version: latest
- run: sight --version
```

Pin a release tag for reproducible builds:

```yaml
- uses: jbearak/setup-sight@v1
  with:
    version: v0.8.4
```

## Inputs

- `version` - `latest` (default) or a Sight release tag such as `v0.8.4`.

## Supported runners

The action supports the runner targets published by Sight:

- Linux x64
- Linux ARM64
- Windows x64
- Windows ARM64
- macOS ARM64

macOS x64 is not supported because Sight does not publish a macOS x64 binary.

## License

[GPL-3.0](LICENSE), the same license as Sight.
