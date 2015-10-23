@Astronome = do ->
  if Meteor.isClient
    keys = {}
    Template.editorPane.helpers
      content: -> @workingContent or @savedContent
      date: -> (new Date @lastParsedTime).toLocaleString()
    Template.editorPane.events
      "keydown": (e) ->
        keys[e.which] = true
        keys['ctrlKey'] = e.ctrlKey
        if keys['ctrlKey'] and keys[83]
          e.preventDefault()
          Meteor.call 'saveChangesToFS', (err) ->
            if err? then console.error err
            else console.info 'Persisting file changes to FS'
      "keyup": (e) -> keys[e.which] = null
      "input textarea": (e) ->
        Meteor.call 'updateFile', @_id, $(e.currentTarget).val(), (err) ->
          if err? then console.error err
          else console.info 'Saved file to DB'
  if Meteor.isServer
    path = Npm.require 'path'
    fs = Npm.require 'fs'
    util = Npm.require 'util'

    E = {}
    createErrProp = (name, e, r) -> E[name] = {error:e, reason:r }
    createErrProp n... for n in [
      ['ParamsMustBeObject', 1473, 'params must be an object']
      ['WrongSourcePath', 1474, 'sourcePath must be a string']
      ['SourceNotFound', 1475, 'directory at sourcePath not found']
      ['InvalidDirectoryCollection', 1476, 'directoryCollection must be a valid Meteor Collection']
      ['InvalidFileCollection', 1477, 'fileCollection must be a valid Meteor Collection']
      ['MissingDirectoryInDatabase', 1479, 'could not find tracked directory in database']
      ['CorruptedDirectoryInDatabase', 1480, 'directory in database is corrupted (has no "sourceId" key)']
      ['FailedToInsertDirectoryInDatabase', 1481, 'failed to insert directory in database']
      ['FailedToWriteIdTrackerFile', 1482, 'failed to create and write to IdTracker file']
      ['FailedToInsertFileInDatabase', 1483, 'failed to insert file in database']
      ['FailedToParseKnownSubDirectory', 1484, 'cannot parse a known subdirectory as a source']
      ['FailedToForgetNotSourceDirectory', 1485, 'cannot forget a directory that is not a source']
    ]

    err = (e, details) ->
      throw new Meteor.Error e.error, "[Astronome] #{e.reason}:#{details}", details or ''

    defaults =
      sourcePath: null
      directoryCollection: null
      fileCollection: null
      idFilename: '.astronomeid'
      onDirectoryAddedBeforeCB: -> true
      onDirectoryAddedAfterCB: -> true
      onDirectoryDeletedCB: -> true
      onDirectoryMovedCB: -> true
      onDirectoryForgottenCB: -> true
      onFileAddedBeforeCB: -> true
      onFileAddedAfterCB: -> true
      onFileDeletedCB: -> true
      onFileChangedCB: -> true
      onFileForgottenCB: -> true

    tis =
      undef: (obj) -> obj is undefined
      obj: (obj) -> typeof obj is 'object'
      arr: (obj) -> util.isArray obj
      str: (obj) -> typeof obj is 'string'
      fn: (obj) -> typeof obj is 'function'

    tisnt = {}
    createIsntFn = (n,f) -> tisnt[n] = (obj) -> not f obj
    createIsntFn n,f for n,f of tis

    check =
      params: (params) ->
        unless (tis.obj params) and (tisnt.arr params)
          err E.ParamsMustBeObject
      dir: (dir, fullpath) ->
        if not dir then err E.MissingDirectoryInDatabase, fullpath
        if not dir.sourceId? then err E.CorruptedDirectoryInDatabase
      path: (path) ->
        if tisnt.str path then err E.WrongSourcePath, path
      exists: (path) ->
        if not fs.existsSync path then err E.SourceNotFound, path
      collection: (collection) ->
        if not collection or
          (tisnt.obj collection) or
          (tis.arr collection) or
          (tisnt.fn collection._makeNewID) then err E.InvalidDirectoryCollection

    checkParams = (params) ->
      check.params params
      (params[k] = v) for k,v of defaults when not params[k]?
      check.path params.sourcePath
      if path.sep != params.sourcePath.substr -1 then params.sourcePath += path.sep
      check.exists params.sourcePath
      for c in [params.directoryCollection, params.fileCollection]
        check.collection c
      return params

    getKnownSourceDirectory = (p) ->
      idPath = p.sourcePath + p.idFilename
      if fs.existsSync idPath
        dirId = '' + fs.readFileSync idPath
        dir = p.directoryCollection.findOne dirId
        check.dir dir, p.sourcePath
        dir
      else null

    processDir = (p, parentdir, sDirRelPath) ->
      idPath = p.sourcePath + sDirRelPath + p.idFilename
      fullpath = p.sourcePath + sDirRelPath
      bRootDir = sDirRelPath == ''
      dirId = undefined
      dir = null
      if not fs.existsSync idPath
        #console.log "processing new #{fullpath}"
        if bRootDir or p.onDirectoryAddedBeforeCB fullpath
          dirId = p.directoryCollection.insert
            sourceId: p.sourceId
            parentId: p.parentDir._id
            dirPath: fullpath
            lastParsedTime: p.updateTime
          if not dirId then err E.FailedToInsertDirectoryInDatabase
          dir = p.directoryCollection.findOne dirId
          check.dir dir, fullpath
          #console.log "writing id file #{idPath} with content #{dirId}"
          if fs.writeFileSync idPath, dirId then err E.FailedToWriteIdTrackerFile
          if not bRootDir then p.onDirectoryAddedAfterCB dir
      else
        #console.log "processing existing #{fullpath}"
        dirId = '' + fs.readFileSync idPath
        dir = p.directoryCollection.findOne dirId
        check.dir dir, fullpath
        olddirPath = dir.dirPath
        if olddirPath != fullpath
          p.directoryCollection.update dirId, $set:
            sourceId: p.sourceId
            parentId: p.parentDir._id
            dirPath: fullpath
            lastParsedTime: p.updateTime
          dir = p.directoryCollection.findOne dirId
          check.dir dir, fullpath
          if not bRootDir then p.onDirectoryMovedCB dir, olddirPath
        # In any case, update the last parsed time
        else p.directoryCollection.update dirId, $set: lastParsedTime: p.updateTime
      dir

    extensionRegexp = new RegExp(/([^.]+)\.(.*)$/)

    processFile = (p, dir, sFileName, sDirRelPath, mtime) ->
      fullpath = p.sourcePath + sDirRelPath
      if sFileName == p.idFilename then return
      file = undefined
      file = p.fileCollection.findOne $and: [
        { parentId: dir._id }
        { filename: sFileName }
      ]
      if file
        #console.log "[processExistingFile] #{sFileName} last changed on #{file.mtime} vs #{mtime}"
        # compare mtime from database to filesystem to check if it has changed or not
        if file.mtime < mtime then p.onFileChangedCB file
        # update lastParsedTime in order to detect deleted files
        p.fileCollection.update file._id, $set:
          savedContent: fs.readFileSync fullpath, 'utf8'
          sourceId: p.sourceId
          mtime: mtime
          lastParsedTime: p.updateTime
      else
        result = sFileName.match extensionRegexp
        basename = result[1]
        extension = result[2]
        #console.log "[processNewFile] #{sFileName}"
        if p.onFileAddedBeforeCB sFileName, basename, extension
          fileID = p.fileCollection.insert
            sourceId: p.sourceId
            parentId: dir._id
            filename: sFileName
            fullpath: fullpath
            savedContent: fs.readFileSync fullpath, 'utf8'
            basename: basename
            extension: extension
            mtime: mtime
            lastParsedTime: p.updateTime
          if not fileID then err E.FailedToInsertFileInDatabase
          else p.onFileAddedAfterCB p.fileCollection.findOne fileID
      false

    recursiveBackup = (objA, history) ->
      objB = undefined
      if objA and Array.isArray(objA) then objB = []
      else if objA and typeof objA == 'object' then objB = {}
      else return objA
      history.push {a: objA, b: objB}
      for attr of objA
        if objA.hasOwnProperty(attr) and not defaults.hasOwnProperty(attr)
          if Object.getOwnPropertyDescriptor(objA, attr).writable
            if objA[attr] and typeof objA[attr] == 'object'
              bFound = false
              h = 0
              while h < history.length
                if history[h].a == objA[attr]
                  objB[attr] = history[h].b
                  bFound = true
                ++h
              if !bFound then objB[attr] = recursiveBackup(objA[attr], history)
            else objB[attr] = objA[attr]
      objB
    recursiveRestore = (org, bkp, history) ->
      if tis.undef org then return
      for h in history when h == bkp
        org = h.b
        return

      history.push {b: bkp, o: org}
      for k of bkp when bkp.hasOwnProperty k
        if bkp[k] and typeof bkp[k] == 'object'
          bAlreadyRestored = false
          for h in history when h.b == bkp[k]
            org[k] = h.o
            bAlreadyRestored = true
          if not bAlreadyRestored
            recursiveRestore org[k], bkp[k], history
        else org[k] = bkp[k]

    backup = (objA) -> recursiveBackup objA, []
    restore = (obj, backup) -> recursiveRestore obj, backup, []

    recursiveParseDir = (p, sDirPath) ->
      dir = p.parentDir
      #console.log "parsing dir #{sDirPath} with id #{p.parentDir._id}"
      elts = fs.readdirSync p.sourcePath + sDirPath
      for elt in elts
        relEltPath = sDirPath + elt
        eltStats = fs.statSync p.sourcePath + relEltPath
        if eltStats.isDirectory()
          subdir = processDir p, dir, relEltPath + path.sep
          if subdir
            bkp = backup p
            p.parentDir = subdir
            recursiveParseDir p, relEltPath + path.sep
            restore p, bkp
        else processFile p, dir, elt, relEltPath + path.sep, eltStats.mtime.getTime()

    parse = (params) ->
      p = checkParams params
      p.sourceId = 0
      p.parentDir = 0
      p.updateTime = Date.now()
      rootDir = processDir p, null, ''
      if rootDir.parentId then err E.FailedToParseKnownSubDirectory
      p.sourceId = rootDir._id
      p.parentDir = rootDir
      recursiveParseDir p, ''

      # All subdirs and files of this source that have not been updated have been deleted
      dirsToDeleteIds = dirsWithNullSource = filesToDeleteIds = filesWithNullSource = []

      sourceDirs = (p.directoryCollection.find sourceId: rootDir._id).fetch()
      for d in sourceDirs when d.lastParsedTime != p.updateTime
        if p.onDirectoryDeletedCB d then dirsToDeleteIds.push d._id
        else dirsWithNullSource.push d._id

      sourceFiles = (p.fileCollection.find sourceId: rootDir._id).fetch()
      for f in sourceFiles when f.lastParsedTime != p.updateTime
        if p.onFileDeletedCB f then filesToDeleteIds.push f._id
        else filesWithNullSource.push f._id

      # Clean database
      p.directoryCollection.remove _id: $in: dirsToDeleteIds
      p.fileCollection.remove _id: $in: filesToDeleteIds
      p.directoryCollection.update { _id: $in: dirsWithNullSource }, $set: sourceId: null
      p.fileCollection.update { _id: $in: filesWithNullSource }, $set: sourceId: null

    forget = (params) ->
      p = checkParams params
      rootDir = getKnownSourceDirectory p
      if rootDir == null or rootDir.parentId != null
        err E.FailedToForgetNotSourceDirectory, rootDir

      # forget files
      sourceFiles = (p.fileCollection.find sourceId: rootDir._id).fetch()
      (p.onFileForgottenCB f) for f in sourceFiles
      p.fileCollection.remove sourceId: rootDir._id

      # forget dirs
      sourceDirs = (p.directoryCollection.find sourceId: rootDir._id).fetch()
      for d in sourceDirs
        p.onDirectoryForgottenCB dir
        try fs.unlinkSync dir.dirPath + p.idFilename
      p.directoryCollection.remove sourceId: rootDir._id

      # forget source
      try fs.unlinkSync rootDir.dirPath + p.idFilename
      p.directoryCollection.remove rootDir

    getFileDirAndName = (fullpath) ->
      frags = fullpath.split '/'
      name = frags[frags.length - 1]
      dir = (frags.slice 0, frags.length - 1).join '/'
      [dir, name]

    queue = []
    Meteor.startup ->
        Meteor.methods
          saveChangesToFS: ->
            queue.pop()() for i in [1..queue.length]
          saveFile: (fullpath, content) ->
            file = Files.findOne fullpath: fullpath
            if file? then Files.update file._id, '$set': workingContent: content
            queue.unshift -> fs.writeFileSync fullpath, content, 'utf8'
          updateFile: (id, content) ->
            file = Files.findOne _id: id
            if file?
              Files.update id, '$set': workingContent: content
              queue.unshift -> fs.writeFileSync file.fullpath, content, 'utf8'
          deleteFile: ->
          moveFile: ->

    # Public API
    messages: E
    checkParams: (params) -> checkParams params
    parse: (params) -> parse params
    forget: (params) -> forget params
