# Create Transform util
# Eg:
# Transform.map obj,
#   'path.to.property': 'newName',
#   'path to optional property': 'newName'


# Create collection of events by name
# All clients will listen for changes and do something whenever the data is updated

@Events = new Meteor.Collection 'Events'
Events.handlers = {}

mergeNoConflict = (objTo, objFrom) ->
  for k,v of objFrom
    unless objTo[k]? then objTo[k] = v
    else console.warn "Property '#{k}' already exists in object."

upsert = (name, data...) ->
  Events.upsert name:name,
    $set: {data: data, date: new Date},
    (err, args...) ->
      if err? then console.error 'update failed', err
      #else console.log 'updated', (data.concat args)...

Meteor.methods event: upsert

updateEvent = (name, data...) ->
  handlers = Events.handlers[name]
  if handlers?.length > 0
    (fn data...) for fn in handlers
  if Meteor.isClient
    Meteor.call 'event', name, data...
  else upsert name, data...

bind = (name, fn) ->
  handlers = Events.handlers[name]
  if handlers? and fn?
    handlers.push fn
    Events.handlers[name] = handlers
  else if fn? then Events.handlers[name] = [fn]
  else console.error 'fn must be present', fn

if Meteor.isServer
  mergeNoConflict Events,
    on: (name, fn) -> bind name, fn
    emit: (name, data...) ->
      Meteor.publish 'events', (name) ->
        Events.find name:name
      updateEvent name, data...

else if Meteor.isClient
  subscribeToEvent = (name, fn) ->
    bind name, fn
    Meteor.subscribe 'events', name
    isInitial = true
    listen = ->
      #console.log 'calling listen'
      event = Events.find(name:name).fetch()[0]
      if event isnt undefined and not isInitial then fn event.data...
      else console.warn 'no event by that name'
      isInitial = false
    Tracker.autorun listen
    #Meteor.setInterval listen, 500

  mergeNoConflict Events,
    on: (name, fn) -> subscribeToEvent name, fn
    emit: (name, args...) -> updateEvent name, args...

Meteor.startup ->
  Events.counter = 0
  #Events.on 'test', (args...) -> console.log 'event:', args...
  Events.on 'test', -> Events.counter++