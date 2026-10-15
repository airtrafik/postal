# postal

[![CI](https://github.com/airtrafik/postal/actions/workflows/ci.yaml/badge.svg)](https://github.com/airtrafik/postal/actions/workflows/ci.yaml)
[![Go Reference](https://pkg.go.dev/badge/github.com/airtrafik/postal.svg)](https://pkg.go.dev/github.com/airtrafik/postal)

Go/cgo interface to [libpostal](https://github.com/openvenues/libpostal), a C library for fast international street address parsing and normalization.

Originally forked from [openvenues/gopostal](https://github.com/openvenues/gopostal), rewritten with a modern Go API:

- Single `postal.New()` constructor with functional options
- Configurable data directory via `WithDataDir()` or `LIBPOSTAL_DATA_DIR` environment variable
- Proper error returns instead of `log.Fatal`
- No `init()` side effects
- Go module support

## Usage

```go
package main

import (
    "fmt"
    "log"

    "github.com/airtrafik/postal"
)

func main() {
    p, err := postal.New()
    if err != nil {
        log.Fatal(err)
    }
    defer p.Close()

    // Expand an address into normalized forms
    expansions := p.Expand("Quatre-vingt-douze Ave des Champs-Élysées")
    for _, e := range expansions {
        fmt.Println(e)
    }

    // Parse an address into labeled components
    components := p.Parse("781 Franklin Ave Crown Heights Brooklyn NY 11216 USA")
    for _, c := range components {
        fmt.Printf("%s: %s\n", c.Label, c.Value)
    }
}
```

### Custom data directory

Point libpostal at a non-default data directory (e.g., a GCS FUSE mount):

```go
p, err := postal.New(postal.WithDataDir("/mnt/gcs/libpostal-data"))
```

Or set the `LIBPOSTAL_DATA_DIR` environment variable:

```bash
export LIBPOSTAL_DATA_DIR=/mnt/gcs/libpostal-data
```

## Prerequisites

Install the libpostal C library before using postal.

**On Mac**
```bash
brew install curl autoconf automake libtool pkg-config
```

**On Ubuntu/Debian**
```bash
sudo apt-get install curl autoconf automake libtool pkg-config
```

**On Alpine**
```bash
apk add libpostal-dev libpostal-data
```

**Installing libpostal from source**

```bash
git clone https://github.com/openvenues/libpostal
cd libpostal
./bootstrap.sh
./configure --datadir=[...some dir with a few GB of space...]
make -j4
sudo make install
sudo ldconfig  # Linux only
```

## Installation

```bash
go get github.com/airtrafik/postal
```

## Development

```bash
make          # Full build: clean, lint, test
make test     # Run tests only
make lint     # Run linters only
make lint-fix # Auto-fix formatting
make help     # Show all targets
```

## Releasing

Releases use [svu](https://github.com/caarlos0/svu) for semantic versioning based on conventional commits. `feat` gives a minor (a breaking change too, while on v0); any other commit since the last tag (fix, chore, deps, test, docs) gives a patch; no commits since the tag releases nothing.

```bash
make release-preview  # Show what the next version would be
make release          # Interactive release with confirmation
```
