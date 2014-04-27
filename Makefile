.PHONY: chrome firefox safari

all: chrome firefox safari

chrome:
	mkdir -p build/chrome
	cp manifest.json diff-highlighter.* icon-128.png build/chrome/
	rm -f build/chrome/extension.zip
	cd build/chrome && zip extension.zip *

firefox: build/firefox/jetpack-sdk-latest.zip
	mkdir -p build/firefox
	mkdir -p build/firefox/lib
	mkdir -p build/firefox/data
	cp package.json icon-64.png build/firefox/
	cp diff-highlighter.* build/firefox/data/
	cp main.js build/firefox/lib/

build/jetpack-sdk-latest.zip:
	mkdir -p build
	cd build && wget https://ftp.mozilla.org/pub/mozilla.org/labs/jetpack/jetpack-sdk-latest.zip
	cd build && unzip jetpack-sdk-latest.zip

safari:
	mkdir -p build/safari.safariextension
	cp Info.plist diff-highlighter.* icon-*.png build/safari.safariextension/

clean:
	rm -r build
