.PHONY: generate build test run package clean

VERSION := $(shell tr -d '[:space:]' < VERSION)
BUILD := $(shell bash scripts/semver-build.sh)
VERSION_SETTINGS := MARKETING_VERSION=$(VERSION) CURRENT_PROJECT_VERSION=$(BUILD)

generate:
	xcodegen generate

build: generate
	xcodebuild -project Ordino.xcodeproj -scheme Ordino -configuration Debug -derivedDataPath .derived -destination 'platform=macOS,arch=arm64' $(VERSION_SETTINGS) build

test: generate
	xcodebuild -project Ordino.xcodeproj -scheme Ordino -configuration Debug -derivedDataPath .derived -destination 'platform=macOS,arch=arm64' $(VERSION_SETTINGS) test

run: build
	@# 普通 open 会复用旧进程；必须精准重启当前工作区产物，确保刚构建的代码生效。
	@app="$$(pwd -P)/.derived/Build/Products/Debug/Ordino.app"; \
	exe="$$app/Contents/MacOS/Ordino"; \
	pids="$$(ps -axo pid=,comm= | awk -v exe="$$exe" '$$2 == exe { print $$1 }')"; \
	for pid in $$pids; do kill -TERM "$$pid"; done; \
	n=50; \
	while [ $$n -gt 0 ]; do \
		live="$$(ps -axo pid=,comm= | awk -v exe="$$exe" '$$2 == exe { print $$1 }')"; \
		[ -z "$$live" ] && break; \
		sleep 0.1; \
		n=$$((n - 1)); \
	done; \
	live="$$(ps -axo pid=,comm= | awk -v exe="$$exe" '$$2 == exe { print $$1 }')"; \
	[ -z "$$live" ] || { echo "Ordino did not exit: $$live" >&2; exit 1; }; \
	open -n "$$app"

package:
	bash scripts/package-app.sh

clean:
	rm -rf .derived Ordino.xcodeproj dist
