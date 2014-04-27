.PHONY: chrome firefox safari

all: chrome firefox safari

chrome:
	mkdir -p build/chrome
	cp manifest.json diff-highlighter.* icon-128.png build/chrome/
	rm -f build/chrome/extension.zip
	cd build/chrome && zip extension.zip *

firefox:

safari:
	mkdir -p build/safari.safariextension
	cp Info.plist diff-highlighter.* icon-*.png build/safari.safariextension/

clean:
	rm -r build
