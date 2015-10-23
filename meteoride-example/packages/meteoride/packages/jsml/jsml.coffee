Jsml = new (->
  _ = @
  forOwn = (obj, fn) ->
    for key, val of obj
      if obj.hasOwnProperty key
        fn.call obj, key, val

  styleNames = []
  checkStyle = (style) ->
    styleNames.indexOf style > 0

  @isValidStyle = (style) ->
    if styleNames.length then checkStyle style
    else # TODO var body = document.getElementsByTagName('body')[0]
      forOwn document.body.style, (key, val) ->
        if val? then styleNames.push val
      checkStyle style

  @parseStyle = (style, $base) ->
    parseTree = (selector, rules) ->
      continueParseTree = (s,r) ->
        parseTree "#{selector} #{s}", r

      parseRules = ->
      parseRulesForSelector = (extendedSelector, property, value) ->
        $elems = ->
          if $base then $base.find extendedSelector or selector
          else $ extendedSelector or selector

        if $.isPlainObject value then forOwn value,
          (a...) -> parseRulesForSelector "#{selector} #{property}", a...
        else if $.isFunction value
          fn = value
          $elems().each (i,v) ->
            $(v).css property, fn $elem
        else if property equals 'mixin'
          mixin = value
          if $.isPlainObject mixin then forOwn mixin, continueParseTree
          else if $.isFunction mixin then # TODO evaluate after rendering
          else if mixin.length > 0 then (forOwn m, parseRules) for m in mixin
          else # TODO mixin matching selector
        else if value.length
          ($elems().css property, style) for style in value
        else if _.isValidStyle property then $elems().css property, value

      parseRules = (a...) -> parseRulesForSelector null, a...

      if $.isPlainObject rules then forOwn rules, parseRules
      else console.warn "Other object parsing is not yet implemented.",
        {selector: selector, rules: rules}

    forOwn style, parseTree

  @Writer = (options) ->
    createNode = (isVoid, tag, attributes, strings...) ->
      if isVoid then value = strings[0]
      text = attrstr = ''

      if isVoid
        if not $.isPlainObject attributes
          attributes = value:attributes
        else if value? then attributes.value = value
      else if not $.isPlainObject attributes
        text += attributes
        attributes = {}

      forOwn attributes, (prop, attr) ->
        if not options.useRawAttributes
          prop = prop.replace /[A-Z]/g, (match) -> "-#{match.toLowerCase()}"

        if attr? and attr isnt false
          if prop is 'style' then attrstr += _.parseStyle attr
          else if $.isFunction attr
            regexInnerFn = /function\s\(\)\s\{([\s\S]+)\}/gi
            attrstr += " #{prop}=\"#{regexInnerFn.exec(attr)[1]}\""
          else attrstr += " #{prop}=\"#{attr}\""

      (text += str) for str in strings when str?

      if isVoid then "<#{tag}#{attrstr} />"
      else "<#{tag}#{attrstr}>#{text}</#{tag}>"

    node = (a...) -> createNode false, a...
    voidNode = (a...) -> createNode true, a...

    writer = options?.context or {}
    createMethods = (methodNames, baseFn) ->
      methodNames.split(' ').forEach (e) ->
        writer[e] = (a...) -> baseFn e, a...

    normalNodes = 'p span li label ul ol div h1 h2 h3 h4 h5 h6 button code pre a'
    voidNodes = 'input i br'

    createMethods normalNodes, node
    createMethods voidNodes, voidNode
    return writer
  return _
)
