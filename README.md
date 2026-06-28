# setup-sight

A GitHub Action that installs the [Sight](https://github.com/jbearak/sight) CLI
from prebuilt release binaries.

## Usage

```yaml
- uses: actions/checkout@v4
- uses: jbearak/setup-sight@v1
  with:
    version: latest
- run: sight --version
```

## License

[GPL-3.0](LICENSE), the same license as Sight.
