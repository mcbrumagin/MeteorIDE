if Meteor.isClient
  enable = (enable = true) ->
    Reload.isWaitingForResume = -> enable
    Reload._onMigrate (retry) -> [enable]

  Reload.enable = enable
  Reload.disable = -> enable false

