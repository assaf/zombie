function pageReady() {
  var staticLinks = [
    ["Github",        "https://github.com/assaf/zombie"],
    ["Google Group",  "https://groups.google.com/forum/?hl=en#!forum/zombie-js"],
    ["Contributing",  "https://github.com/assaf/zombie/blob/master/CONTRIBUTING.md"],
    ["PDF",           "zombie.pdf"],
    ["Kindle",        "zombie.mobi"]
  ];

  var navigationBar = document.getElementById("navigation-bar");
  var navigationLinks = navigationBar.querySelector("ul");
  var expandNavigationLink = navigationBar.querySelector(".expand");


  // Returns a CSS style object from the page's stylesheet for the given
  // selector.
  function getStyleFromStylesheet(selector) {
    var cssRules = document.styleSheets[0].cssRules;
    if (cssRules) {
      for (var i = 0; i < cssRules.length; ++i) {
        var cssRule = cssRules[i];
        if (cssRule.selectorText == selector)
          return cssRule.style;
      }
    }
    return cssRule.style;
  }


  // Adds a navigation link to the navigation bar.  Obviously at the very end.
  function addLinkToNavigationLinks(linkText, linkURL, alwaysShown) {
    var a = document.createElement("a");
    a.textContent = linkText;
    a.href = linkURL;
    var li = document.createElement("li");
    li.appendChild(a);
    if (alwaysShown)
      li.setAttribute("class", "always-shown");
    navigationLinks.appendChild(li);
  }


  // Creates navigation links inside the navigation bar by scanning the document
  // content for H2 headers and adding the static links listed above.  That way
  // we don't have to update a link list.
  //
  // Oh, and it also assigns each H2 header an ID so we can link directly to it
  // from anywhere in the document.
  function populateNavigationLinks() {
    // Add table of contents to navigation links
    var headers = document.getElementsByTagName("h2");
    for (var i = 0; i < headers.length; ++i) {
      var header = headers[i];
      header.id = header.textContent.replace(/\s+/, "_").toLowerCase();
      addLinkToNavigationLinks(header.textContent, "#" + header.id);
    }

    // Add static links to navigation links
    staticLinks.forEach(function(staticLink) {
      addLinkToNavigationLinks(staticLink[0], staticLink[1], true);
    });

    // Determine fix width for these links
    var linkWidths = Array.prototype.slice.call(navigationLinks.querySelectorAll("li")).map(function(li) { 
        return li.clientWidth;
      });
    var maxLinkWidth = Math.max.apply(null, linkWidths) + "px";
    getStyleFromStylesheet("#navigation-bar li").width = maxLinkWidth;
  }


  // Determine the height of the navigation bar and set the appropriate CSS
  // style.
  //
  // We need to know the exact height in pixels so we can update the CSS rule in
  // the stylesheet.  With it, we get smooth animations as the navigation bar
  // expands and contracts. Without it, we get a junky transition that no one
  // deserves to experience.
  //
  // The exact height determines on the screen size, font size and so
  // forth, so we need to adjust this periodically (e.g. every time screen gets
  // resized). 
  function setNavigationBarHeight() {
    getStyleFromStylesheet("#navigation-bar.expanded").height = navigationLinks.clientHeight + "px";
  }
  window.addEventListener("resize", setNavigationBarHeight);


  // Navigation bar contains an "expand me" link, clicking on it expands and
  // contracts the navigation bar.  This works differently in different
  // browsers, but all handled by CSS magic.
  expandNavigationLink.addEventListener("click", function(event) {
    if (navigationBar.className == "contracted")
      navigationBar.className = "expanded";
    else
      navigationBar.className = "contracted";
    event.stopPropagation();
    event.preventDefault();
    setNavigationBarHeight();
  });
  // Clicking anywhere else on the page, including navigation link, closes the
  // navigation bar.
  document.addEventListener("click", function(event) {
    navigationBar.className = "contracted";
  });


  // Scroll page to the header given by its ID.
  //
  // The navigation bar obscures the top of the page, so we use this to scroll
  // the page to just above the header, so the header shows in full.  Used when
  // clicking on a navigation link or reloading the page.
  function scrollToHeader(id) {
    // This has to happen outside the main event.
    setTimeout(function() {
      var header = document.getElementById(id);
      if (header)
        scrollTo(0, header.offsetTop - 48);
    });
  }
  // Scroll page to the header in the URL document fragment.
  scrollToHeader(document.location.hash.slice(1));
  // Close navigation bar and scroll to header when clicking on navigation link.
  navigationLinks.addEventListener("click", function(event) {
    navigationBar.className = "contracted";
  });
  window.addEventListener("hashchange", function(event) {
    scrollToHeader(document.location.hash.slice(1));
  });


  // Populate navigation bar with links, we need to do this before we can
  // calculate the expanded height navigation bar, which we need in order to set
  // the CSS styles for a smooth animation.  Don't we all like smooth
  // animations?
  populateNavigationLinks();
  setNavigationBarHeight();
  navigationBar.style.visibility = "visible";
}


// Wait for page content to load, if not already loaded.
if (document.readyState == "loading")
  document.addEventListener("DOMContentLoaded", pageReady);
else
  pageReady();
