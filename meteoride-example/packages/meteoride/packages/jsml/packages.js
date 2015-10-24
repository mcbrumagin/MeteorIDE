Package.describe({
    summary: 'JavaScript Markup Language',
    version: '0.0.2',
    name: 'jsml'
})

Package.onUse(function(api) {
    api.use(['coffeescript'], ['client'])
    api.addFiles('jsml.coffee')
    api.export('Jsml', ['client'])
})
