Meteor.startup ->
  context = resources: Resources.find()
  UI.renderWithData Template.meteoride, context, document.body