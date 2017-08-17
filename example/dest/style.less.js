/* trace:example/src/style.less */
define(function(require, exports, module) {
    var moduleClassName = "89de1ef2";
    var cssContent = ".89de1ef2 .menu{width:200px;background-image:url(arrow.png?)}.89de1ef2 .bar,.89de1ef2 .foo,.89de1ef2 .foo .bar{width:200px}";
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