export CLANG_MODULE_CACHE_PATH := $(CURDIR)/.cache/clang
export SWIFTPM_MODULECACHE_OVERRIDE := $(CURDIR)/.cache/clang
SPM_FLAGS := --sdk "$(shell xcrun --sdk macosx --show-sdk-path)" --cache-path "$(CURDIR)/.cache/swiftpm" --config-path "$(CURDIR)/.cache/config" --security-path "$(CURDIR)/.cache/security"
TEST_PLUGIN_DIR := $(dir $(shell xcrun --find swiftc))../lib/swift/host/plugins/testing
ifneq ($(wildcard $(TEST_PLUGIN_DIR)/libTestingMacros.dylib),)
TEST_FLAGS := -Xswiftc -plugin-path -Xswiftc "$(TEST_PLUGIN_DIR)"
endif
.PHONY: check style test smoke app fmt format-check

style:
	python3 scripts/check_design.py

test:
	swift test $(SPM_FLAGS) $(TEST_FLAGS) --disable-xctest

fmt:
	xcrun swift-format format --in-place --recursive Sources Tests Package.swift

format-check:
	xcrun swift-format lint --strict --recursive Sources Tests Package.swift

check: style format-check test

smoke:
	GLASSNOTES_WINDOW_TESTS=1 swift test $(SPM_FLAGS) $(TEST_FLAGS) --disable-xctest --filter NativeDesktopTests

app: style
	swift build -c release --product GlassNotes $(SPM_FLAGS) -Xlinker -platform_version -Xlinker macos -Xlinker 14.0 -Xlinker "$(shell xcrun --sdk macosx --show-sdk-version)"
	bash scripts/package.sh "$$(swift build -c release $(SPM_FLAGS) --show-bin-path)"
