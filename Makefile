.PHONY: chrome firefox safari

all: chrome firefox safari

chrome:
	mkdir -p build/chrome
	cp manifest.json diff-highlighter.* icon-128.png build/chrome/
	rm -f build/chrome/extension.zip
	cd build/chrome && zip extension.zip *

firefox:

safari:
