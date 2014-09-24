const clean  = require('gulp-clean');
const coffee = require('gulp-coffee');
const gulp   = require('gulp');
const gutil  = require('gulp-util');
const notify = require('gulp-notify');


// gulp -> gulp watch
gulp.task('default', ['watch']);


// gulp build -> compile coffee script
gulp.task('build', ['clean'], function() {
  const compile = coffee({ bare: true })
    .on('error', function(error) {
      notify({
        title:    'Fail!',
        message:  error.toString()
      }).write(error);
    });
  gulp.src('src/**/*.coffee')
    .pipe(compile)
    .pipe( notify({
      title:    'Success!',
      message:  'Compiled Zombie.js',
      onLast:   true
    }) )
    .pipe( gulp.dest('lib/') );
});


// gulp clean -> clean generated files
gulp.task('clean', function() {
  return gulp
    .src('lib', { read: false })
    .pipe( clean() );
});


// gulp watch -> watch for changes and compile
gulp.task('watch', ['build'], function() {
  return gulp.watch('src/**/*.coffee', ['clean', 'build']);
});

