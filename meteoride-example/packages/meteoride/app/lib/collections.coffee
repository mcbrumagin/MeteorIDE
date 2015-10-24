@Resources = new Meteor.Collection 'resources'
@Files = new FS.Collection 'files',
  stores: [
    (new FS.Store.FileSystem 'files', path: '~/..')
  ]