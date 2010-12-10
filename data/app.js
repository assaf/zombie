Sammy("body", function(app) {
  app.get("#/", function(context) {
    context.swap("The Living");
  });
  app.get("#/dead", function(context) {
    context.swap("The Living Dead");
  });
});
$(function() { Sammy("body").run("#/") });
