const assert      = require('assert');
const Browser     = require('../src/zombie');
const { brains }  = require('./helpers');
const File        = require('fs')
const Crypto      = require('crypto');


describe('Forms', function() {
  let browser;

  before(function() {
    browser = Browser.create();
    return brains.ready();
  });


  before(function() {
    brains.static('/forms/form', `
      <html>
        <body>
          <form action="/forms/submit" method="post">
            <label>Name <input type="text" name="name" id="field-name" /></label>
            <label for="field-email">Email</label>
            <input type="text" name="email" id="field-email"></label>
            <textarea name="likes" id="field-likes">Warm brains</textarea>
            <input type="password" name="password" id="field-password">
            <input type="badtype" name="invalidtype" id="field-invalidtype">
            <input type="text" name="email2" id="field-email2">
            <input type="text" name="email3" id="field-email3">
            <input type="text" name="disabled" disabled>
            <input type="text" name="readonly" readonly>
            <input type="text" name="empty_text" id="empty-text">

            <label>Hungry</label>
            <label>You bet<input type="checkbox" name="hungry[]" value="you bet" id="field-hungry"></label>
            <label>Certainly<input type="checkbox" name="hungry[]" value="certainly" id="field-hungry-certainly"></label>

            <label for="field-brains">Brains?</label>
            <input type="checkbox" name="brains" value="yes" id="field-brains">
            <input type="checkbox" name="green" id="field-green" value="Super green!" checked="checked">
            <input type="checkbox" name="check" id="field-check" value="Huh?" checked="checked">
            <input type="checkbox" name="uncheck" id="field-uncheck" value="Yeah!">
            <input type="checkbox" name="empty_checkbox" id="empty-checkbox" checked="checked">

            <label>Looks
              <select name="looks" id="field-looks">
                <option value="blood" label="Bloody"></option>
                <option value="clean" label="Clean"></option>
                <option value=""      label="Choose one"></option>
              </select>
            </label>
            <label>Scary <input name="scary" type="radio" value="yes" id="field-scary"></label>
            <label>Not scary <input name="scary" type="radio" value="no" id="field-notscary" checked="checked"></label>

            <select name="state" id="field-state">
              <option>alive</option>
              <option>dead</option>
              <option>neither</option>
            </select>

            <span>First address</span>
            <label for='address1_street'>Street</label>
            <input type="text" name="addresses[][street]" value="" id="address1_street">

            <label for='address1_city'>City</label>
            <input type="text" name="addresses[][city]" value="" id="address1_city">

            <span>Second address</span>
            <label for='address2_street'>Street</label>
            <input type="text" name="addresses[][street]" value="" id="address2_street">

            <label for='address2_city'>City</label>
            <input type="text" name="addresses[][city]" value="" id="address2_city">

            <select name="kills" id="field-kills">
              <option>Five</option>
              <option>Seventeen</option>
              <option id="option-killed-thousands">Thousands</option>
            </select>

            <select name="unselected_state" id="field-unselected-state">
              <option>alive</option>
              <option>dead</option>
            </select>

            <select name="hobbies[]" id="field-hobbies" multiple="multiple">
              <option>Eat Brains</option>
              <option id="hobbies-messy">Make Messy</option>
              <option>Sleep</option>
            </select>

            <select name="months" id="field-months">
              <option value=""></option>
              <option value="jan_2011"> Jan 2011 </option>
              <option value="feb_2011"> Feb 2011 </option>
              <option value="mar_2011"> Mar 2011 </option>
            </select>

            <input type="unknown" name="unknown" value="yes">
            <input type="reset" value="Reset">
            <input type="submit" name="button" value="Submit">
            <input type="image" name="image" id="image_submit" value="Image Submit">

            <button name="button" value="hit-me">Hit Me</button>

            <input type="checkbox" id="field-prevent-check">
            <input type="radio" id="field-prevent-radio">
            <input type="radio" name="radio_reused_name" id="field-radio-first-form" />
          </form>
          <div id="formless_inputs">
            <label>Hunter <input type="text" name="hunter_name" id="hunter-name"></label>
            <textarea name="hunter_hobbies">Killing zombies.</textarea>
            <input type="password" name="hunter_password" id="hunter-password">
            <input type="badtype" name="hunter_invalidtype" id="hunter-invalidtype" />
            <label>Weapons</label>
            <label>Chainsaw<input type="checkbox" name="hunter_weapon[]" value="chainsaw"></label>
            <label>Shotgun<input type="checkbox" name="hunter_weapon[]" value="shotgun"></label>
            <label>Type
              <select name="hunter_type">
                <option value="regular" label="Regular"></option>
                <option value="evil" label="Evil"></option>
                <option value="tiny" label="tiny"></option>
              </select>
            </label>
            <label>Powerglove <input name="hunter_powerglove" type="radio" value="glove"></label>
            <label>No powerglove <input name="hunter_powerglove" type="radio" value="noglove" checked="checked"></label>
          </div>
          <form>
            <input type="radio" name="radio_reused_name" id="field-radio-second-form" checked="checked" />
          </form>
        </body>
      </html>
    `);

    brains.post('/forms/submit', function(req, res) {
      res.send(`
        <html>
          <title>Results</title>
          <body>
            <div id="name">${req.body.name}</div>
            <div id="likes">${req.body.likes}</div>
            <div id="green">${req.body.green}</div>
            <div id="brains">${req.body.brains}</div>
            <div id="looks">${req.body.looks}</div>
            <div id="hungry">${JSON.stringify(req.body.hungry)}</div>
            <div id="scary">${req.body.scary}</div>
            <div id="state">${req.body.state}</div>
            <div id="empty-text">${req.body.empty_text}</div>
            <div id="empty-checkbox">${req.body.empty_checkbox || "nothing"}</div>
            <div id="unselected_state">${req.body.unselected_state}</div>
            <div id="hobbies">${JSON.stringify(req.body.hobbies)}</div>
            <div id="addresses">${JSON.stringify(req.body.addresses)}</div>
            <div id="unknown">${req.body.unknown}</div>
            <div id="clicked">${req.body.button}</div>
            <div id="image_clicked">${req.body.image}</div>
          </body>
        </html>
      `);
    });
  });


  describe('fill field', function() {
    let changed = null;

    before(async function() {
      await browser.visit('/forms/form');

      const fillEvents = ['input', 'change'];
      let remaining = fillEvents.length;
      browser.on('event', function(event, target) {
        if (~fillEvents.indexOf(event.type)) {
          remaining = remaining - 1;
          if (remaining === 0) {
            changed = target;
            remaining = fillEvents.length;
          }
        }
      });
    });

    describe('fill input with same the same value', function() {
      before(function() {
        browser.fill('Name', '');
      });

      it('should not fire input *and* change events', function() {
        assert.equal(changed, null);
      });
    });

    describe('text input enclosed in label', function() {
      before(function() {
        browser.fill('Name', 'ArmBiter');
      });

      it('should set text field', function() {
        browser.assert.input('#field-name', 'ArmBiter');
      });
      it('should fire input and changed event', function() {
        assert.equal(changed.id, 'field-name');
      });
    });

    describe('email input referenced from label', function() {
      before(function() {
        browser.fill('Email', 'armbiter@example.com');
      });

      it('should set email field', function() {
        browser.assert.input('#field-email', 'armbiter@example.com');
      });
      it('should fire input and change events', function() {
        assert.equal(changed.id, 'field-email');
      });
    });

    describe('textarea by field name', function() {
      before(function() {
        browser.fill('likes', 'Arm Biting');
      });

      it('should set textarea', function() {
        browser.assert.input('#field-likes', 'Arm Biting');
      });
      it('should fire input and change events', function() {
        assert.equal(changed.id, 'field-likes');
      });
    });

    describe('password input by selector', function() {
      before(function() {
        browser.fill('input[name=password]', 'b100d');
      });

      it('should set password', function() {
        browser.assert.input('#field-password', 'b100d');
      });
      it('should fire input and change events', function() {
        assert.equal(changed.id, 'field-password');
      });
    });

    describe('input without a valid type', function() {
      before(function() {
        browser.fill('input[name=invalidtype]', 'some value');
      });

      it('should set value', function() {
        browser.assert.input('#field-invalidtype', 'some value');
      });
      it('should fire input and change events', function() {
        assert.equal(changed.id, 'field-invalidtype');
      });
    });

    describe('email2 input by node', function() {
      before(function() {
        browser.fill('#field-email2', 'headchomper@example.com');
      });

      it('should set email2 field', function() {
        browser.assert.input('#field-email2', 'headchomper@example.com');
      });
      it('should fire input and change events', function() {
        assert.equal(changed.id, 'field-email2');
      });
    });

    describe('disabled input can not be modified', function() {
      it('should raise error', function() {
        assert.throws(function() {
          browser.fill('#disabled_input_field', 'yeahh');
        });
      });
    });

    describe('readonly input can not be modified', function() {
      it('should raise error', function() {
        assert.throws(function() {
          browser.fill('#readonly_input_field', 'yeahh');
        });
      });
    });

    describe('focus field (1)', function() {
      before(function() {
        return browser.visit('/forms/form');
      });
      before(function(done) {
        const field1 = browser.querySelector('#field-email2');
        const field2 = browser.querySelector('#field-email3');
        browser.fill(field1, 'something');
        field2.addEventListener('focus', ()=> done());
        browser.fill(field2, 'else');
      });

      it('should fire focus event on selected field', function() {
        assert(true);
      });
    });

    describe('focus field (2)', function() {
      before(function() {
        return browser.visit('/forms/form');
      });
      before(function(done) {
        const field1 = browser.querySelector('#field-email2');
        const field2 = browser.querySelector('#field-email3');
        browser.fill(field1, 'something');
        field2.addEventListener('blur', ()=> done());
        browser.fill(field2, 'else');
      });

      it('should fire blur event on previous field', function() {
        assert(true);
      });
    });

    describe('keep value and switch focus', function() {
      before(function() {
        return browser.visit('/forms/form');
      });
      before(function(done) {
        const field1 = browser.querySelector('#field-email2');
        const field2 = browser.querySelector('#field-email3');
        field1.addEventListener('change', function() {
          done(new Error('Should not fire'));
        });
        browser.focus(field1);
        browser.focus(field2);
        setImmediate(done);
      });

      it('should fire change event on previous field', function() {
        assert(true);
      });
    });

    describe('change value and switch focus', function() {
      before(function() {
        return browser.visit('/forms/form');
      });
      before(function(done) {
        const field1 = browser.querySelector('#field-email2');
        const field2 = browser.querySelector('#field-email3');
        field1.addEventListener('change', ()=> done());
        browser.focus(field1);
        field1.value = 'something';
        browser.focus(field2);
      });

      it('should fire change event on previous field', function() {
        assert(true);
      });
    });
  });


  describe('check box', function() {
    let changed = null;
    let clicked = null;

    before(async function() {
      await browser.visit('/forms/form');

      browser.on('event', function(event, target) {
        switch(event._type) {
          case 'change': {
            changed = target;
            break;
          }
          case 'click': {
            clicked = target
            break;
          }
        }
      });
    });

    describe('checkbox enclosed in label', function() {
      before(function() {
        browser.check('You bet');
      });

      it('should check checkbox', function() {
        browser.assert.element('#field-hungry:checked');
      });
      it('should fire change event', function() {
        assert.equal(changed.id, 'field-hungry');
      });
      it('should fire clicked event', function() {
        assert.equal(clicked.id, 'field-hungry');
      });
    });

    describe('checkbox referenced from label', function() {
      before(function() {
        browser.uncheck('Brains?');
        changed = null;
        clicked = null;
        browser.check('Brains?');
      });

      it('should check checkbox', function() {
        browser.assert.element('#field-brains:checked');
      });
      it('should fire change event', function() {
        assert.equal(changed.id, 'field-brains');
      });
    });

    describe('checkbox by name', function() {
      before(function() {
        browser.check('green');
        changed = null;
        clicked = null;
        browser.uncheck('green');
      });

      it('should uncheck checkbox', function() {
        browser.assert.elements('#field-green:checked', 0);
      });
      it('should fire change event', function() {
        assert.equal(changed.id, 'field-green');
      });
    });

    describe('prevent default', function() {
      const values = [];

      before(function() {
        const checkBox = browser.$$('#field-prevent-check');
        values.push(checkBox.checked);

        checkBox.addEventListener('click', function(event) {
          values.push(checkBox.checked);
          event.preventDefault();
        });
        browser.check(checkBox);
        values.push(checkBox.checked);
      });

      it('should turn checkbox on then off', function() {
        assert.deepEqual(values, [false, true, false]);
      });
    });

    describe('any checkbox (1)', function() {
      before(function() {
        return browser.visit('/forms/form');
      });
      before(function(done) {
        const field1 = browser.querySelector('#field-check');
        const field2 = browser.querySelector('#field-uncheck');
        browser.uncheck(field1);
        browser.check(field1);
        field2.addEventListener('focus', ()=> done());
        browser.check(field2);
      });

      it('should fire focus event on selected field', function() {
        assert(true);
      });
    });

    describe('any checkbox (2)', function() {
      before(function() {
        return browser.visit('/forms/form');
      });
      before(function(done) {
        const field1 = browser.querySelector('#field-check');
        const field2 = browser.querySelector('#field-uncheck');
        browser.uncheck(field1);
        browser.check(field1);
        field1.addEventListener('blur', ()=> done());
        browser.check(field2);
      });

      it('should fire blur event on previous field', function() {
        assert(true);
      });
    });
  });


  describe('radio buttons', function() {
    let changed = null;
    let clicked = null;

    before(async function() {
      await browser.visit('/forms/form');
      browser.on('event', function(event, target) {
        switch (event.type) {
          case 'change': {
            changed = target;
            break;
          }
          case 'click': {
            clicked = target;
            break;
          }
        }
      });
    });

    describe('radio button enclosed in label', function() {
      before(function() {
        browser.choose('Scary');
      });

      it('should check radio', function() {
        browser.assert.element('#field-scary:checked');
      });
      it('should fire click event', function() {
        assert.equal(clicked.id, 'field-scary');
      });
      it('should fire change event', function() {
        assert.equal(changed.id, 'field-scary');
      });
    });

    describe('radio button by value', function() {
      before(async function() {
        await browser.visit('/forms/form');
        browser.choose('no');
      });

      it('should check radio', function() {
        browser.assert.element('#field-notscary:checked');
      });
      it('should uncheck other radio', function() {
        browser.assert.elements('#field-scary:checked', 0);
      });
    });

    describe('prevent default', function() {
      const values = [];

      before(function() {
        const radio = browser.$$('#field-prevent-radio');
        values.push(radio.checked);

        radio.addEventListener('click', function(event) {
          values.push(radio.checked);
          event.preventDefault();
        });
        browser.choose(radio);
        values.push(radio.checked);
      });

      it('should turn radio on then off', function() {
        assert.deepEqual(values, [false, true, false]);
      });
    });

    describe('any radio button (1) ', function() {
      before(function(done) {
        const field1 = browser.querySelector('#field-scary');
        const field2 = browser.querySelector('#field-notscary');
        browser.choose(field1);
        field2.addEventListener('focus', ()=> done());
        browser.choose(field2);
      });

      it('should fire focus event on selected field', function() {
        assert(true);
      });
    });

    describe('any radio button (1) ', function() {
      before(function(done) {
        const field1 = browser.querySelector('#field-scary');
        const field2 = browser.querySelector('#field-notscary');
        browser.choose(field1);
        field1.addEventListener('blur', ()=> done());
        browser.choose(field2);
      });

      it('should fire blur event on previous field', function() {
        assert(true);
      });
    });

    describe('same radio name used in different forms', function() {
      before(function() {
        browser.choose('#field-radio-first-form');
      });

      it('should not uncheck radio in other forms', function() {
        browser.assert.element('#field-radio-second-form:checked');
      });
    });
  });


  describe('select option', function() {
    let changed = null;

    before(async function() {
      await browser.visit('/forms/form');
      browser.on('event', function(event, target) {
        if (event.type === 'change')
          changed = target;
      });
    });

    describe('enclosed in label using option label', function() {
      before(function() {
        browser.select('Looks', 'Bloody');
      });

      it('should set value', function() {
        browser.assert.input('#field-looks', 'blood');
      });
      it('should select first option', function() {
        const select      = browser.querySelector('#field-looks');
        const options     = Array.prototype.slice.call(select.options);
        const isSelected  = options.map((option)=> !!option.getAttribute('selected'));
        assert.deepEqual(isSelected, [true, false, false]);
      });
      it('should fire change event', function() {
        assert.equal(changed.id, 'field-looks');
      });
    });

    describe('select name using option value', function() {
      before(function() {
        browser.select('state', 'dead');
      });

      it('should set value', function() {
        browser.assert.input('#field-state', 'dead');
      });
      it('should select second option', function() {
        const select      = browser.querySelector('#field-state');
        const options     = Array.prototype.slice.call(select.options);
        const isSelected  = options.map((option)=> !!option.getAttribute('selected'));
        assert.deepEqual(isSelected, [false, true, false]);
      });
      it('should fire change event', function() {
        assert.equal(changed.id, 'field-state');
      });
    });

    describe('select name using option text', function() {
      before(function() {
        browser.select('months', 'Jan 2011');
      });

      it('should set value', function() {
        browser.assert.input('#field-months', 'jan_2011');
      });
      it('should select second option', function() {
        const select      = browser.querySelector('#field-months');
        const options     = Array.prototype.slice.call(select.options);
        const isSelected  = options.map((option)=> !!option.getAttribute('selected'));
        assert.deepEqual(isSelected, [false, true, false, false]);
      });
      it('should fire change event', function() {
        assert.equal(changed.id, 'field-months');
      });
    });

    describe('select option value directly', function() {
      before(function() {
        browser.selectOption('#option-killed-thousands');
      });

      it('should set value', function() {
        browser.assert.input('#field-kills', 'Thousands');
      });
      it('should select second option', function() {
        const select      = browser.querySelector('#field-kills');
        const options     = Array.prototype.slice.call(select.options);
        const isSelected  = options.map((option)=> !!option.getAttribute('selected'));
        assert.deepEqual(isSelected, [false, false, true]);
      });
      it('should fire change event', function() {
        assert.equal(changed.id, 'field-kills');
      });
    });

    describe('any selection (1)', function() {
      before(function() {
        return browser.visit('/forms/form');
      });
      before(function(done) {
        const field1 = browser.querySelector('#field-email2');
        const field2 = browser.querySelector('#field-kills');
        browser.fill(field1, 'something');
        field2.addEventListener('focus', ()=> done());
        browser.select(field2, 'Five');
      });

      it('should fire focus event on selected field', function() {
        assert(true);
      });
    });

    describe('any selection (2)', function() {
      before(function() {
        return browser.visit('/forms/form');
      });
      before(function(done) {
        const field1 = browser.querySelector('#field-email2');
        const field2 = browser.querySelector('#field-kills');
        browser.fill(field1, 'something');
        field1.addEventListener('blur', ()=> done());
        browser.select(field2, 'Five');
      });

      it('should fire blur event on previous field', function() {
        assert(true);
      });
    });
  });


  describe('multiple select option', function() {
    let changed = null;

    before(async function() {
      await browser.visit('/forms/form');
      browser.on('event', function(event, target) {
        if (event.type === 'change')
          changed = target;
      });

    });
    describe('select name using option value', function() {
      before(function() {
        browser.select('#field-hobbies', 'Eat Brains');
        browser.select('#field-hobbies', 'Sleep');
      });

      it('should select first and second options', function() {
        const select      = browser.querySelector('#field-hobbies');
        const options     = Array.prototype.slice.call(select.options);
        const isSelected  = options.map((option)=> !!option.getAttribute('selected'));
        assert.deepEqual(isSelected, [true, false, true]);
      });
      it('should fire change event', function() {
        assert.equal(changed.id, 'field-hobbies');
      });
      it('should not fire change event if nothing changed', function() {
        assert(changed);
        changed = null;
        browser.select('#field-hobbies', 'Eat Brains');
        assert(!changed);
      });
    });

    describe('unselect name using option value', function() {
      before(async function() {
        await browser.visit('/forms/form');
        browser.select('#field-hobbies', 'Eat Brains');
        browser.select('#field-hobbies', 'Sleep');
        browser.unselect('#field-hobbies', 'Sleep');
      });

      it('should unselect items', function() {
        const select      = browser.querySelector('#field-hobbies');
        const options     = Array.prototype.slice.call(select.options);
        const isSelected  = options.map((option)=> !!option.getAttribute('selected'));
        assert.deepEqual(isSelected, [true, false, false]);
      });
    });

	  describe('unselect name using option selector', function() {
      before(async function() {
        await browser.visit('/forms/form');
        browser.selectOption('#hobbies-messy');
        browser.unselectOption('#hobbies-messy');
      });

      it('should unselect items', function() {
        assert(!browser.query('#hobbies-messy').selected);
      });
    });

  });


  describe('fields not contained in a form', function() {
    before(function() {
      return browser.visit('/forms/form');
    });

    it('should not fail', function() {
      browser
        .fill('Hunter', 'Bruce')
        .fill('hunter_hobbies', 'Trying to get home')
        .fill('#hunter-password', 'klaatubarada')
        .fill('input[name=hunter_invalidtype]', 'necktie?')
        .check('Chainsaw')
        .choose('Powerglove')
        .select('Type', 'Evil');
    });
  });


  describe('reset form', function() {

    describe('by calling reset', function() {

      before(async function() {
        await browser.visit('/forms/form');
        browser
          .fill('Name', 'ArmBiter')
          .fill('likes', 'Arm Biting')
          .check('You bet')
          .choose('Scary')
          .select('state', 'dead');
        browser.querySelector('form').reset();
      });

      it('should reset input field to original value', function() {
        browser.assert.input('#field-name', '');
      });
      it('should reset textarea to original value', function() {
        browser.assert.input('#field-likes', 'Warm brains');
      });
      it('should reset checkbox to original value', function() {
        browser.assert.elements('#field-hungry:checked', 0);
      })
      it('should reset radio to original value', function() {
        browser.assert.elements('#field-scary:checked', 0);
        browser.assert.elements('#field-notscary:checked', 1);
      });
      it.skip('should reset select to original option', function() {
        browser.assert.input('#field-state', 'alive');
      });
    });

    describe('with event handler', function() {
      let eventType = null;

      before(function() {
        return browser.visit('/forms/form');
      });
      before(function(done) {
        browser.querySelector('form [type=reset]').addEventListener('click', function(event) {
          eventType = event.type
          done();
        });
        browser.querySelector('form [type=reset]').click();
      });

      it('should fire click event', function() {
        assert.equal(eventType, 'click');
      });
    });

    describe('with preventDefault', function() {
      before(function() {
        return browser.visit('/forms/form');
      });
      before(function(done) {
        browser.fill('Name', 'ArmBiter');
        browser.querySelector('form [type=reset]').addEventListener('click', function(event) {
          event.preventDefault();
          done();
        });
        browser.querySelector('form [type=reset]').click();
      });

      it('should not reset input field', function() {
        browser.assert.input('#field-name', 'ArmBiter');
      });
    });

    describe('by clicking reset input', function() {
      before(async function() {
        await browser.visit('/forms/form');
        browser.fill('Name', 'ArmBiter');
        browser.querySelector('form [type=reset]').click();
      });

      it('should reset input field to original value', function() {
        browser.assert.input('#field-name', '');
      });
    });
  });


  // Submitting form
  describe('submit form', function() {

    describe('by calling submit', function() {
      before(async function() {
        await browser.visit('/forms/form');
        browser
          .fill('Name', 'ArmBiter')
          .fill('likes', 'Arm Biting')
          .check('You bet')
          .check('Certainly')
          .choose('Scary')
          .select('state', 'dead')
          .select('looks', 'Choose one')
          .select('#field-hobbies', 'Eat Brains')
          .select('#field-hobbies', 'Sleep')
          .check('Brains?')
          .fill('#address1_city', 'Paris')
          .fill('#address1_street', 'CDG')
          .fill('#address2_city', 'Mikolaiv')
          .fill('#address2_street', 'PGS');
        browser.querySelector('form').submit();
        await browser.wait();
      });

      it('should open new page', function() {
        browser.assert.url('/forms/submit');
        browser.assert.text('title', 'Results');
      });
      it('should add location to history', function() {
        assert.equal(browser.window.history.length, 2);
      });
      it('should send text input values to server', function() {
        browser.assert.text('#name', 'ArmBiter');
      });
      it('should send textarea values to server', function() {
        browser.assert.text('#likes', 'Arm Biting');
      });
      it('should send radio button to server', function() {
        browser.assert.text('#scary', 'yes');
      });
      it('should send unknown types to server', function() {
        browser.assert.text('#unknown', 'yes');
      });
      it('should send checkbox with default value to server (brains)', function() {
        browser.assert.text('#brains', 'yes');
      });
      it('should send checkbox with default value to server (green)', function() {
        browser.assert.text('#green', 'Super green!');
      });
      it('should send multiple checkbox values to server', function() {
        browser.assert.text('#hungry', '["you bet","certainly"]');
      });
      it('should send selected option to server', function() {
        browser.assert.text('#state', 'dead');
      });
      it('should send first selected option if none was chosen to server', function() {
        browser.assert.text('#unselected_state', 'alive');
        browser.assert.text('#looks', '');
      });
      it('should send multiple selected options to server', function() {
        browser.assert.text('#hobbies', '["Eat Brains","Sleep"]');
      });
      it('should send empty text fields', function() {
        browser.assert.text('#empty-text', '');
      });
      it('should send checked field with no value', function() {
        browser.assert.text('#empty-checkbox', '1');
      });
    });


    describe('by clicking button', function() {
      before(async function() {
        await browser.visit('/forms/form');
        browser.fill('Name', 'ArmBiter');
        browser.fill('likes', 'Arm Biting');
        await browser.pressButton('Hit Me');
      });

      it('should open new page', function() {
        browser.assert.url('/forms/submit');
      });
      it('should add location to history', function() {
        assert.equal(browser.window.history.length, 2);
      });
      it('should send button value to server', function() {
        browser.assert.text('#clicked', 'hit-me');
      });
      it('should send input values to server', function() {
        browser.assert.text('#name', 'ArmBiter');
        browser.assert.text('#likes', 'Arm Biting');
      });
      it('should not send other button values to server', function() {
        browser.assert.text('#image_clicked', 'undefined');
      });
    });

    describe('pressButton(1)', function() {
      before(function() {
        return browser.visit('/forms/form');
      });
      before(function(done) {
        const field = browser.querySelector('#field-email2');
        browser.fill(field, 'something');
        browser.button('Hit Me').addEventListener('focus', ()=> done());
        browser.pressButton('Hit Me');
      });

      it('should fire focus event on button', function() {
        assert(true);
      });
    });

    describe('pressButton(2)', function() {
      before(function() {
        return browser.visit('/forms/form');
      });
      before(function(done) {
        const field = browser.querySelector('#field-email2');
        browser.fill(field, 'something');
        browser.button('Hit Me').addEventListener('blur', ()=> done());
        browser.pressButton('Hit Me');
      });

      it('should fire blur event on previous field', function() {
        assert(true);
      });
    });


    describe('by clicking image button', function() {
      before(async function() {
        await browser.visit('/forms/form');
        browser.fill('Name', 'ArmBiter');
        browser.fill('likes', 'Arm Biting');
        await browser.pressButton('#image_submit');
      });

      it('should open new page', function() {
        browser.assert.url('/forms/submit');
      });
      it('should add location to history', function() {
        assert.equal(browser.window.history.length, 2);
      });
      it('should send image value to server', function() {
        browser.assert.text('#image_clicked', 'Image Submit');
      });
      it('should send input values to server', function() {
        browser.assert.text('#name', 'ArmBiter');
        browser.assert.text('#likes', 'Arm Biting');
      });
      it('should not send other button values to server', function() {
        browser.assert.text('#clicked', 'undefined');
      });
    });

    describe('by clicking input', function() {
      before(async function() {
        await browser.visit('/forms/form');
        browser.fill('Name', 'ArmBiter');
        browser.fill('likes', 'Arm Biting');
        await browser.pressButton('Submit');
      });

      it('should open new page', function() {
        browser.assert.url('/forms/submit');
      });
      it('should add location to history', function() {
        assert.equal(browser.window.history.length, 2);
      });
      it('should send submit value to server', function() {
        browser.assert.text('#clicked', 'Submit');
      });
      it('should send input values to server', function() {
        browser.assert.text('#name', 'ArmBiter');
        browser.assert.text('#likes', 'Arm Biting');
      });
    });

    describe('cancel event', function() {
      before(async function() {
        brains.static('/forms/cancel', `
          <html>
            <head>
              <script src="/scripts/jquery.js"></script>
              <script>
                $(function() {
                  $("form").submit(function() {
                    return false;
                  })
                })
              </script>
            </head>
            <body>
              <form action="/forms/submit" method="post">
                <button>Submit</button>
              </form>
            </body>
          </html>
        `);

        await browser.visit('/forms/cancel');
        await browser.pressButton('Submit');
      });


      it('should not change page', function() {
        browser.assert.url('/forms/cancel');
      });
    });
  });


  // File upload
  describe('file upload', function() {
    before(function() {
    });
      brains.static('/forms/upload', `
        <html>
          <body>
            <form method="post" enctype="multipart/form-data">
              <input name="text" type="file">
              <input name="image" type="file">
              <button>Upload</button>
            </form>
          </body>
        </html>
      `);

      brains.post('/forms/upload', function(req, res) {
        if (req.files) {
          const [text, image] = [req.files.text, req.files.image];
          if (text || image) {
            const file = (text || image)[0];
            const data = File.readFileSync(file.path);
            const digest = image && Crypto.createHash('md5').update(data).digest('hex');
            res.send(`
              <html>
                <head><title>${file.originalFilename}</title></head>
                <body>${digest || data}</body>
              </html>
            `);
          }
        } else
          res.send('<html><body>nothing</body></html>');
      });


    describe('text', function() {
      before(async function() {
        await browser.visit('/forms/upload');
        const filename = `${__dirname}/data/random.txt`;
        browser.attach('text', filename);
        await browser.pressButton('Upload');
      });

      it('should upload file', function() {
        browser.assert.text('body', 'Random text');
      });
      it('should upload include name', function() {
        browser.assert.text('title', 'random.txt');
      });
    });


    describe('binary', function() {
      const filename = __dirname + '/data/zombie.jpg';

      before(async function() {
        await browser.visit('/forms/upload');
        browser.attach('image', filename);
        await browser.pressButton('Upload');
      });

      it('should upload include name', function() {
        browser.assert.text('title', 'zombie.jpg');
      });
      it('should upload file', function() {
        const digest = Crypto.createHash('md5').update(File.readFileSync(filename)).digest('hex');
        browser.assert.text('body', digest);
      });
    });


    describe('mixed', function() {
      before(async function() {
        brains.static('/forms/mixed', `
          <html>
            <body>
              <form method="post" enctype="multipart/form-data">
                <input name="username" type="text">
                <input name="logfile" type="file">
                <button>Save</button>
              </form>
            </body>
          </html>
        `);

        brains.post('/forms/mixed', function(req, res) {
          const file = req.files.logfile[0];
          const data = File.readFileSync(file.path);
          res.send(`
            <html>
              <head><title>${file.originalFilename}</title></head>
              <body>${data}</body>
            </html>
          `);
        });

        await browser.visit('/forms/mixed');
        browser.fill('username', 'hello');
        browser.attach('logfile', `${__dirname}/data/random.txt`);
        await browser.pressButton('Save');
      });

      it('should upload file', function() {
        browser.assert.text('body', 'Random text');
      });
      it('should upload include name', function() {
        browser.assert.text('title', 'random.txt');
      });
    });


    describe('empty', function() {
      before(async function() {
        await browser.visit('/forms/upload');
        browser.attach('text', '');
        await browser.pressButton('Upload');
      });

      it('should not upload any file', function() {
        browser.assert.text('body', 'nothing');
      });
    });


    describe('not set', function() {
      before(async function() {
        await browser.visit('/forms/upload');
        await browser.pressButton('Upload');
      });

      it('should not send inputs without names', function() {
        browser.assert.text('body', 'nothing');
      });
    });
  });


  describe('file upload with JS', function() {
    before(async function() {
      brains.static('/forms/upload-js', `
        <html>
          <head>
            <title>Upload a file</title>
            <script>
              function handleFile() {
                document.title = "Upload done";
                var file = document.getElementById("my_file").files[0];
                document.getElementById("filename").innerHTML = file.name;
                document.getElementById("type").innerHTML = file.type;
                document.getElementById("size").innerHTML = file.size;
                document.getElementById("is_file").innerHTML = (file instanceof File);
              }
            </script>
          </head>
          <body>
            <form>
              <input name="my_file" id="my_file" type="file" onchange="handleFile()">
            </form>
            <div id="filename"></div>
            <div id="type"></div>
            <div id="size"></div>
            <div id="is_file"></div>
          </body>
        </html>
      `);

      await browser.visit('/forms/upload-js');
      const filename = `${__dirname}/data/random.txt`;
      await browser.attach('my_file', filename);
    });

    it('should call callback', function() {
      browser.assert.text('title', 'Upload done');
    });
    it('should have filename', function() {
      browser.assert.text('#filename', 'random.txt');
    });
    it('should know file type', function() {
      browser.assert.text('#type', 'text/plain');
    });
    it('should know file size', function() {
      browser.assert.text('#size', '12');
    });
    it('should be of type File', function() {
      browser.assert.text('#is_file', 'true');
    });
  });


  describe('content length', function() {

    describe('post form urlencoded having content', function() {
      before(async function() {
        brains.static('/forms/urlencoded', `
          <html>
            <body>
              <form method="post">
                <input name="text" type="text">
                <input type="submit" value="submit">
              </form>
            </body>
          </html>
        `);

        brains.post('/forms/urlencoded', function(req, res) {
          res.send(`${req.body.text};${req.headers['content-length']}`);
        });

        await browser.visit('/forms/urlencoded');
        browser.fill('text', 'bite');
        await browser.pressButton('submit');
      });

      it('should send content-length header', function() {
        const [body, length] = browser.source.split(';');
        assert.equal(length, '9'); // text=bite
      });
      it('should have body with content of input field', function() {
        const [body, length] = browser.source.split(';');
        assert.equal(body, 'bite');
      });
    });

    describe('post form urlencoded being empty', function() {
      before(async function() {
        brains.static('/forms/urlencoded/empty', `
          <html>
            <body>
              <form method="post">
                <input type="submit" value="submit">
              </form>
            </body>
          </html>
        `);

        brains.post('/forms/urlencoded/empty', function(req, res) {
          res.send(req.headers['content-length']);
        });

        await browser.visit('/forms/urlencoded/empty');
        await browser.pressButton('submit');
      });

      it('should send content-length header 0', function() {
        assert.equal(browser.source, '0');
      });
    });
  });


  describe('GET form submission', function() {
    before(async function() {
      brains.static('/forms/get', `
        <html>
          <body>
            <form method="get" action="/forms/get/echo">
              <input type="text" name="my_param" value="my_value">
              <input type="submit" value="submit">
            </form>
          </body>
        </html>
      `);
      brains.get('/forms/get/echo', function(req, res) {
        res.send(`
          <html>
            <body>${req.query.my_param}</body>
          </html>
        `);
      });

      await browser.visit('/forms/get');
      await browser.pressButton('submit');
    });

    it('should echo the correct query string', function() {
      assert.equal(browser.text('body'), 'my_value');
    });
  });


  // DOM specifies that getAttribute returns empty string if no value, but in
  // practice it always returns `null`. However, the `name` and `value`
  // properties must return empty string.
  describe('inputs', function() {
    before(async function() {
      brains.static('/forms/inputs', `
        <html>
          <body>
            <form>
              <input type="text">
              <textarea></textarea>
              <select></select>
              <button></button>
            </form>
          </body>
        </html>
      `);
      await browser.visit('/forms/inputs');
    });

    it('should return empty string if name attribute not set', function() {
      for (let tagName of ['form', 'input', 'textarea', 'select', 'button']) {
        browser.assert.attribute(tagName, 'name', null);
      }
    });
    it('should return empty string if value attribute not set', function() {
      for (let tagName of ['input', 'textarea', 'select', 'button']) {
        assert.equal(browser.query(tagName).getAttribute('value'), null);
        assert.equal(browser.query(tagName).value, '');
      }
    });
    it('should return empty string if id attribute not set', function() {
      for (let tagName of ['form', 'input', 'textarea', 'select', 'button']) {
        assert.equal(browser.query(tagName).getAttribute('id'), null);
        assert.equal(browser.query(tagName).id, '');
      }
    });
  });


  after(function() {
    browser.destroy();
  });
});
