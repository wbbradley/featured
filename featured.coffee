log = (level, msg) ->
  if typeof console != 'undefined'
    console.log "featured : #{level} : #{msg}"

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

  checked = (el) ->
    return $(el)?.prop('checked')

  featureStates =
    requirements:
      next: 'design'
      desc: 'This feature is in Requirements Gathering'
      items:
        owners: 'Dev Owner of the feature has been established'
        stakeholders: 'Key Stakeholders of the feature have been established.'
        requirements: 'Requirements have been gathered'
        targetDateReq: 'A rough target date has been agreed upon between the stakeholders and the owner'
    design:
      next: 'preCoding'
      desc: 'This feature is in Design'
      items:
        design: 'UX Design has been assembled.'
        assetsReq: 'Visual requirements or other required assets have been identified'
        deliverable: 'Requirements have been gathered from are entered into tracking software'
        estimates: 'Estimates are entered into tracking software'
        approval: 'Design is approved by stakeholders'
        targetDateDesign: 'A clearly defined target date range has been agreed upon between the stakeholders and the owner'
    preCoding:
      next: 'inProgress'
      desc: 'This feature is Pre-Coding iteration'
      items:
        assetsInMotion: 'Non-code asset gathering is underway.'
        stakeholdersDesign: 'Key Stakeholders of the feature have been established.'

    inProgress:
      next: 'complete'
      desc: 'Coding is ongoing on this feature.'
      items:
        tested: 'You have run all tests in staging'
        published: 'The feature is live'
    complete:
      next: undefined
      desc: 'This feature is in the hands of its target audience.'

  updateCheckbox = (event) ->
    feature = getFeature event.target
    if not feature
      throw new Error "Can't find feature from event.target"
    feature.items = feature.items or {}
    feature.items[event.target.name] = checked(event.target)
    complete = true
    for item of featureStates[feature.state].items
      if not item of feature.items or not feature.items[item]
        complete = false
        break

    if complete
      feature.state = featureStates[feature.state].next

    Features.update feature._id,
      $set: _.omit feature, '_id'

  Template.features.features = ->
    Features.find {}, {sort: {timestamp: -1}}

  # Set up feature update events
  events =
    'click button[name=close-feature]': (event) ->
      feature = getFeature event.target
      Features.remove feature._id
    'change input[type=checkbox]': updateCheckbox

  Template.feature.events events

  Template.feature.helpers
    status: () ->
      featureStates[@state].desc

    dateRender: (timestamp) ->
      formatDate(timestamp)

    ifChecked: (item_name, options) ->
      if item_name of @items and @items[item_name]
        return options.fn @
      else
        return options.inverse @

    items: (context, options) ->
      if not @_id or not @author
        throw new Error "This doesn't look like a feature"
      ret = ''
      console.log "Looking for #{@state}"
      if not @state of featureStates
        throw new Error "Invalid state '#{@state}' found"
      for item_name, item_description of featureStates[@state].items
        console.log "rendering feature #{@name} item #{item_name}"
        ret = ret + options.fn
          name: item_name
          description: item_description
          checked: if (item_name of @items and @items[item_name]) then 'checked="checked"' else ''
      return ret

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
    'click button[name=feature-add]' : ->
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
        state: 'requirements'
        items: {}
      Features.insert feature, (obj, _id) ->
        if typeof obj is 'undefined'
          log 'info', "feature logged '#{_id}'"
        else
          log 'warning', 'error inserting a new feature'
  @Features = Features
  @featureStates = featureStates
  @formatDate = formatDate
  @dumpColl = dumpColl

  # Finally, subscribe to the features collection
  Meteor.subscribe 'features'


if Meteor.isServer
  if not Meteor.settings.validDomain
    console.log "!!! Unabled to find Meteor.settings.validDomain"

  endsWith = (string, suffix) ->
      string.indexOf(suffix, string.length - suffix.length) isnt -1

  validUserByEmail = (user) ->
    if user?.services?.google?.email
      if endsWith user.services.google.email, ('@' + Meteor.settings.validDomain)
        return true
    else
      return false

  # Setup security features
  Meteor.users.deny
    update: () ->
      return true

  Meteor.publish 'features', () ->
    console.log "Checking whether to publish for user #{@userId}"
    if validUserByEmail Meteor.users.findOne @userId
      console.log "Yep. Publishing to user #{@userId}"
      return Features.find()
    else
      console.log "Nope. Not going to publish to user #{@userId}"
      return undefined

  Accounts.validateNewUser (user) ->
    if validUserByEmail user
      return true
    throw new Meteor.Error 403, "Sorry, you are not allowed to have access to this site."

  Features.allow
    insert: (userId, doc) ->
      console.log "Checking #{userId}"
      return validUserByEmail Meteor.users.findOne userId
    update: (userId, doc, fieldNames, modifier) ->
      console.log "Checking #{userId}"
      valid = validUserByEmail Meteor.users.findOne userId
      console.log "update valid #{valid}"
      return valid
    remove: (userId, doc) ->
      console.log "Checking #{userId}"
      return validUserByEmail Meteor.users.findOne userId

  Meteor.startup ->
    # code to run on server at startup
