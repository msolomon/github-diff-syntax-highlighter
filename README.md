# GitHub diff syntax highlighter

Use GitHub's own syntax highlighting for diffs on GitHub

------------------------

### Note: this extension is now unnecessary

On December 9, 2014, GitHub finally implemented this functionality on the server-side. See GitHub’s announcement [“Syntax Highlighted Diffs”](https://github.com/blog/1932-syntax-highlighted-diffs). Thus, this extension is unnecessary and will be discontinued. Enjoy your diff-reading!

------------------------

GitHub doesn't syntax highlight inside diffs. This extension fixes that.

[Other extensions](https://github.com/danielribeiro/github-diff-highlight-extension) already exist that use a Javascript syntax highlighter to perform a similar task, but this extension instead requests the highligted HTML directly from GitHub and merges it into the page.

This has two advantages:

1. The syntax highlighting matches that on the rest of GitHub exactly
1. Small diffs without enough context to be parsed properly with Javascript still get highlighted properly

It also has some disadvantages:

1. It is highly coupled with GitHub's current HTML output. This is very brittle since the HTML could change and any time and break everything.
1. On large diffs, it can require many additional network requests before it will begin its work (this could be somewhat alleviated).
1. Because there are many contexts in which diffs appear and the HTML differs for each, I probably missed some cases.
1. Due to the brittle design of the whole thing (which essentially merges different GitHub pages into one and has to handle many special cases), it may become out of date at any time and I may or may not have time to fix it.
1. It doesn't highlight deleted lines on just-renamed files since GitHub's HTML doesn't usually contain enough information to do that.
1. It doesn't highlight inline diffs (such as in comments), since GitHub's HTML doesn't include enough information to do it accurately.

## TL;DR

This extension rocks and you should use it until it breaks inexplicably

## Installation

### Chrome

[Visit the Chrome web store](https://chrome.google.com/webstore/detail/github-diff-syntax-highli/dgkfbihjnombgekdpemmggglcpnmoich) and install the extension.

### Firefox
Clone, then build with `make` and bundle with `cfx xpi build/firefox/` (too little demand for me to do this for each release). The `cfx` command is provided by Mozilla’s [Jetpack](https://wiki.mozilla.org/Jetpack) – see its [installation instructions](https://developer.mozilla.org/en-US/Add-ons/SDK/Tutorials/Installation). Install the generated file `github-diff-syntax-highlighter.xpi` by opening it in Firefox.

For convenience, here are the commands to build and install the project for the first time on a Mac with [Homebrew](http://brew.sh/):

~~~sh
# install dependencies with Homebrew
brew install wget  # wget is needed by the Makefile
brew install mozilla-addon-sdk  # cfx is needed to bundle the xpi
# clone
git clone git@github.com:msolomon/github-diff-syntax-highlighter.git
cd github-diff-syntax-highlighter
# build
make
cd build
cfx xpi firefox/
# install in Firefox
open -a Firefox github-diff-syntax-highlighter.xpi
~~~

### Safari

Clone, then build with `make` and bundle in Safari (too little demand for me to do this for each release).


------------------------

Brought to you by [msol](http://msol.io/), aka [@msol](https://twitter.com/msol)
