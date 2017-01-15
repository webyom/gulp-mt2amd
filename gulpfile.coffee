gulp = require 'gulp'
coffee = require 'gulp-coffee'
postcss = require 'postcss'
postcssImport = require 'postcss-import'
autoprefixer = require 'autoprefixer-core'
imgCssSprite = require 'gulp-img-css-sprite'

gulp.task 'compile', ->
	gulp.src('src/**/*.coffee')
		.pipe coffee()
		.pipe gulp.dest('lib')

gulp.task 'sprite', ->
	gulp.src('example/src/**/*.+(jpg|png)')
		.pipe imgCssSprite.imgStream
			padding: 2
		.pipe gulp.dest('example/dest')

gulp.task 'example', ['sprite'], ->
	mt2amd = require './lib/index'
	gulp.src(['example/src/**/*.json', 'example/src/**/*.tag', 'example/src/**/*.tpl.html', 'example/src/**/*.css', 'example/src/**/*.less', 'example/src/**/*.scss', 'example/src/**/*.+(png|jpg|jpeg|gif|svg)'])
		.pipe mt2amd
			generateDataUri: true
			cssSprite:
				base:
					url: '//webyom.org'
					dir: 'example/src'
			beautify: true
			trace: true
			postcss: (file, type) ->
				res = postcss()
					.use postcssImport()
					.use autoprefixer browsers: ['last 2 version']
					.process file.contents.toString(),
						from: file.path
				res.css
		.pipe gulp.dest('example/dest')

gulp.task 'default', ['compile']
