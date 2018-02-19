// Patches to JSDOM for properly handling forms.
const DOM   = require('./index');
const File  = require('fs');
const Mime  = require('mime');
const Path  = require('path');
const { idlUtils, domSymbolTree, HTMLInputElementImpl }    = require('./impl');


// The Form
// --------

// Forms convert INPUT fields of type file into this object and pass it as
// parameter to resource request.
//
// The base class is a String, so the value (e.g. when passed in a GET request)
// is the base filename.  Additional properties include the MIME type (`mime`),
// the full filename (`filename`) and the `read` method that returns the file
// contents.
function uploadedFile(filename) {
  const file = {
    valueOf() {
      return Path.basename(filename);
    }
  };
  file.filename = filename;
  file.mime     = Mime.lookup(filename);
  file.read     = function() {
    return File.readFileSync(filename);
  };
  return file;
}


// Implement form.submit such that it actually submits a request to the server.
// This method takes the submitting button so we can send the button name/value.
DOM.HTMLFormElement.prototype.submit = function(button) {
  const form      = this;
  const document  = form.ownerDocument;
  const params    = new Map();

  function addFieldValues(fieldName, values) {
    const current = (params.get(fieldName) || []);
    const next    = current.concat(values);
    params.set(fieldName, next);
  }

  function addFieldToParams(field) {
    if (field.getAttribute('disabled'))
      return;

    const name = field.getAttribute('name');
    if (!name)
      return;

    if (field.nodeName === 'SELECT') {
      const selected = Array.from(field.options)
        .filter(option  => option.selected)
        .map(options    => options.value);

      if (field.multiple)
        addFieldValues(name, selected);
      else {
        const value = (selected.length > 0) ?
          selected[0] :
          (field.options.length && field.options[0].value);
        addFieldValues(name, [ value ]);
      }
      return;
    }

    if (field.nodeName === 'INPUT' && (field.type === 'checkbox' || field.type === 'radio')) {
      if (field.checked) {
        const value   = field.value || '1';
        addFieldValues(name, [ value ]);
      }
      return;
    }

    if (field.nodeName === 'INPUT' && field.type === 'file') {
      if (field.value) {
        const value   = uploadedFile(field.value);
        addFieldValues(name, [ value ]);
      }
      return;
    }

    if (field.nodeName === 'TEXTAREA' || field.nodeName === 'INPUT') {
      if (field.type !== 'submit' && field.type !== 'image')
        addFieldValues(name, [ field.value ]);
      return;
    }
  }

  function addButtonToParams() {
    if (button.nodeName === 'INPUT' && button.type === 'image') {
      addFieldValues(button.name + '.x', [ '0' ]);
      addFieldValues(button.name + '.y', [ '0' ]);

      if (button.value)
        addFieldValues(button.name, [ button.value ]);
    } else
      addFieldValues(button.name, [ button.value ]);
  }

  function submit() {
    if (button && button.name)
      addButtonToParams();

    // Ask window to submit form, let it figure out how to handle this based on
    // the target attribute.
    document.defaultView._submit({
      url:      form.getAttribute('action') || document.location.href,
      method:   form.getAttribute('method') || 'GET',
      encoding: form.getAttribute('enctype'),
      params:   params,
      target:   form.getAttribute('target')
    });
  }

  function process(index) {
    const field = form.elements.item(index);
    if (!field) {
      submit();
      return;
    }
    addFieldToParams(field);
    process(index + 1);
  }

  process(0);
};

// override input.checked being set in jsdom, we set in manually in zombie
HTMLInputElementImpl.implementation.prototype._preClickActivationSteps = function(){};




// Replace dispatchEvent so we can send the button along the event.
DOM.HTMLFormElement.prototype._dispatchSubmitEvent = function(button) {
  const event = this.ownerDocument.createEvent('HTMLEvents');
  event.initEvent('submit', true, true);
  event._button = button;
  const inputElementImpl = idlUtils.implForWrapper(event._button);
  const bodyElementImpl = domSymbolTree.parent(domSymbolTree.parent(inputElementImpl));
  bodyElementImpl.addEventListener('submit', _submit, {once: true})
  return this.dispatchEvent(event);
};


// Default behavior for submit events is to call the form's submit method, but we
// also pass the submitting button.
// DEBUG DOM.HTMLFormElement.prototype._eventDefaults.submit = function(event) {
DOM.HTMLFormElement.prototype._submit = function(event) {
  event.target.submit(event._button);
};


// Buttons
// -------

// Current INPUT behavior on click is to capture sumbit and handle it, but
// ignore all other clicks. We need those other clicks to occur, so we're going
// to dispatch them all.
DOM.HTMLInputElement.prototype.click = function() {
  const input = this;
  input.focus();

  // First event we fire is click event
  function click() {
    const clickEvent = input.ownerDocument.createEvent('HTMLEvents');
    clickEvent.initEvent('click', true, true);
    const labelElementImpl = domSymbolTree.parent(idlUtils.implForWrapper(input));
    labelElementImpl.addEventListener('click', input._click, {})
    return input.dispatchEvent(clickEvent);
  }

  switch (input.type) {
    case 'checkbox': {
      if (input.getAttribute('readonly'))
        break;

      const original    = input.checked;
      input.checked     = !original;
      const checkResult = click();
      if (checkResult === false)
        input.checked = original;
      break;
    }

    case 'radio': {
      if (input.getAttribute('readonly'))
        break;

      if (input.checked)
        click();
      else {
        const radios = input.ownerDocument.querySelectorAll(`input[type=radio][name='${this.getAttribute('name')}']`);
        const checked = Array.from(radios)
          .filter(radio   => radio.checked && radio.form === this.form )
          .map(radio  => {
            radio.checked = false;
          })[0];

        input.checked = true;
        const radioResult = click();
        if (radioResult === false) {
          input.checked = false;
          Array.from(radios)
            .filter(radio   => radio.form === input.form )
            .forEach(radio  => {
              radio.checked = (radio === checked);
            });
        }
      }
      break;
    }

    default: {
      click();
      break;
    }
  }
};


// HTMLForm listeners
DOM.HTMLButtonElement.prototype._click = function(event) {
  const button = event.target;
  if (button.getAttribute('disabled'))
    return false;

  const form = button.form;
  if (form)
    return form._dispatchSubmitEvent(button);
};

DOM.HTMLInputElement.prototype._click = function(event) {
  if (event.defaultPrevented) return;

  const input = event.target;

  function change() {
    const changeEvent = input.ownerDocument.createEvent('HTMLEvents');
    changeEvent.initEvent('change', true, true);
    input.dispatchEvent(changeEvent);
  }

  switch (input.type) {
    case 'reset': {
      if (input.form)
        input.form.reset();
      break;
    }
    case 'submit': {
      if (input.form)
        input.form._dispatchSubmitEvent(input);
      break;
    }
    case 'image': {
      if (input.form)
        input.form._dispatchSubmitEvent(input);
      break;
    }
    case 'checkbox': {
      change();
      break;
    }
    case 'radio': {
      if (!input.getAttribute('readonly')) {
        input.checked = true;
        change();
      }
    }
  }
};

const _submit = function(event) {
  event.target.submit(event._button);
};
