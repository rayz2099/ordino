.PHONY: generate build test run clean

generate:
	xcodegen generate

build: generate
	xcodebuild -project Ordino.xcodeproj -scheme Ordino -configuration Debug -derivedDataPath .derived -destination 'platform=macOS,arch=arm64' build

test: generate
	xcodebuild -project Ordino.xcodeproj -scheme Ordino -configuration Debug -derivedDataPath .derived -destination 'platform=macOS,arch=arm64' test

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

clean:
	rm -rf .derived Ordino.xcodeproj
