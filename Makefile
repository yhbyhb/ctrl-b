APP_NAME   = CtrlB
BUNDLE     = $(APP_NAME).app
BUILD_DIR  = .build/release
BINARY     = $(BUILD_DIR)/$(APP_NAME)

.PHONY: build app install test clean lint lint-fix setup

## swift build (개발용)
build:
	swift build -c release

## .app 번들 생성
app: build
	mkdir -p $(BUNDLE)/Contents/MacOS
	mkdir -p $(BUNDLE)/Contents/Resources
	cp $(BINARY) $(BUNDLE)/Contents/MacOS/$(APP_NAME)
	cp Resources/Info.plist $(BUNDLE)/Contents/Info.plist
	cp Resources/AppIcon.icns $(BUNDLE)/Contents/Resources/AppIcon.icns
	cp -r $(BUILD_DIR)/CtrlB_CtrlB.bundle $(BUNDLE)/Contents/Resources/ 2>/dev/null || true
	@echo "✓ $(BUNDLE) 생성 완료"

## /Applications 에 설치
install: app
	cp -r $(BUNDLE) /Applications/
	@echo "✓ /Applications/$(BUNDLE) 설치 완료"

## 유닛 테스트 실행
test:
	swift test

## 빌드 산출물 정리
clean:
	rm -rf .build $(BUNDLE)

## SwiftLint 검사
lint:
	swiftlint lint --strict

## SwiftLint 자동 수정
lint-fix:
	swiftlint lint --fix

## 개발 환경 초기 설정 (git hooks)
setup:
	git config core.hooksPath .githooks
	chmod +x .githooks/pre-commit
	@echo "✓ Git hooks configured"
