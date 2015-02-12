const Browser     = require('../src');
const { brains }  = require('./helpers');


describe.skip('angularjs', function() {
  const browser = new Browser();

  before(async function() {
    await brains.ready();

    brains.static('/angular/show.html', '<h1>{{title}}</h1>');

    brains.static('/angular/list.html', `
      <ul>
          <li ng-repeat='item in items'>
              <a href='#/show'>{{item.text}}</span>
          </li>
      </ul>
    `);

    brains.static('/angular', `
      <html ng-app='test'>
        <head>
          <title>Angular</title>
          <script src='/scripts/angular-1.3.0.js'></script>
        </head>
        <body>
          <div ng-view></div>
          <script>
            angular.module('test', []).
              config(['$routeProvider', function($routeProvider) {
                $routeProvider.
                  when('/show', {templateUrl: '/angular/show.html', controller: ShowCtrl}).
                  when('/list', {templateUrl: '/angular/list.html', controller: ListCtrl}).
                  otherwise({redirectTo: '/list'});
            }]);
            function ListCtrl($scope) {
              $scope.items = [{text:'my link'}];
            }
            function ShowCtrl($scope) {
              $scope.title = 'my title';
            }
          </script>
        </body>
      </html>
    `);

    await browser.visit('/angular');
    browser.clickLink('my link');
    await browser.wait({ duration: 100 });
  });

  it('should follow the link to the detail', function() {
    browser.assert.text('h1', 'my title');
  });

  after(function() {
    browser.destroy();
  });

});

