/* trace:example/src/style.less */
define(function(require, exports, module) {
    var cssContent = ".menu{width:200px;background-image:url(arrow.png?)}";
    var moduleUri = module && module.uri;
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
    module.exports = cssContent;
});