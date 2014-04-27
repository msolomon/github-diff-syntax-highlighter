var data = require("sdk/self").data;
var pageMod = require("sdk/page-mod");

pageMod.PageMod({
  include: "*.github.com",
  contentScriptFile: data.url("diff-highlighter.js")
});
