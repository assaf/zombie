const assert      = require('assert');
const Browser     = require('../src/zombie');
const { brains }  = require('./helpers');


describe.skip("angularjs", function() {
  let browser;

  before(function*() {
    browser = Browser.create();
    yield (resume)=> brains.ready(resume);

    brains.get("/angular/show.html", function(req, res) {
      res.send("<h1>{{title}}</h1>");
    });

    brains.get("/angular/list.html", function(req, res) {
      res.send("\
      <ul>\
          <li ng-repeat='item in items'>\
              <a href='#/show'>{{item.text}}</span>\
          </li>\
      </ul>\
      ");
    });

    brains.get("/angular", function(req, res) {
      res.send("\
      <html ng-app='test'>\
        <head>\
          <title>Angular</title>\
          <script src='/scripts/angular-1.0.6.js'></script>\
        </head>\
        <body>\
          <div ng-view></div>\
          <script>\
            angular.module('test', []).\
              config(['$routeProvider', function($routeProvider) {\
                $routeProvider.\
                  when('/show', {templateUrl: '/angular/show.html', controller: ShowCtrl}).\
                  when('/list', {templateUrl: '/angular/list.html', controller: ListCtrl}).\
                  otherwise({redirectTo: '/list'});\
            }]);\
            function ListCtrl($scope) {\
              $scope.items = [{text:'my link'}];\
            }\
            function ShowCtrl($scope) {\
              $scope.title = 'my title';\
            }\
          </script>\
        </body>\
      </html>\
      ");
    });

    yield browser.visit('/angular');
    browser.clickLink("my link");
    yield browser.wait({ duration: 100 });
  });

  it("should follow the link to the detail", function() {
    browser.assert.text('h1', "my title");
  });

  after(function() {
    browser.destroy();
  });

});

