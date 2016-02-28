_ = require 'lodash'
Q = require 'q'
fs = require 'fs'
path = require 'path'
less = require 'gulp-less'
sass = require 'gulp-sass'
gutil = require 'gulp-util'
through = require 'through2'
uglify = require 'uglify-js'
sus = require 'gulp-sus'
gulpCssSprite = require 'gulp-img-css-sprite'
riot = require 'riot'

EOL = '\n'
EXPORTS_REGEXP = /(^|[^.])\b(module\.exports|exports\.[^.]+)\s*=[^=]/
RIOT_EXT_REGEXP = /(\.riot\.html|\.tag)$/

getUnixStylePath = (p) ->
	p.split(path.sep).join '/'

getBodyDeps = (def) ->
	deps = []
	got = {}
	def = def.replace /(^|[^.])\brequire\s*\(\s*(["'])([^"']+?)\2\s*\)/mg, (full, lead, quote, dep) ->
		pDep = dep.replace /\{\{([^{}]+)\}\}/g, quote + ' + $1 + ' + quote
		qDep = quote + pDep + quote
		got[dep] || deps.push qDep
		got[dep] = 1
		if pDep is dep
			full
		else
			lead + 'require(' + qDep + ')'
	{
		def: def
		deps: deps
	}

fixDefineParams = (def, depId, userDefinedBaseDir) ->
	def = getBodyDeps def
	bodyDeps = def.deps
	fix = (full, b, d, quote, definedId, deps) ->
		if bodyDeps.length
			if (/^\[\s*\]$/).test deps
				deps = "['require', 'exports', 'module', " + bodyDeps.join(', ') + "]"
			else if deps
				tmp = deps.replace(/'/g, '"').replace(/\s+/g, '').replace(/"\+"/g, '+')
				deps = deps.replace(/^\[\s*|\s*\]$/g, '').split(/\s*,\s*/)
				for bodyDep in bodyDeps
					if tmp.indexOf(bodyDep.replace(/'/g, '"').replace(/\s+/g, '').replace(/"\+"/g, '+')) is -1
						deps.push bodyDep
				deps = '[' + deps.join(', ') + ']'
			else
				deps = "['require', 'exports', 'module', " + bodyDeps.join(', ') + "], "
		if definedId and not (/^\./).test definedId
			id = definedId
		else
			id = depId || ''
			if id and not userDefinedBaseDir and not (/^\./).test(id)
				id = './' + id
		[b, d, id && ("'" + getUnixStylePath(id) + "', "), deps || "['require', 'exports', 'module'], "].join ''
	if not (/(^|[^.])\bdefine\s*\(/).test(def.def) and EXPORTS_REGEXP.test(def.def)
		def = [
			fix('define(', '', 'define(') + 'function(require, exports, module) {'
			def.def
			'});'
		].join EOL
	else
		def = def.def.replace /(^|[^.])\b(define\s*\()\s*(?:(["'])([^"'\s]+)\3\s*,\s*)?\s*(\[[^\[\]]*\])?/m, fix
	def

htmlBase64img = (data, base, opt) ->
	Q.Promise (resolve, reject) ->
		if opt.generateDataUri
			data = data.replace /<img\s([^>]*)src="([^"]+)"/ig, (full, extra, imgPath) ->
				if not (/^data:|\/\//i).test(imgPath)
					imgPath = path.resolve(base, imgPath)
					if fs.existsSync imgPath
						'<img ' + extra + 'src="data:image/' + path.extname(imgPath).replace(/^\./, '') + ';base64,' + fs.readFileSync(imgPath, 'base64') + '"'
					else
						full
				else
					full
			resolve data
		else
			resolve data

cssBase64img = (content, filePath, opt) ->
	Q.Promise (resolve, reject) ->
		if opt.generateDataUri
			sus.cssContent(content, filePath).then(
				(content) ->
					resolve content
				(err) ->
					reject err
			).done()
		else
			resolve content

cssSprite = (content, filePath, opt) ->
	Q.Promise (resolve, reject) ->
		if opt.cssSprite
			gulpCssSprite.cssContent(content, filePath, opt.cssSprite).then(
				(content) ->
					resolve content
				(err) ->
					reject err
			).done()
		else
			resolve content

compileLess = (file, opt) ->
	Q.Promise (resolve, reject) ->
		if opt.trace
			trace = '/* trace:' + path.relative(process.cwd(), file.path) + ' */' + EOL
		else
			trace = ''
		file._originalPath = file.path
		lessStream = less opt.lessOpt
		lessStream.pipe through.obj(
			(file, enc, next) ->
				content = if opt.postcss then opt.postcss(file, 'less') else file.contents.toString()
				cssSprite(content, file.path, opt).then(
					(content) ->
						cssBase64img(content, file.path, opt)
				).then(
					(content) ->
						file.contents = new Buffer [
							'<style type="text/css">'
								content
							'</style>'
						].join EOL
						file._cssContents = new Buffer content
						resolve file
						next()
					(err) ->
						reject err
				).done()
		)
		lessStream.on 'error', (e) ->
			console.log 'gulp-mt2amd Error:', e.message
			console.log 'file:', file.path
			console.log 'line:', e.line
		lessStream.end file

compileSass = (file, opt) ->
	Q.Promise (resolve, reject) ->
		if opt.trace
			trace = '/* trace:' + path.relative(process.cwd(), file.path) + ' */' + EOL
		else
			trace = ''
		file._originalPath = file.path
		sassStream = sass opt.sassOpt
		sassStream.on 'data', (file) ->
			content = if opt.postcss then opt.postcss(file, 'scss') else file.contents.toString()
			cssSprite(content, file.path, opt).then(
				(content) ->
					cssBase64img(content, file.path, opt)
			).then(
				(content) ->
					file.contents = new Buffer [
						'<style type="text/css">'
							content
						'</style>'
					].join EOL
					file._cssContents = new Buffer content
					resolve file
				(err) ->
					reject err
			).done()
		sassStream.on 'error', (e) ->
			console.log 'gulp-mt2amd Error:', e.message
			console.log 'file:', file.path
		sassStream.write file

compileCss = (file, opt) ->
	Q.Promise (resolve, reject) ->
		if opt.trace
			trace = '/* trace:' + path.relative(process.cwd(), file.path) + ' */' + EOL
		else
			trace = ''
		file._originalPath = file.path
		content = if opt.postcss then opt.postcss(file, 'css') else file.contents.toString()
		cssSprite(content, file.path, opt).then(
			(content) ->
				cssBase64img(content, file.path, opt)
		).then(
			(content) ->
				file.contents = new Buffer [
					'<style type="text/css">'
						content
					'</style>'
				].join EOL
				file._cssContents = new Buffer content
				resolve file
			(err) ->
				reject err
		).done()

compileRiot = (file, opt) ->
	Q.Promise (resolve, reject) ->
		content = file.contents.toString()
		asyncList = []
		content = content.replace /<!--\s*include\s+(['"])([^'"]+)\.(less|scss|css)\1\s*-->/mg, (full, quote, incName, ext) ->
			asyncMark = '<INC_PROCESS_ASYNC_MARK_' + asyncList.length + '>'
			incFilePath = path.resolve path.dirname(file.path), incName + '.' + ext
			incFile = new gutil.File
				base: file.base
				cwd: file.cwd
				path: incFilePath
				contents: fs.readFileSync incFilePath
			if ext is 'less'
				asyncList.push compileLess(incFile, _.extend({}, opt, {_riot: true}))
			if ext is 'scss'
				asyncList.push compileSass(incFile, _.extend({}, opt, {_riot: true}))
			if ext is 'css'
				asyncList.push compileCss(incFile, _.extend({}, opt, {_riot: true}))
			asyncMark
		Q.all(asyncList).then(
			(results) ->
				htmlBase64img(content, path.dirname(file.path), opt).then(
					(content) ->
						results.forEach (incFile, i) ->
							incContent = incFile.contents.toString()
							if opt.trace
								trace = '/* trace:' + path.relative(process.cwd(), incFile._originalPath || incFile.path) + ' */' + EOL
							else
								trace = ''
							content = trace + content.replace '<INC_PROCESS_ASYNC_MARK_' + i + '>', incContent
						riotOpt = _.extend {}, opt.riotOpt
						m = content.match /(?:^|\r\n|\n|\r)\/\*\*\s*@riot\s+(coffeescript|es6)/
						if m
							riotOpt.type = m[1]
						content = riot.compile content, riotOpt
						file.contents = new Buffer content
						resolve file
					(err) ->
						reject err
				).done()
			(err) ->
				reject err
		).done()

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
				htmlBase64img(content, path.dirname(file.path), opt).then(
					(content) ->
						results.forEach (incFile, i) ->
							incContent = incFile.contents.toString()
							if opt.trace
								trace = '<%/* trace:' + path.relative(process.cwd(), incFile._originalPath || incFile.path) + ' */%>' + EOL
							else
								trace = ''
							content = content.replace '<INC_PROCESS_ASYNC_MARK_' + i + '>', trace + incContent
						strict = (/(^|[^.])\B\$data\./).test content
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

module.exports.fixDefineParams = fixDefineParams

module.exports.compile = (file, opt = {}) ->
	Q.Promise (resolve, reject) ->
		originFilePath = file.path
		extName = path.extname originFilePath
		if RIOT_EXT_REGEXP.test originFilePath
			compileRiot(file, opt).then(
				(file) ->
					if opt.trace
						trace = '/* trace:' + path.relative(process.cwd(), originFilePath) + ' */' + EOL
					else
						trace = ''
					processedContent = file.contents.toString()
					content = [
						trace
						if opt.commonjs then "" else "define(function(require, exports, module) {"
						if (/(?:^|[^.])\brequire\s*\((["'])riot\1\s*\)/).test processedContent then "" else "riot = require('riot');"
						processedContent
						if EXPORTS_REGEXP.test processedContent then "" else "module.exports = '" + path.basename(originFilePath).replace(RIOT_EXT_REGEXP, '') + "'"
						if opt.commonjs then "" else "});"
					].join(EOL)
					content = fixDefineParams content if not opt.commonjs
					if opt.beautify
						try
							content = beautify content, opt.beautify
						catch e
							console.log 'gulp-mt2amd Error:', e.message
							console.log 'file:', file.path
							console.log getErrorStack(content, e.line)
					file.contents = new Buffer content
					file.path = originFilePath.replace RIOT_EXT_REGEXP, '.js'
					resolve file
				(err) ->
					reject err
			).done()
		else if extName in ['.less', '.scss', '.css']
			if extName is '.less'
				cssCompiler = compileLess
			else if extName is '.scss'
				cssCompiler = compileSass
			else
				cssCompiler = compileCss
			cssCompiler(file, opt).then(
				(file) ->
					if opt.trace
						trace = '/* trace:' + path.relative(process.cwd(), originFilePath) + ' */' + EOL
					else
						trace = ''
					content = [
						if opt.commonjs then "" else "define(function(require, exports, module) {"
						trace + "var cssContent = '" + file._cssContents.toString().replace(/\r\n|\n|\r/g, '').replace(/\s+/g, ' ') + "';"
						"""
						var moduleUri = module && module.uri;
						var head = document.head || document.getElementsByTagName('head')[0];
						var styleTagId = 'yom-style-module-inject-tag';
						var styleTag = document.getElementById(styleTagId);
						if (!styleTag) {
							styleTag = document.createElement('style');
							styleTag.id = styleTagId;
							styleTag.type = 'text/css';
							styleTag = head.appendChild(styleTag);
						}
						window._yom_style_module_injected = window._yom_style_module_injected || {};
						if (!moduleUri) {
							styleTag.appendChild(document.createTextNode(cssContent + '\\n'));
						} else if(!window._yom_style_module_injected[moduleUri]) {
							styleTag.appendChild(document.createTextNode('/* ' + moduleUri + ' */\\n' + cssContent + '\\n'));
							window._yom_style_module_injected[moduleUri] = 1;
						}
						module.exports = cssContent;
						"""
						if opt.commonjs then "" else "});"
					].join(EOL)
					if opt.beautify
						try
							content = beautify content, opt.beautify
						catch e
							console.log 'gulp-mt2amd Error:', e.message
							console.log 'file:', file.path
							console.log getErrorStack(content, e.line)
					file.contents = new Buffer content
					file.path = originFilePath + '.js'
					resolve file
				(err) ->
					reject err
			).done()
		else
			compile(file, opt).then(
				(processed) =>
					content = [
						if opt.commonjs then "" else "define(function(require, exports, module) {"
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
						if opt.commonjs then "" else "});"
					].join(EOL).replace(/_\$out_\.push\(''\);/g, '')
					content = fixDefineParams content if not opt.commonjs
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
