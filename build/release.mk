#
# Makefile fragment for Releases
#
# Semantic versioning based on conventional commits using svu.
# Creates GitHub releases with auto-generated notes via gh CLI.
# No goreleaser, no changelog files — this is a library.
#
# Targets:
#   release-preview  - Show next version and commits without making changes
#   release          - Interactive release with confirmation prompt
#   release-auto     - Non-interactive release (for CI pipelines)
#   release-tag      - Create and push a release tag manually
#   release-clean    - Clean distribution directory
#

GO           ?= go
DIST_DIR     ?= ./dist

# Tool commands using centralized versions from versions.mk
# svu v3 dropped --strip-prefix (an empty --tag.prefix replaces it), defaults
# to tags from all branches, and bumps v0 to v1 on a breaking commit. These
# flags print bare versions, read only release tags (v<digit>…) merged into
# the current branch, and keep postal on v0. The pattern skips tags that don't
# start with v<digit> (such as v-old); it can't tell v1.2.3.bak from a
# release, and svu v3 fails on such a tag, so don't push one. v3 picks the
# highest such tag, where v1 took the nearest one; they agree while tags only
# move forward.
# --always makes svu next return a patch when no commit since the tag is a
# feat, fix or breaking change (only chore, deps, docs, test...), so those
# still ship. It would also bump with no commits at all, so SVU_VERSIONS only
# calls svu next when there is at least one commit since the tag.
SVU_TAG_PATTERN  := v[0-9]*
SVU_CMD          := $(GO) run $(SVU_PKG)
SVU_FLAGS        := --tag.prefix= --tag.mode=current --tag.pattern='$(SVU_TAG_PATTERN)'
SVU_NEXT_FLAGS   := $(SVU_FLAGS) --v0 --always

# CURRENT and NEXT for the release targets. The guard counts the same tags svu
# reads (release tags merged into HEAD). Only a repo with no release tag at
# all, here or on origin, falls back to 0.0.0/0.1.0. A shallow clone (checked
# first, so it gets the right advice), release tags that exist but aren't
# merged into HEAD (an old branch), tags on origin that weren't fetched, and
# any git or svu failure all stop the target, so none of them can be read as
# "first release". ls-remote matches the end of a ref name, hence the
# refs/tags/ anchor (archive/v1.0 isn't a release tag); GIT_TERMINAL_PROMPT=0
# and ssh BatchMode make an origin that wants credentials fail instead of
# hanging. BatchMode is appended to the caller's own ssh command
# (GIT_SSH_COMMAND or core.sshCommand), so a custom key still works.
#
# With no commits since the current tag NEXT equals CURRENT and nothing is
# released; any commit at all gives at least a patch (feat a minor). Commits
# are counted from the tag v$CURRENT, so a highest tag svu normalizes (v1.2,
# read as 1.2.0) stops the target.
SVU_VERSIONS = \
	MERGED_TAGS=$$(git tag -l '$(SVU_TAG_PATTERN)' --merged HEAD) || exit 1; \
	ALL_TAGS=$$(git tag -l '$(SVU_TAG_PATTERN)') || exit 1; \
	if [ -n "$$MERGED_TAGS" ]; then \
		CURRENT=$$($(SVU_CMD) current $(SVU_FLAGS)) || exit 1; \
		if ! git rev-parse -q --verify "refs/tags/v$$CURRENT" >/dev/null; then \
			echo "  ERROR: svu read v$$CURRENT but no tag has that exact name; the highest release tag isn't vMAJOR.MINOR.PATCH (v1.2?)" >&2; \
			exit 1; \
		fi; \
		SINCE=$$(git rev-list --count "v$$CURRENT..HEAD") || exit 1; \
		if [ "$$SINCE" -gt 0 ]; then \
			NEXT=$$($(SVU_CMD) next $(SVU_NEXT_FLAGS)) || exit 1; \
		else \
			NEXT=$$CURRENT; \
		fi; \
	elif [ "$$(git rev-parse --is-shallow-repository)" != "false" ]; then \
		echo "  ERROR: shallow clone with no release tag in its history; fetch full history and tags (git fetch --unshallow --tags)" >&2; \
		exit 1; \
	elif [ -n "$$ALL_TAGS" ]; then \
		echo "  ERROR: release tags exist but none is merged into HEAD (old branch?)" >&2; \
		exit 1; \
	elif ! REMOTE_TAGS=$$(GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND="$${GIT_SSH_COMMAND:-$$(git config core.sshCommand || echo ssh)} -o BatchMode=yes" git ls-remote --tags origin 'refs/tags/$(SVU_TAG_PATTERN)'); then \
		echo "  ERROR: no local release tags and origin could not be checked, so this can't be confirmed as a first release" >&2; \
		exit 1; \
	elif [ -n "$$REMOTE_TAGS" ]; then \
		echo "  ERROR: origin has release tags this clone hasn't fetched; run git fetch --tags" >&2; \
		exit 1; \
	else \
		CURRENT=0.0.0; NEXT=0.1.0; \
	fi

# Default branch for releases
DEFAULT_BRANCH   ?= main

# Preview the next release without making changes
release-preview:
	@echo "=== $(PROJECT_NAME) === [ release-preview  ]: Calculating next version from conventional commits..."
	@echo ""
	@$(SVU_VERSIONS); \
	echo "  Current version: v$$CURRENT"; \
	echo "  Next version:    v$$NEXT"; \
	echo ""; \
	if [ "$$CURRENT" = "$$NEXT" ]; then \
		echo "  Status: No version bump needed (no commits since v$$CURRENT)"; \
	else \
		echo "  Commits since v$$CURRENT:"; \
		git log --oneline v$$CURRENT..HEAD 2>/dev/null | head -20 | sed 's/^/    /'; \
		TOTAL=$$(git rev-list --count v$$CURRENT..HEAD 2>/dev/null || echo "0"); \
		if [ "$$TOTAL" -gt 20 ]; then \
			echo "    ... and $$((TOTAL - 20)) more commits"; \
		fi; \
	fi
	@echo ""

# Interactive release with confirmation prompt
release: release-check
	@echo "=== $(PROJECT_NAME) === [ release          ]: Starting release process..."
	@$(SVU_VERSIONS); \
	if [ "$$CURRENT" = "$$NEXT" ]; then \
		echo ""; \
		echo "  No version bump needed - no commits since v$$CURRENT"; \
		echo "  To force a release, use: make release-tag VERSION=x.y.z"; \
		exit 0; \
	fi; \
	echo ""; \
	echo "  Current version: v$$CURRENT"; \
	echo "  Next version:    v$$NEXT"; \
	echo ""; \
	echo "  This will:"; \
	echo "    1. Create and push tag v$$NEXT"; \
	echo "    2. Create GitHub release with auto-generated notes"; \
	echo ""; \
	read -p "  Proceed with release? [y/N] " confirm; \
	if [ "$$confirm" != "y" ] && [ "$$confirm" != "Y" ]; then \
		echo "  Release cancelled."; \
		exit 0; \
	fi; \
	$(MAKE) release-execute VERSION=$$NEXT

# Non-interactive release for CI pipelines
release-auto: release-check
	@echo "=== $(PROJECT_NAME) === [ release-auto     ]: Starting automated release..."
	@$(SVU_VERSIONS); \
	if [ "$$CURRENT" = "$$NEXT" ]; then \
		echo "  No version bump needed - no commits since v$$CURRENT"; \
		exit 0; \
	fi; \
	echo "  Releasing v$$NEXT (current: v$$CURRENT)"; \
	$(MAKE) release-execute VERSION=$$NEXT

# Pre-flight checks for release
release-check:
	@echo "=== $(PROJECT_NAME) === [ release-check    ]: Running pre-flight checks..."
	@BRANCH=$$(git rev-parse --abbrev-ref HEAD); \
	if [ "$$BRANCH" != "$(DEFAULT_BRANCH)" ]; then \
		echo "  ERROR: Must be on $(DEFAULT_BRANCH) branch (currently on $$BRANCH)"; \
		exit 1; \
	fi
	@if [ -n "$$(git status --porcelain)" ]; then \
		echo "  ERROR: Working directory has uncommitted changes"; \
		git status --short; \
		exit 1; \
	fi
	@GIT_USER=$$(git config user.name); \
	if [ -z "$$GIT_USER" ]; then \
		echo "  ERROR: git user.name not configured"; \
		exit 1; \
	fi
	@GIT_EMAIL=$$(git config user.email); \
	if [ -z "$$GIT_EMAIL" ]; then \
		echo "  ERROR: git user.email not configured"; \
		exit 1; \
	fi
	@if ! gh auth token >/dev/null 2>&1; then \
		echo "  ERROR: GitHub CLI not authenticated (run 'gh auth login')"; \
		exit 1; \
	fi
	@echo "  All checks passed"

# Execute the release (called by release and release-auto)
release-execute:
	@if [ -z "$(VERSION)" ]; then \
		echo "  ERROR: VERSION not specified"; \
		exit 1; \
	fi
	@echo "=== $(PROJECT_NAME) === [ release-execute  ]: Creating tag v$(VERSION)..."
	@git tag v$(VERSION)
	@git push --no-verify origin HEAD:$(DEFAULT_BRANCH) v$(VERSION)
	@echo "=== $(PROJECT_NAME) === [ release-execute  ]: Creating GitHub release..."
	@gh release create v$(VERSION) --generate-notes --latest
	@echo ""
	@echo "=== $(PROJECT_NAME) === [ release-execute  ]: Release v$(VERSION) complete!"

# Create and push a new release tag manually (bypasses svu calculation)
release-tag:
	@if [ -z "$(VERSION)" ]; then \
		echo "ERROR: VERSION not specified. Usage: make release-tag VERSION=0.1.0"; \
		exit 1; \
	fi
	@echo "=== $(PROJECT_NAME) === [ release-tag      ]: Creating tag v$(VERSION)..."
	@git tag -a v$(VERSION) -m "Release v$(VERSION)"
	@git push origin v$(VERSION)
	@echo "=== $(PROJECT_NAME) === [ release-tag      ]: Tag v$(VERSION) created and pushed"

# Clean distribution directory
release-clean:
	@echo "=== $(PROJECT_NAME) === [ release-clean    ]: Cleaning distribution files..."
	@rm -rf $(DIST_DIR)

.PHONY: release release-auto release-check release-execute release-preview \
        release-tag release-clean
