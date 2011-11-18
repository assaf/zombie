class Interaction
  constructor: (browser)->
    # Collects all prompts (alert, confirm, prompt).
    prompts = []

    alertFns = []
    # When alert displayed to user, call this function.
    this.onalert = (fn)-> alertFns.push fn

    confirmFns = []
    confirmCanned = {}
    # When prompted with a question, return the response. First argument
    # may be a function.
    this.onconfirm = (question, response)->
      if typeof question == "function"
        confirmFns.push question
      else
        confirmCanned[question] = !!response

    promptFns = []
    promptCanned = {}
    # When prompted with message, return response or null if response is
    # false. First argument may be a function.
    this.onprompt = (message, response)->
      if typeof message == "function"
        promptFns.push message
      else
        promptCanned[message] = response

    this.prompted = (message)-> prompts.indexOf(message) >= 0

    this.extend = (window)->
      # Implements window.alert: show message.
      window.alert = (message)->
        prompts.push message
        fn message for fn in alertFns
        return
      # Implements window.confirm: show question and return true/false.
      window.confirm = (question)->
        prompts.push question
        response = confirmCanned[question]
        unless response || response == false
          for fn in confirmFns
            response = fn(question)
            break if response || response == false
        return !!response
      # Implements window.prompt: show message and return value of null.
      window.prompt = (message, def)->
        prompts.push message
        response = promptCanned[message]
        unless response || response == false
          for fn in promptFns
            response = fn(message, def)
            break if response || response == false
        return response.toString() if response
        return null if response == false
        return def || ""


exports.use = (browser)->
  return new Interaction(browser)
