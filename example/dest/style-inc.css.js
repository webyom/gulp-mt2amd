/* trace:example/src/style-inc.css */
define(function(require, exports, module) {
    function yomCssModuleHelper(className, cssContent, moduleUri) {
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
        function moduleClassNames() {
            var cns = [];
            var args = Array.prototype.slice.call(arguments);
            if (!args.length) {
                return className;
            }
            args.forEach(function(cn) {
                if (typeof cn == "object") {
                    Object.keys(cn).forEach(function(k) {
                        if (cn[k]) {
                            k = k.replace(/^&/, className).replace(/&/g, "");
                            k && cns.push(k);
                        }
                    });
                } else {
                    cn = cn.replace(/^&/, className).replace(/&/g, "");
                    cn && cns.push(cn);
                }
            });
            return cns.join(" ");
        }
        return {
            moduleClassNames: moduleClassNames,
            cssContent: cssContent
        };
    }
    var moduleUri = typeof module != "undefined" && module.uri;
    var expo = yomCssModuleHelper("", ".menu{width:30px}", moduleUri);
    module.exports = expo;
});