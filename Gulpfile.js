const assert      = require('assert');
const del         = require('del');
const eslint      = require('gulp-eslint');
const exec        = require('gulp-exec');
const File        = require('fs');
const gulp        = require('gulp');
const gutil       = require('gulp-util');
const notify      = require('gulp-notify');
const sourcemaps  = require('gulp-sourcemaps');
const babel       = require('gulp-babel');


function lint() {
  return gulp.src([ 'src/**/*.js', 'test/*.js' ])
    .pipe(eslint())
    .pipe(eslint.formatEach())
    .pipe(eslint.failOnError());
}


function clean() {
  return del('lib/**');
}


function build() {
  return gulp.src('src/**/*.js')
    .pipe(sourcemaps.init())
    .pipe(babel())
    .pipe(sourcemaps.write('.'))
    .pipe(gulp.dest('lib'))
    .pipe(notify({
      message: 'Zombie: built!',
      onLast:  true
    }));
}


function watch() {
  return gulp.watch('src/*.js', gulp.series(clean, build));
}


// Generate a change log summary for this release
// git tag uses the generated .changes file
function changes() {
  const version   = require('./package.json').version;
  const changelog = File.readFileSync('CHANGELOG.md', 'utf-8');
  const match     = changelog.match(/^## Version (.*) .*\n([\S\s]+?)\n##/m);

  assert(match, 'CHANGELOG.md missing entry: ## Version ' + version);
  assert.equal(match[1], version, 'CHANGELOG.md missing entry for version ' + version);

  const changes   = match[2].trim();
  assert(changes, 'CHANGELOG.md empty entry for version ' + version);
  File.writeFileSync('.changes', changes);
}


function tag() {
  const version = require('./package.json').version;
  const tag     = 'v' + version;

  gutil.log('Tagging this release', tag);
  return gulp.src('.changes')
    .pipe( exec('git add package.json CHANGELOG.md') )
    .pipe( exec('git commit --allow-empty -m "Version ' + version + '"') )
    .pipe( exec('git tag ' + tag + ' --file .changes') )
    .pipe( exec('git push origin ' + tag) )
    .pipe( exec('git push origin master') );
}


// gulp build -> compile coffee script
exports.build = gulp.series(clean, build, lint);
// gulp clean -> clean generated files
exports.clean = clean;
// gulp lint -> errors if code dirty
exports.lint = lint;
// gulp watch -> watch for changes and compile
exports.watch = gulp.series(build, watch);
// gulp tag -> Tag this release
exports.tag = gulp.series(changes, tag);
// gulp -> gulp watch
exports.default = exports.watch;

