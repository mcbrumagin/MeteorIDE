Package.describe({
    summary: 'MeteorIDE allows you to develop your application from your browser.',
    version: '0.0.0',
    name: 'meteoride'
})

Package.onUse(function(api) {
    var Client = 'client',
        Server = 'server',
        Both = [Client, Server]

    api.use('cfs:standard-packages@0.5.9', Both)
    api.use('cfs:filesystem@0.1.2', Both)

    //api.imply('templating')
    api.use([
        'templating',
        'handlebars'
    ], Client)

    api.use('coffeescript', Both)

    api.addFiles([
        'app/client/meteoride.html',
        'app/client/startup.coffee',
        'app/client/templates.coffee'
    ], Client)

    api.addFiles('app/lib/collections.coffee', Both)

    //api.addFiles('app/server/startup.coffee')
    api.addFiles('app/server/publish.coffee', Server)

    //api.export('MIDE', Both)
})
