(function() {
  var EOL, Q, compile, fs, gutil, less, path, through;

  Q = require('q');

  fs = require('fs');

  path = require('path');

  less = require('less');

  gutil = require('gulp-util');

  through = require('through2');

  EOL = '\n';

  module.exports = function() {
    return through.obj(function(file, enc, next) {
      if (file.isNull()) {
        return this.emit('error', new gutil.PluginError('gulp-mt2amd', 'File can\'t be null'));
      }
      if (file.isStream()) {
        return this.emit('error', new gutil.PluginError('gulp-mt2amd', 'Streams not supported'));
      }
      return module.exports.compile(file).then((function(_this) {
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

  module.exports.compile = function(file) {
    return Q.Promise(function(resolve, reject) {
      return compile(file).then((function(_this) {
        return function(processed) {
          var content;
          content = [
            "define(function(require, exports, module) {", "	function $encodeHtml(str) {", "		return (str + '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/\x60/g, '&#96;').replace(/\x27/g, '&#39;').replace(/\x22/g, '&quot;');", "	}", "	exports.render = function($data, $opt) {", "		$data = $data || {};", "		var _$out_= [];", "		var $print = function(str) {_$out_.push(str);};", "		_$out_.push('" + processed.contents.toString('utf8').replace(/<\/script>/ig, '</s<%=""%>cript>').replace(/\r\n|\n|\r/g, "\v").replace(/(?:^|%>).*?(?:<%|$)/g, function($0) {
              return $0.replace(/('|\\)/g, "\\$1").replace(/[\v\t]/g, "").replace(/\s+/g, " ");
            }).replace(/[\v]/g, EOL).replace(/<%==(.*?)%>/g, "', $encodeHtml($1), '").replace(/<%=(.*?)%>/g, "', $1, '").replace(/<%(<-)?/g, "');" + EOL + "		").replace(/->(\w+)%>/g, EOL + "		$1.push('").split("%>").join(EOL + "		_$out_.push('") + "');", "		return _$out_.join('');", "	};", "});"
          ].join(EOL).replace(/_\$out_\.push\(''\);/g, '');
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

  compile = function(file, wrap) {
    return Q.Promise(function(resolve, reject) {
      var asyncList, content;
      content = file.contents.toString('utf-8');
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
          asyncList.push(Q.Promise(function(resolve, reject) {
            return less.render(incFile.contents.toString('utf-8'), {
              paths: path.dirname(incFilePath),
              strictMaths: false,
              strictUnits: false,
              filename: incFilePath
            }, function(err, css) {
              if (err) {
                return reject(err);
              } else {
                incFile.contents = new Buffer(['<style type="text/css">', css, '</style>'].join(EOL));
                return resolve(incFile);
              }
            });
          }));
        } else {
          asyncList.push(compile(incFile, true));
        }
        return asyncMark;
      });
      return Q.all(asyncList).then(function(results) {
        var strict;
        results.forEach(function(incFile, i) {
          return content = content.replace('<INC_PROCESS_ASYNC_MARK_' + i + '>', incFile.contents.toString('utf8'));
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

}).call(this);
