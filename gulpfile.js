var gulp = require('gulp');
var coffee = require('gulp-coffee');

gulp.task('compile', function (){
	return gulp.src('src/**/*.coffee')
		.pipe(coffee())
		.pipe(gulp.dest('lib'));
});

gulp.task('example', function (){
	var mt2amd = require('./lib/index');
	return gulp.src('example/src/**/*.tpl.html')
		.pipe(mt2amd())
		.pipe(gulp.dest('example/dest'));
});

gulp.task('default', ['compile']);