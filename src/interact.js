module.exports = class Interaction {

  constructor(browser) {
    this._browser       = browser;
    // Collects all prompts (alert, confirm, prompt).
    this._prompts       = [];
    this._alertFns      = [];
    this._confirmFns    = [];
    this._confirmCanned = {};
    this._promptFns     = [];
    this._promptCanned  = {};
  }

  // When alert displayed to user, call this function.
  onalert(fn) {
    this._alertFns.push(fn);
  }

  // When prompted with a question, return the response. First argument
  // may be a function.
  onconfirm(question, response) {
    if (typeof question === 'function')
      this._confirmFns.push(question);
    else
      this._confirmCanned[question] = !!response;
  }

  // When prompted with message, return response or null if response is
  // false. First argument may be a function.
  onprompt(message, response) {
    if (typeof message === 'function')
      this._promptFns.push(message);
    else
      this._promptCanned[message] = response;
  }

  prompted(message) {
    return this._prompts.indexOf(message) >= 0;
  }

  extend(window) {
    // Implements window.alert: show message.
    window.alert = (message)=> {
      this._browser.emit('alert', message);
      this._prompts.push(message);
      for (let fn of this._alertFns)
        fn(message);
    };

    // Implements window.confirm: show question and return true/false.
    window.confirm = (question)=> {
      this._browser.emit('confirm', question);
      this._prompts.push(question);
      let response = this._confirmCanned[question];
      if (!(response || response === false)) {
        for (let fn of this._confirmFns) {
          response = fn(question);
          if (response || response === false)
            break;
        }
      }
      return !!response;
    };

    // Implements window.prompt: show message and return value of null.
    window.prompt = (message, defaultValue)=> {
      this._browser.emit('prompt', message);
      this._prompts.push(message);
      let response = this._promptCanned[message];
      if (!(response || response === false)) {
        for (let fn of this._promptFns) {
          response = fn(message, defaultValue);
          if (response || response === false)
            break;
        }
      }
      return response ?  response.toString() :
             (response === false) ? null :
             (defaultValue || '');
    };
  }

}
