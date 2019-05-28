(function (global) {
  var docHead = document.head || document.getElementsByTagName('head')[0];
  var maxTags = global._yom_max_injected_style_tags || 100;
  var tagAmount = 0;
  var injected = {};
  var reusedTag;
  global.yomCssModuleHelper = global.yomCssModuleHelper || function (className, cssContent, moduleUri) {
    var id;
    if (moduleUri && className) {
      id = className + '_' + moduleUri;
    } else if (moduleUri) {
      id = moduleUri;
    } else if (className) {
      id = className;
    }
    var styleTag;
    if (reusedTag) {
      styleTag = reusedTag;
    } else {
      styleTag = document.createElement('style');
      styleTag.type = 'text/css';
      if (id) {
        styleTag.setAttribute('data-id', id);
      }
      styleTag = docHead.appendChild(styleTag);
      if (++tagAmount >= maxTags) {
        reusedTag = styleTag;
      }
    }
    if (!id) {
      styleTag.appendChild(document.createTextNode(cssContent + '\n'));
    } else if(!injected[id]) {
      styleTag.appendChild(document.createTextNode('/* ' + id + ' */\n' + cssContent + '\n'));
      injected[id] = 1;
    }
    function formatClassName(cn) {
      return cn.replace(/^\s*&/, className).replace(/\s+&/g, ' ' + className).replace(/&/g, '')
    }
    function moduleClassNames() {
      var cns = [];
      var args = Array.prototype.slice.call(arguments);
      if (!args.length) {
        return className;
      }
      args.forEach(function (cn) {
        if (typeof cn == 'object') {
          Object.keys(cn).forEach(function (k) {
            if (cn[k]) {
              k = formatClassName(k);
              k && cns.push(k);
            }
          });
        } else {
          cn = formatClassName(cn);
          cn && cns.push(cn);
        }
      });
      return cns.join(' ');
    }
    return {
      moduleClassNames: moduleClassNames,
      cssContent: cssContent
    };
  };
})(typeof global == 'undefined' ? self : global);
