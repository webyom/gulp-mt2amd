Q = require 'q'
fs = require 'fs'
path = require 'path'
less = require 'less'
gutil = require 'gulp-util'
through = require 'through2'

EOL = '\n'

getIncProcessed = (file, wrap) ->
	Q.Promise (resolve, reject) ->
		content = file.contents.toString 'utf-8'
		asyncList = []
		content = content.replace /<!--\s*include\s+(['"])([^'"]+)\.(tpl\.html|less)\1\s*-->/mg, (full, quote, incName, ext) ->
			asyncMark = '<INC_PROCESS_ASYNC_MARK_' + asyncList.length + '>'
			incFilePath = path.resolve path.dirname(file.path), incName + '.' + ext
			incFile = new gutil.File
				base: file.base
				cwd: file.cwd
				path: incFilePath
				contents: fs.readFileSync incFilePath
			if ext is 'less'
				asyncList.push ->
					Q.Promise (resolve, reject) ->
						less.render(
							incFile.contents.toString('utf-8')
							{
								paths: path.dirname incFilePath
								strictMaths: false
								strictUnits: false
								filename: incFilePath
							}
							(err, css) ->
								if err
									reject err
								else
									resolve [
										'<style type="text/css">'
										css
										'</style>'
									].join EOL
						)
			else
				asyncList.push getIncProcessed incFile, true
			asyncMark
		Q.all(asyncList).then(
			(results) ->
				results.forEach (res, i) ->
					content = content.replace '<INC_PROCESS_ASYNC_MARK_' + i + '>', res
				strict = (/(^|[^.]+)\B\$data\./).test content
				content = [
					content
				]
				if strict
					content.unshift '<%with($data) {%>'
					content.push '<%}%>'
				if wrap
					content.unshift '<%;(function() {%>'
					content.push '<%})();%>'
				resolve content.join EOL
			(err) ->
				reject err
		)

module.exports = ->
	through.obj (file, enc, next) ->
		return @emit 'error', new gutil.PluginError('gulp-amd-dependency', 'File can\'t be null') if file.isNull()
		return @emit 'error', new gutil.PluginError('gulp-amd-dependency', 'Streams not supported') if file.isStream()
		getIncProcessed(file).then(
			(processed) =>
				content = [
					"define(function(require, exports, module) {"
					"	function $encodeHtml(str) {"
					"		return (str + '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/\x60/g, '&#96;').replace(/\x27/g, '&#39;').replace(/\x22/g, '&quot;');"
					"	}"
					"	exports.render = function($data, $opt) {"
					"		$data = $data || {};"
					"		var _$out_= [];"
					"		var $print = function(str) {_$out_.push(str);};"
					"		_$out_.push('" + processed.replace /<\/script>/ig, '</s<%=""%>cript>'
							.replace(/\r\n|\n|\r/g, "\v")
							.replace(/(?:^|%>).*?(?:<%|$)/g, ($0) ->
								$0.replace(/('|\\)/g, "\\$1").replace(/[\v\t]/g, "").replace(/\s+/g, " ")
							)
							.replace(/[\v]/g, EOL)
							.replace(/<%==(.*?)%>/g, "', $encodeHtml($1), '")
							.replace(/<%=(.*?)%>/g, "', $1, '")
							.replace(/<%(<-)?/g, "');" + EOL + "		")
							.replace(/->(\w+)%>/g, EOL + "		$1.push('")
							.split("%>").join(EOL + "		_$out_.push('") + "');"
					"		return _$out_.join('');"
					"	};"
					"});"
				].join(EOL).replace(/_\$out_\.push\(''\);/g, '')
				file.contents = new Buffer content
				file.path = file.path + '.js'
				@push file
			(err) =>
				@emit 'error', new gutil.PluginError('gulp-amd-dependency', err)
		).done()
		next()
