(function() {
  var EOL, Q, beautify, compile, compileLess, fs, gutil, less, path, through, uglify;

  Q = require('q');

  fs = require('fs');

  path = require('path');

  less = require('less');

  gutil = require('gulp-util');

  through = require('through2');

  uglify = require('uglify-js');

  EOL = '\n';

  compileLess = function(file) {
    return Q.Promise(function(resolve, reject) {
      return less.render(file.contents.toString(), {
        paths: path.dirname(file.path),
        strictMaths: false,
        strictUnits: false,
        filename: file.path
      }, function(err, css) {
        if (err) {
          return reject(err);
        } else {
          file.contents = new Buffer(['<style type="text/css">', css, '</style>'].join(EOL));
          return resolve(file);
        }
      });
    });
  };

  compile = function(file, wrap) {
    return Q.Promise(function(resolve, reject) {
      var asyncList, content;
      content = file.contents.toString();
      asyncList = [];
      content = content.replace(/<!--\s*include\s+(['"])([^'"]+)\.(tpl\.html|less)\1\s*-->/mg, function(full, quote, incName, ext) {
        var asyncMark, incFile, incFilePath;
        asyncMark = '<INC_PROCESS_ASYNC_MARK_' + asyncList.length + '>';
        incFilePath = path.resolve(path.dirname(file.path), incName + '.' + ext);
        incFile = new gutil.File({
          base: file.base,
          cwd: file.cwd,
          path: incFilePath,
          contents: fs.readFileSync(incFilePath)
        });
        if (ext === 'less') {
          asyncList.push(compileLess(incFile));
        } else {
          asyncList.push(compile(incFile, true));
        }
        return asyncMark;
      });
      return Q.all(asyncList).then(function(results) {
        var strict;
        results.forEach(function(incFile, i) {
          return content = content.replace('<INC_PROCESS_ASYNC_MARK_' + i + '>', incFile.contents.toString());
        });
        strict = /(^|[^.]+)\B\$data\./.test(content);
        content = [content];
        if (!strict) {
          content.unshift('<%with($data) {%>');
          content.push('<%}%>');
        }
        if (wrap) {
          content.unshift('<%;(function() {%>');
          content.push('<%})();%>');
        }
        file.contents = new Buffer(content.join(EOL));
        return resolve(file);
      }, function(err) {
        return reject(err);
      }).done();
    });
  };

  beautify = function(content) {
    var ast;
    ast = uglify.parse(content);
    return content = ast.print_to_string({
      beautify: true
    });
  };

  module.exports = function(opt) {
    if (opt == null) {
      opt = {};
    }
    return through.obj(function(file, enc, next) {
      if (file.isNull()) {
        return this.emit('error', new gutil.PluginError('gulp-mt2amd', 'File can\'t be null'));
      }
      if (file.isStream()) {
        return this.emit('error', new gutil.PluginError('gulp-mt2amd', 'Streams not supported'));
      }
      return module.exports.compile(file, opt).then((function(_this) {
        return function(file) {
          _this.push(file);
          return next();
        };
      })(this), (function(_this) {
        return function(err) {
          return _this.emit('error', new gutil.PluginError('gulp-mt2amd', err));
        };
      })(this)).done();
    });
  };

  module.exports.compile = function(file, opt) {
    if (opt == null) {
      opt = {};
    }
    return Q.Promise(function(resolve, reject) {
      return compile(file).then((function(_this) {
        return function(processed) {
          var content;
          content = [
            "define(function(require, exports, module) {", "	function $encodeHtml(str) {", "		return (str + '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/\x60/g, '&#96;').replace(/\x27/g, '&#39;').replace(/\x22/g, '&quot;');", "	}", "	exports.render = function($data, $opt) {", "		$data = $data || {};", "		var _$out_= [];", "		var $print = function(str) {_$out_.push(str);};", "		_$out_.push('" + processed.contents.toString().replace(/<\/script>/ig, '</s<%=""%>cript>').replace(/\r\n|\n|\r/g, "\v").replace(/(?:^|%>).*?(?:<%|$)/g, function($0) {
              return $0.replace(/('|\\)/g, "\\$1").replace(/[\v\t]/g, "").replace(/\s+/g, " ");
            }).replace(/[\v]/g, EOL).replace(/<%==(.*?)%>/g, "', $encodeHtml($1), '").replace(/<%=(.*?)%>/g, "', $1, '").replace(/<%(<-)?/g, "');" + EOL + "		").replace(/->(\w+)%>/g, EOL + "		$1.push('").split("%>").join(EOL + "		_$out_.push('") + "');", "		return _$out_.join('');", "	};", "});"
          ].join(EOL).replace(/_\$out_\.push\(''\);/g, '');
          if (opt.beautify) {
            content = beautify(content);
          }
          file.contents = new Buffer(content);
          file.path = file.path + '.js';
          return resolve(file);
        };
      })(this), (function(_this) {
        return function(err) {
          return reject(err);
        };
      })(this)).done();
    });
  };

}).call(this);
