// Exports a method for serializing the DOM.  This can be used to store the
// state of the DOM for comparison, e.g. to detect changes in rendering.
//
// The method operates on an element or document, and serializes all elements,
// their attributes, computed styles, and text nodes.  Comments, processing
// instructions and CDATA sections are not serialized.
//
// Computed stylesheets are based on any style attribute and any applied styles.
// You must instruct Zombie to load external stylesheets if you want those
// styles included.
//
// If you need to ignore certain elements or attributes, this method takes a
// second function that is called with the node and should return true for every
// node that needs to be ignored.  For example, often ID attributes are based on
// database IDs that change from one run to the other, you can ignore them with
// a function like this:
//
//   function ignoreIDAttributes(node) {
//     return node.nodeType === 2 && node.name == 'id';
//   });


function serializeAttributes(element, ignore) {
  const attributes = [...element.attributes]
    .filter(node => !ignore(node))
    .sort((a, b)=> a.name.localeCompare(b.name));
  if (attributes.length) {
    return attributes.reduce((map, attr)=> {
      map[attr.name] = attr.value;
      return map;
    }, {});
  }
}


function serializeStyles(element) {
  const window    = element.ownerDocument.parentWindow;
  const computed  = window.getComputedStyle(element);
  const names     = [...computed].sort();
  if (names.length) {
    return names.reduce((map, name)=> {
      map[name] = computed[name];
      return map;
    }, {});
  }
}


function serializeChildNodes(element, ignore) {
  const childNodes = [...element.childNodes]
    .map(node => serializeNode(node, ignore))
    .filter(node => node);
  if (childNodes.length)
    return childNodes;
}


function serializeElement(element, ignore) {
  return {
    name:       element.nodeName,
    attributes: serializeAttributes(element, ignore),
    styles:     serializeStyles(element),
    childNodes: serializeChildNodes(element, ignore)
  };
}


function serializeNode(node, ignore) {
  if (ignore(node))
    return;

  switch (node.nodeType) {
    case 1: // ELEMENT_NODE:
      return serializeElement(node, ignore);
    case 3: // TEXT_NODE
      return { text: node.nodeValue };
  }
}


module.exports = function serializeDOM(element, ignore = function() { }) {
  return serializeNode(element.documentElement || element, ignore);
};

