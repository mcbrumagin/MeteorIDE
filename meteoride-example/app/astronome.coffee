@Directories = new Meteor.Collection "Directories"
@Files = new Meteor.Collection "Files"

if Meteor.isServer
  Meteor.startup ->
    parameters = Astronome.checkParams
      sourcePath: Meteor.settings.sourcePath
      idFilename: '.astronomeid'
      directoryCollection: Directories
      fileCollection: Files
      onDirectoryAddedBeforeCB: (dirFullPath) ->
        #console.log JSON.stringify onDirectoryAddedBeforeCB: [dirFullPath, @someUserData++]
        true
      onDirectoryAddedAfterCB: (dir) ->
        #console.log JSON.stringify onDirectoryAddedAfterCB: [dir, @someUserData++]
        true
      onDirectoryDeletedCB: (dir) ->
        #console.log JSON.stringify onDirectoryDeletedCB: [dir, @someUserData++]
        true
      onDirectoryMovedCB: (dir, oldDirPath) ->
        #console.log JSON.stringify onDirectoryMovedCB: [dir, oldDirPath, @someUserData++]
        true
      onFileAddedAfterCB: (file) ->
        #console.log JSON.stringify onFileAddedAfterCB: [file, @someUserData++]
        true
      onFileDeletedCB: (file) ->
        #console.log JSON.stringify onFileDeletedCB: [file, @someUserData++]
        true
      onFileChangedCB: (file) ->
        #console.log JSON.stringify onFileChangedCB: [file, @someUserData++]
        true
      someUserData: 0

    Meteor.setInterval (-> Astronome.parse parameters), 10000
    console.log process.env.AUTOUPDATE_VERSION

setReload = (enable) ->
  if enable
    console.log process.env.AUTOUPDATE_VERSION
    delete process.env.AUTOUPDATE_VERSION
  else process.env.AUTOUPDATE_VERSION = 'you suck'

printIfErr = (err, res)->
  if err? then console.error err

if Meteor.isClient
  @Reload =
    enable: -> Meteor.call 'enableReload', printIfErr
    disable: -> Meteor.call 'disableReload', printIfErr
else Meteor.methods
  enableReload: ->
    setReload true
  disableReload: ->
    setReload false
    setTimeout (-> setReload false), 50
  setReload: setReload
  reload: ->
    setReload true
    setTimeout (-> setReload false), 50

