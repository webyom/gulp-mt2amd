/* trace:example/src/style-inc.css */
define(function(require, exports, module) {
    var moduleClassName = "138cabec";
    var cssContent = ".menu{width:30px}";
    var moduleUri = typeof module != "undefined" && module.uri;
    var head = document.head || document.getElementsByTagName("head")[0];
    var styleTagId = "yom-style-module-inject-tag";
    var styleTag = document.getElementById(styleTagId);
    if (!styleTag) {
        styleTag = document.createElement("style");
        styleTag.id = styleTagId;
        styleTag.type = "text/css";
        styleTag = head.appendChild(styleTag);
    }
    window._yom_style_module_injected = window._yom_style_module_injected || {};
    if (!moduleUri) {
        styleTag.appendChild(document.createTextNode(cssContent + "\n"));
    } else if (!window._yom_style_module_injected[moduleUri]) {
        styleTag.appendChild(document.createTextNode("/* " + moduleUri + " */\n" + cssContent + "\n"));
        window._yom_style_module_injected[moduleUri] = 1;
    }
    module.exports = {
        moduleClassName: moduleClassName,
        cssContent: cssContent
    };
});