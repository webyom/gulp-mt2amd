define(function(require, exports, module) {
	function $encodeHtml(str) {
		return (str + '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/`/g, '&#96;').replace(/'/g, '&#39;').replace(/"/g, '&quot;');
	}
	exports.render = function($data, $opt) {
		$data = $data || {};
		var _$out_= [];
		var $print = function(str) {_$out_.push(str);};
		
		with($data) {
		_$out_.push('<div>World</div>');
		;(function() {
		
		with($data) {
		_$out_.push('<script type="text/javascript">alert(\'Hello\');</s', "", 'cript><style type="text/css">.menu { width: 200px;}</style>', a, '', $encodeHtml(b), '');
		}
		
		})();
		
		}
		
		return _$out_.join('');
	};
});