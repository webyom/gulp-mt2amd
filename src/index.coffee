Q = require 'q'
fs = require 'fs'
path = require 'path'
less = require 'gulp-less'
sass = require 'gulp-sass'
gutil = require 'gulp-util'
through = require 'through2'
uglify = require 'uglify-js'

EOL = '\n'

compileLess = (file, opt) ->
	Q.Promise (resolve, reject) ->
		if opt.trace
			trace = '<%/* trace:' + path.relative(process.cwd(), file.path) + ' */%>' + EOL
		else
			trace = ''
		lessStream = less opt.lessOpt
		lessStream.pipe through.obj(
			(file, enc, next) ->
				file.contents = new Buffer [
					trace + '<style type="text/css">'
						file.contents.toString()
					'</style>'
				].join EOL
				resolve file
				next()
		)
		lessStream.on 'error', (e) ->
			console.log 'gulp-mt2amd Error:', e.message
			console.log 'file:', file.path
			console.log 'line:', e.line
		lessStream.end file

compileSass = (file, opt) ->
	Q.Promise (resolve, reject) ->
		if opt.trace
			trace = '<%/* trace:' + path.relative(process.cwd(), file.path) + ' */%>' + EOL
		else
			trace = ''
		sassStream = sass opt.sassOpt
		sassStream.on 'data', (file) ->
			file.contents = new Buffer [
				trace + '<style type="text/css">'
					file.contents.toString()
				'</style>'
			].join EOL
			resolve file
		sassStream.on 'error', (e) ->
			console.log 'gulp-mt2amd Error:', e.message
			console.log 'file:', file.path
		sassStream.write file

compileCss = (file, opt) ->
	Q.Promise (resolve, reject) ->
		if opt.trace
			trace = '<%/* trace:' + path.relative(process.cwd(), file.path) + ' */%>' + EOL
		else
			trace = ''
		file.contents = new Buffer [
			trace + '<style type="text/css">'
			file.contents.toString()
			'</style>'
		].join EOL
		resolve file

compile = (file, opt, wrap) ->
	Q.Promise (resolve, reject) ->
		content = file.contents.toString()
		asyncList = []
		content = content.replace /<!--\s*include\s+(['"])([^'"]+)\.(tpl\.html|less|scss|css)\1\s*-->/mg, (full, quote, incName, ext) ->
			asyncMark = '<INC_PROCESS_ASYNC_MARK_' + asyncList.length + '>'
			incFilePath = path.resolve path.dirname(file.path), incName + '.' + ext
			incFile = new gutil.File
				base: file.base
				cwd: file.cwd
				path: incFilePath
				contents: fs.readFileSync incFilePath
			if ext is 'tpl.html'
				asyncList.push compile(incFile, opt, true)
			if ext is 'less'
				asyncList.push compileLess(incFile, opt)
			if ext is 'scss'
				asyncList.push compileSass(incFile, opt)
			if ext is 'css'
				asyncList.push compileCss(incFile, opt)
			asyncMark
		Q.all(asyncList).then(
			(results) ->
				results.forEach (incFile, i) ->
					content = content.replace '<INC_PROCESS_ASYNC_MARK_' + i + '>', incFile.contents.toString()
				strict = (/(^|[^.]+)\B\$data\./).test content
				if opt.trace
					trace = '<%/* trace:' + path.relative(process.cwd(), file.path) + ' */%>' + EOL
				else
					trace = ''
				content = [
					trace + content
				]
				if not strict
					content.unshift '<%with($data) {%>'
					content.push '<%}%>'
				if wrap
					content.unshift '<%;(function() {%>'
					content.push '<%})();%>'
				file.contents = new Buffer content.join EOL
				resolve file
			(err) ->
				reject err
		).done()

beautify = (content, beautifyOpt) ->
	if typeof beautifyOpt isnt 'object'
		beautifyOpt = {}
	beautifyOpt.beautify = true
	beautifyOpt.comments = ->
		true
	ast = uglify.parse content
	content = ast.print_to_string beautifyOpt

getErrorStack = (content, line) ->
	startLine = Math.max 1, line - 2
	maxLineNoLen = 0
	content = content.split(/\n|\r\n|\r/).slice startLine - 1, line + 2
	content.forEach (l, i) ->
		lineNo = (startLine + i) + (if startLine + i is line then ' ->' else '   ') + '| '
		maxLineNoLen = Math.max(maxLineNoLen, lineNo.length)
		content[i] = lineNo + l
	content.forEach (l, i) ->
		if l.split('|')[0].length + 2 < maxLineNoLen
			content[i] = ' ' + l
	content.join EOL

module.exports = (opt = {}) ->
	through.obj (file, enc, next) ->
		return @emit 'error', new gutil.PluginError('gulp-mt2amd', 'File can\'t be null') if file.isNull()
		return @emit 'error', new gutil.PluginError('gulp-mt2amd', 'Streams not supported') if file.isStream()
		module.exports.compile(file, opt).then(
			(file) =>
				@push file
				next()
			(err) =>
				@emit 'error', new gutil.PluginError('gulp-mt2amd', err)
		).done()

module.exports.compile = (file, opt = {}) ->
	Q.Promise (resolve, reject) ->
		compile(file, opt).then(
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
					"		_$out_.push('" + processed.contents.toString().replace /<\/script>/ig, '</s<%=""%>cript>'
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
				if opt.beautify
					try
						content = beautify content, opt.beautify
					catch e
						console.log 'gulp-mt2amd Error:', e.message
						console.log 'file:', file.path
						console.log getErrorStack(content, e.line)
				file.contents = new Buffer content
				file.path = file.path + '.js'
				resolve file
			(err) =>
				reject err
		).done()
