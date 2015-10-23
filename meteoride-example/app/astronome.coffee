@Directories = new Meteor.Collection "Directories"
@Files = new Meteor.Collection "Files"

if Meteor.isServer
  Meteor.startup ->
    parameters = Astronome.checkParams
      sourcePath: "C:/Users/Matthew/Documents/Github/MeteorIDE/meteoride-example/app/"
      idFilename: '.astronomeid'
      directoryCollection: Directories
      fileCollection: Files
      onDirectoryAddedBeforeCB: (dirFullPath) ->
        console.log JSON.stringify onDirectoryAddedBeforeCB: [dirFullPath, @someUserData++]
        true
      onDirectoryAddedAfterCB: (dir) ->
        console.log JSON.stringify onDirectoryAddedAfterCB: [dir, @someUserData++]
        true
      onDirectoryDeletedCB: (dir) ->
        console.log JSON.stringify onDirectoryDeletedCB: [dir, @someUserData++]
        true
      onDirectoryMovedCB: (dir, oldDirPath) ->
        console.log JSON.stringify onDirectoryMovedCB: [dir, oldDirPath, @someUserData++]
        true
      onFileAddedAfterCB: (file) ->
        console.log JSON.stringify onFileAddedAfterCB: [file, @someUserData++]
        true
      onFileDeletedCB: (file) ->
        console.log JSON.stringify onFileDeletedCB: [file, @someUserData++]
        true
      onFileChangedCB: (file) ->
        console.log JSON.stringify onFileChangedCB: [file, @someUserData++]
        true
      someUserData: 0

    Meteor.setInterval (-> Astronome.parse parameters), 10000