var gulp = require('gulp');
var coffee = require('gulp-coffee');
var rename = require('gulp-rename');
var gutil = require('gulp-util');

gulp.task('build', function() {
  return gulp.src('./phoenix.litcoffee')
    .pipe(coffee({bare: true}).on('error', gutil.log))
    .pipe(rename({prefix: '.'}))
    .pipe(gulp.dest('./build'));
});

gulp.task('install', ['build'], function() {
  return gulp.src('./build/.phoenix.js')
    .pipe(gulp.dest(process.env['HOME']));
})

gulp.task('watch', ['install'], function() {
  gulp.watch('./phoenix.litcoffee', ['install']);
});

gulp.task('default', ['install']);
