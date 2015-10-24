Template.meteoride.helpers
  resources: -> Resources.find().fetch()

Template.resource.helpers
  name: -> @name or ''
  path: -> @path or ''