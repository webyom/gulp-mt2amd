gulp = require 'gulp'
coffee = require 'gulp-coffee'
postcss = require 'postcss'
postcssImport = require 'postcss-import'
autoprefixer = require 'autoprefixer-core'

gulp.task 'compile', ->
	gulp.src('src/**/*.coffee')
		.pipe coffee()
		.pipe gulp.dest('lib')

gulp.task 'example', ->
	mt2amd = require './lib/index'
	gulp.src('example/src/**/*.tpl.html')
		.pipe mt2amd
			base64img: true
			beautify: true
			trace: true
			postcss: (file) ->
				res = postcss()
					.use postcssImport()
					.use autoprefixer browsers: ['last 2 version']
					.process file.contents.toString(),
						from: file.path
				res.css
		.pipe gulp.dest('example/dest')

gulp.task 'default', ['compile']