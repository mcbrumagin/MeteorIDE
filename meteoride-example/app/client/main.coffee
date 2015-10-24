Template.main.helpers
  posts: -> Posts.find().fetch()
  files: -> Files.find().fetch()

Template.post.helpers
  title: -> @title or 'Untitled'
  content: -> @content or ''
  date: -> @dateUpdated or @dateCreated or @date

Template.addPost.events
  "submit form": (event) ->
    event.preventDefault()
    model = {}
    (($ event.currentTarget).find "[name]").each ->
      $elem = $ @
      val = $elem.val()
      if val? then model[$elem.attr 'name'] = val
      else model[$elem.attr 'name'] = $elem.html()
    model.dateCreated = new Date
    Posts.insert model

