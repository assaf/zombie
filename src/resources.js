// History of resources loaded by window.

const Fetch = require('./fetch');


// Each resource is associated with request, and on completion response or error.
class Resource {

  constructor({ request }) {
    this.request  = request;
    this.error    = null;
    this.response = null;
  }

  // The URL of this resource
  get url() {
    return (this.response && this.response.url) || this.request.url;
  }

  // Dump the resource to output stream/stdout
  dump(output = process.stdout) {
    const { request, response, error } = this;
    // Write summary request/response header
    if (response) {
      const elapsed = response.time - request.time;
      output.write(`${request.method} ${this.url} - ${response.status} ${response.statusText} - ${elapsed}ms\n`);
    } else
      output.write(`${request.method} ${this.url}\n`);

    // If response, write out response headers and sample of document entity
    // If error, write out the error message
    // Otherwise, indicate this is a pending request
    if (response) {
      if (response._redirectCount)
        output.write(`  Followed ${response._redirectCount} redirects\n`);
      for (let [name, value] of response.headers)
        output.write(`  ${name}: ${value}\n`);
      output.write('\n');
      const sample = response.body
        .slice(0, 250)
        .toString('utf8')
        .split('\n')
        .map(line => `  ${line}`)
        .join('\n');
      output.write(sample);
    } else if (error)
      output.write(`  Error: ${error.message}\n`);
    else
      output.write(`  Pending since ${new Date(request.time)}\n`);
    // Keep them separated
    output.write('\n\n');
  }

}


// Each window has a resources object that provides the means for retrieving
// resources and a list of all retrieved resources.
//
// The object is an array, and its elements are the resources.
class Resources extends Array {

  constructor(window) {
    super();
    this._browser = window.browser;
  }


  _fetch(input, init) {
    const pipeline  = this._browser.pipeline;
    const request   = new Fetch.Request(input, init);
    const resource  = new Resource({ request });
    this.push(resource);

    return pipeline
      ._fetch(request)
      .then(function(response) {
        resource.response = response;
        return response;
      })
      .catch(function(error) {
        resource.error    = error;
        resource.response = Fetch.Response.error();
        throw error;
      });
  }


  // Human readable resource listing.
  //
  // output - Write to this stream (optional)
  dump(output = process.stdout) {
    if (this.length === 0)
      output.write('No resources\n');
    else
      this.forEach(resource => resource.dump(output));
  }

}



module.exports = Resources;

