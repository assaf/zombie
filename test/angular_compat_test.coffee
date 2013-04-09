{ assert, brains, Browser } = require("./helpers")


describe.skip "angularjs", ->
  browser = null
  before (done)->
    browser = Browser.create()
    brains.ready(done)

  before ->
    brains.get "/angular/show.html", (req, res)->
      res.send """
      <h1>{{title}}</h1>
      """

    brains.get "/angular/list.html", (req, res)->
      res.send """
      <ul>
          <li ng-repeat="item in items">
              <a href="#/show">{{item.text}}</span>
          </li>
      </ul>
      """

    brains.get "/angular", (req, res)->
      res.send """
      <html ng-app="test">
        <head>
          <title>Angular</title>
          <script src="/scripts/angular-1.0.2.js"></script>
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
              $scope.items = [{text:"my link"}];
            }
            function ShowCtrl($scope) {
              $scope.title = "my title";
            }
          </script>
        </body>
      </html>
      """


  before (done)->
    browser.visit "/angular", ->
      browser.clickLink("my link")
      browser.wait(duration: 100, done)

  it "should follow the link to the detail", ->
    assert.equal browser.text("h1"), "my title"

  after ->
    browser.destroy()
