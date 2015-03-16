define(function(require, exports, module) {
    function $encodeHtml(str) {
        return (str + "").replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/`/g, "&#96;").replace(/'/g, "&#39;").replace(/"/g, "&quot;");
    }
    exports.render = function($data, $opt) {
        $data = $data || {};
        var _$out_ = [];
        var $print = function(str) {
            _$out_.push(str);
        };
        with ($data) {
            /* trace:example/src/tpl-b.tpl.html */
            _$out_.push("<script type=\"text/javascript\">alert('Hello');</s", "", "cript>");
            /* trace:example/src/style.less */
            _$out_.push('<style type="text/css">.menu { width: 200px;}</style>');
            /* trace:example/src/style.scss */
            _$out_.push('<style type="text/css">.content-navigation { border-color: #3bbfce; color: #2ca2af; }.border { padding: 8px; margin: 8px; border-color: #3bbfce; }</style>');
            /* trace:example/src/style.css */
            _$out_.push('<style type="text/css">.menu {width: 30px;}.menu {height: 30px;}</style>', a, "", $encodeHtml(b), "");
        }
        return _$out_.join("");
    };
});