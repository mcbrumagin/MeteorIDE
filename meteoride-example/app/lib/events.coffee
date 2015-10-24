# TODO: Actually test stuff
Meteor.startup ->
  Events.counter = 0
  Events.on 'test', (args...) -> console.log 'event:', args...
  Events.on 'test', -> Events.counter++
  Events.on 'example', -> console.log Events.counter
  Events.emit 'example', 'example'
  if Meteor.isClient
    Events.on 'client', -> console.log 'event triggered from server'
  if Meteor.isServer
    Events.on 'server', -> console.log 'server called from event'
    Events.on 'triggerEventFromServer', ->
      Events.emit 'server'
      Events.emit 'client'
