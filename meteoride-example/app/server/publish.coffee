Meteor.publish 'posts', -> Posts.find()
Meteor.publish 'messages', -> Messages.find()