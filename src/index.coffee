_ = require 'lodash'
Q = require 'q'
fs = require 'fs'
path = require 'path'
crypto = require 'crypto'
less = require 'gulp-less'
sass = require 'gulp-sass'
gutil = require 'gulp-util'
through = require 'through2'
uglify = require 'uglify-js'
minifier = require 'gulp-minifier'
sus = require 'gulp-sus'
gulpCssSprite = require 'gulp-img-css-sprite'

EOL = '\n'
EXPORTS_REGEXP = /(^|[^.])\b(module\.exports|exports\.[^.]+)\s*=[^=]/

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
						file.contents = new Buffer content
						minifier.minify file, minifyCSS: true
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
					file.contents = new Buffer content
					minifier.minify file, minifyCSS: true
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
				file.contents = new Buffer content
				minifier.minify file, minifyCSS: true
				resolve file
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
							if path.extname(incFile.path) is '.css'
								incContent = [
									'<style type="text/css">'
									incFile.contents.toString()
									'</style>'
								].join EOL
							else
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
		relativePath = path.relative process.cwd(), originFilePath
		extName = path.extname(originFilePath).toLowerCase()
		if extName is '.json'
			if opt.trace
				trace = '/* trace:' + relativePath + ' */' + EOL
			else
				trace = ''
			try
				content = JSON.parse(file.contents.toString())
			catch e
				gutil.log gutil.colors.red 'gulp-mt2amd Error: invalid json file ' + file.path
				throw e
			exportContent = JSON.stringify(content, null, 2);
			content = [
				trace + if opt.commonjs or opt.es6 then "" else "define(function(require, exports, module) {"
				if opt.es6 then "export default " + exportContent + ";" else "module.exports = " + exportContent + ";"
				if opt.commonjs or opt.es6 then "" else "});"
			].join EOL
			file.contents = new Buffer content
			file.path = originFilePath + '.js'
			resolve file
		else if extName in ['.png', '.jpg', '.jpeg', '.gif', '.svg']
			if opt.trace
				trace = '/* trace:' + relativePath + ' */' + EOL
			else
				trace = ''
			exportContent = '"data:image/' + extName.replace(/^\./, '') + ';base64,' + fs.readFileSync(originFilePath, 'base64') + '"';
			content = [
				trace + if opt.commonjs or opt.es6 then "" else "define(function(require, exports, module) {"
				if opt.es6 then "export default " + exportContent + ";" else "module.exports = " + exportContent + ";"
				if opt.commonjs or opt.es6 then "" else "});"
			].join EOL
			file.contents = new Buffer content
			file.path = originFilePath + '.js'
			resolve file
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
						trace = '/* trace:' + relativePath + ' */' + EOL
					else
						trace = ''
					cssContent = file.contents.toString().replace(/\r\n|\n|\r/g, '').replace(/('|\\)/g, '\\$1')
					digest = crypto.createHash('md5')
						.update(cssContent)
						.digest('hex')
					moduleClassName = digest.slice(0, if opt.cssModuleClassNameLength > 0 then opt.cssModuleClassNameLength else 32)
					originalCssContent = cssContent
					cssContent = cssContent.replace new RegExp('\\.' + (opt.cssModuleClassNamePlaceholder || '__module_class_name__'), 'g'), '.' + moduleClassName
					moduleClassName = '' if cssContent is originalCssContent
					content = [
						trace + if opt.commonjs or opt.es6 then "" else "define(function(require, exports, module) {"
						"var moduleClassName = '" + moduleClassName + "';"
						"var cssContent = '" + cssContent + "';"
						"""
						var moduleUri = typeof(module) != 'undefined' && module.uri;
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
						"""
						if opt.es6 then "__MT2AMD_ES6_EXPORT_DEFAULT__+{moduleClassName: moduleClassName, cssContent: cssContent};" else "module.exports = {moduleClassName: moduleClassName, cssContent: cssContent};"
						if opt.commonjs or opt.es6 then "" else "});"
					].join(EOL)
					if opt.beautify
						try
							content = beautify content, opt.beautify
						catch e
							console.log 'gulp-mt2amd Error:', e.message
							console.log 'file:', file.path
							console.log getErrorStack(content, e.line)
					if opt.es6
						content = content.replace /__MT2AMD_ES6_EXPORT_DEFAULT__\s*\+\s*/g, 'export default '
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
						if opt.commonjs or opt.es6 then "" else "define(function(require, exports, module) {"
						"	function $encodeHtml(str) {"
						"		return (str + '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/\x60/g, '&#96;').replace(/\x27/g, '&#39;').replace(/\x22/g, '&quot;');"
						"	}"
						"	function render($data, $opt) {"
						"		$data = $data || {};"
						"		var _$out_= '';"
						"		var $print = function(str) {_$out_ += str;};"
						"		_$out_ += '" + processed.contents.toString().replace /<\/script>/ig, '</s<%=""%>cript>'
								.replace(/\r\n|\n|\r/g, "\v")
								.replace(/(?:^|%>).*?(?:<%|$)/g, ($0) ->
									$0.replace(/('|\\)/g, "\\$1").replace(/[\v\t]/g, "").replace(/\s+/g, " ")
								)
								.replace(/[\v]/g, EOL)
								.replace(/<%==(.*?)%>/g, "' + $encodeHtml($1) + '")
								.replace(/<%=(.*?)%>/g, "' + ($1) + '")
								.replace(/<%(<-)?/g, "';" + EOL + "		")
								.replace(/->(\w+)%>/g, EOL + "		$1 += '")
								.split("%>").join(EOL + "		_$out_ += '") + "';"
						"		return _$out_;"
						"	}"
						if opt.es6 then "__MT2AMD_ES6_EXPORT_DEFAULT__+{render: render};" else "exports.render = render;"
						if opt.commonjs or opt.es6 then "" else "});"
					].join(EOL).replace(/_\$out_ \+= '';/g, '')
					content = fixDefineParams content if not opt.commonjs
					if opt.beautify
						try
							content = beautify content, opt.beautify
						catch e
							console.log 'gulp-mt2amd Error:', e.message
							console.log 'file:', file.path
							console.log getErrorStack(content, e.line)
					if opt.es6
						content = content.replace /__MT2AMD_ES6_EXPORT_DEFAULT__\s*\+\s*/g, 'export default '
					file.contents = new Buffer content
					file.path = file.path + '.js'
					resolve file
				(err) =>
					reject err
			).done()
