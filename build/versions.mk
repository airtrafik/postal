#
# Centralized tool versions for go run pkg@version
#
# All development tools are executed via `go run` with pinned versions.
# Update versions here - they are used throughout the build system.
#
# To check for updates: go list -m -versions <package>
#

# Linting tools
MISSPELL_VERSION      := v0.3.4
GOIMPORTS_VERSION     := v0.52.0
GO_MOD_OUTDATED_VERSION := v0.9.0
GOLANGCI_VERSION      := v2.14.0

# Testing tools
GOTESTSUM_VERSION     := v1.13.0

# Release tools
SVU_VERSION           := v3.4.1

# Tool packages with versions (used by go run)
MISSPELL_PKG      := github.com/client9/misspell/cmd/misspell@$(MISSPELL_VERSION)
GOIMPORTS_PKG     := golang.org/x/tools/cmd/goimports@$(GOIMPORTS_VERSION)
GO_MOD_OUTDATED_PKG := github.com/psampaz/go-mod-outdated@$(GO_MOD_OUTDATED_VERSION)
GOLANGCI_PKG      := github.com/golangci/golangci-lint/v2/cmd/golangci-lint@$(GOLANGCI_VERSION)
GOTESTSUM_PKG     := gotest.tools/gotestsum@$(GOTESTSUM_VERSION)
SVU_PKG           := github.com/caarlos0/svu/v3@$(SVU_VERSION)
