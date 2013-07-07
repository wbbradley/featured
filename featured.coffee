log = (level, msg) ->
  if typeof console != 'undefined'
    console.log "home-dashboard : #{level} : #{msg}"

Features = new Meteor.Collection 'features'

if Meteor.isClient
  dumpColl = (coll) ->
    coll.find().forEach (item) ->
      console.log item

  Features.deleteAll = ->
    Features.find().forEach (message) ->
      Features.remove message._id

  append_time_unit = (diff, unit_name, unit, ret) ->
    if diff > unit
      units = Math.floor diff / unit
      diff -= units * unit
      ret += "#{units} #{unit_name}"
      if units isnt 1
        ret += 's'
    if diff > 0 and units > 0
      ret += ', '
    else if units > 0
      ret += ' ago'
    [diff, ret]

  formatDate = (date) ->
    minute = 60
    hour = 60 * minute
    day = 24 * hour
    week = 7 * day
    moon = 28 * day
    diff = Math.round (Date.now() - date) / 1000.0
    orig_diff = diff
    ret = ''
    if diff >= 5
      if diff > 120
        diff = diff - (diff % 60)
      [diff, ret] = append_time_unit diff, 'moon', moon, ret
      [diff, ret] = append_time_unit diff, 'week', week, ret
      [diff, ret] = append_time_unit diff, 'day', day, ret
      [diff, ret] = append_time_unit diff, 'hour', hour, ret
      [diff, ret] = append_time_unit diff, 'minute', minute, ret
      [diff, ret] = append_time_unit diff, 'second', 1, ret
    else
      ret = 'just now'
    ret

  getFeature = (el) ->
    if el.hasAttribute 'data-feature-id'
      return Features.findOne el.getAttribute 'data-feature-id'
    else
      return Features.findOne $(el).parents('.feature').data 'featureId'

  Template['feature-new'].events
    'change input[name=estimates]': (event) ->
      featureId = getFeatureId(event.target)
      console.log "Feature #{featureId} changed"

  Template.feature.helpers
    'dateRender': (timestamp) ->
      formatDate(timestamp)

    'renderState': (feature) ->
      log 'info', 'state is '
      log 'info', @state
      if @state of Template
        return Template[@state] @
      else
        return "TODO: implement state template #{@state}"

  Template.features.features = ->
    Features.find {}, {sort: {timestamp: -1}}

  Template.feature.events
    'click button[name=close-feature]': (event) ->
      feature = getFeature event.target
      Features.remove id

  Template.feature.helpers
    getAuthorImage: (author) ->
      if author.services.twitter
        return author.services.twitter.profile_image_url.replace('_normal', '')
      else if author.services.google
        return author.services.google.picture
      else if author.services.facebook
        return "http://graph.facebook.com/#{author.services.facebook.id}/picture?type=large"
      else
        throw new Error "no author image"

  Template.controls.events
    'keypress input[name=feature-name]': (event) ->
      if event.which is 13
        createFeature()
        return false
      return
    'click input[name=feature-name]' : ->
      createFeature()

  createFeature = ->
    name = $('input[name="feature-name"]').val()
    $('input[name="feature-name"]').val('')
    if name
      log 'info', name
      feature =
        name: name
        timestamp: Date.now()
        author: Meteor.user()
        state: 'feature-new'
      Features.insert feature, (obj, _id) ->
        if typeof obj is 'undefined'
          log 'info', "feature logged '#{_id}'"
        else
          log 'warning', 'error inserting a new feature'
  @Features = Features
  @formatDate = formatDate
  @dumpColl = dumpColl

if Meteor.isServer
  Meteor.startup ->
    # code to run on server at startup
