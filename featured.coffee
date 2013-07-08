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

  Workflow =
    Roles:
      Owner:
        name: 'Dev'
        desc: 'Development owner of the feature'
      Stakeholder:
        name: 'Biz Buddy'
        desc: 'Person assigned to ensure product value and market readiness'

    States:
      requirements:
        desc: 'Requirements Gathering'
        itemsByRole:
          Owner:
            owner: 'Dev Owner of the feature has been established'
            stakeholder: 'Key Stakeholders of the feature have been established.'
            requirements: 'Requirements have been gathered'
            targetDateReq: 'A target date is established'
          Stakeholder:
            established: 'You accept responsibility for ensuring this feature aligns with positive business value'
            targetDateReqApproved: 'You approve of the target date but understand it may change due to future events'
        next: 'design'

      design:
        desc: 'Design'
        itemsByRole:
          Owner:
            design: 'UX Design has been assembled.'
            assetsReq: 'Visual requirements or other required assets have been identified'
            deliverable: 'Requirements have been gathered from are entered into tracking software'
            estimates: 'Estimates are entered into tracking software'
            techSanity: 'You have convinced another dev that your estimates are sane'
            approval: 'Design is approved by stakeholders'
            targetDateDesign: 'A firm date has been identified for this deliverable'
          Stakeholder:
            designApproved: 'User Experience design (wireframe, etc...) is approved'
            assetsApproved: 'Visual goals (graphics, fonts, colors, etc...) are approved'
            valueProp: 'You understand the value proposition of aiming for this deliverable'
            targetDateDesignApproved: 'A clearly defined target date range has been agreed upon between the stakeholders and the owner'
        next: 'preCoding'

      preCoding:
        desc: 'Precoding Iteration'
        itemsByRole:
          Owner:
            assetsInMotion: 'Non-code asset gathering is underway.'
            stakeholdersDesign: 'Key Stakeholders of the feature have been established.'
          Stakeholder:
            understanding: 'You have a firm grasp of what the outcome of this project will be'
            targetDate: 'You have a firm grasp of when the deliverable will be ready'
        next: 'inProgress'

      inProgress:
        desc: 'Coding'
        itemsByRole:
          Owner:
            tested: 'You have run all tests in staging'
            published: 'The feature is live'
          Stakeholder: {}
        next: 'testing'

      testing:
        desc: 'Coding'
        itemsByRole:
          Owner:
            tested: 'You have run all tests in staging'
            published: 'The feature is live'
          Stakeholder: {}
        next: 'complete'

      complete:
        desc: 'Production'
        next: undefined
        itemsByRole:
          Owner:
            highfiveBiz: 'You have high-fived your biz-buddy'
          Stakeholder:
            highfiveDev: 'You have high-fived your dev-buddy'

    Config:
      startState: 'requirements'

  updateCheckbox = (event) ->
    feature = getFeature event.target
    if not feature
      throw new Error "Can't find feature from event.target"
    feature.items = feature.items or {}
    feature.items[event.target.name] = checked(event.target)
    complete = true
    for role, items of Workflow.States[feature.state].itemsByRole
      for item of items
        if not feature.items[item]
          complete = false
          break

    if complete
      feature.state = Workflow.States[feature.state].next

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

  @itemsHelperMaker = (role) ->
    (context, options) ->
      if not @_id or not @owner
        throw new Error "This doesn't look like a feature"
      ret = ''
      console.log "Looking for #{@state}"
      if not @state of Workflow.States
        throw new Error "Invalid state '#{@state}' found"
      for item_name, item_description of Workflow.States[@state].itemsByRole[role]
        checked_state = ''
        try
          if @items[item_name]
            checked_state = 'checked="checked"'
        catch e
        finally
        ret = ret + options.fn
          name: item_name
          description: item_description
          checked: checked_state
          ownerId: @owner?._id
          stakeholderId: @stakeholder?._id
      return ret

  Template.feature.helpers
    user: () ->
      Meteor.user()

    status: () ->
      Workflow.States[@state].desc

    dateRender: (timestamp) ->
      formatDate(timestamp)

    ownerItems: itemsHelperMaker 'Owner'
    stakeholderItems: itemsHelperMaker 'Stakeholder'

    ifOwner: (context, options) ->
      if Meteor.user()._id is @ownerId
        return options.fn @
      else
        return options.inverse @

    ifStakeholder: (context, options) ->
      if Meteor.user()._id is @stakeholderId
        return options.fn @
      else
        return options.inverse @

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
        owner: Meteor.user()
        state: Workflow.Config.startState
        items: {}
      Features.insert feature, (obj, _id) ->
        if typeof obj is 'undefined'
          log 'info', "feature logged '#{_id}'"
        else
          log 'warning', 'error inserting a new feature'

  @Features = Features
  @Workflow = Workflow
  @formatDate = formatDate
  @dumpColl = dumpColl

  # Finally, subscribe to the features collection
  Meteor.subscribe 'features'


if Meteor.isServer

  # Set up settings around user validation
  if not Meteor.settings.validDomain
    console.log "!!! Unabled to find Meteor.settings.validDomain"

  Meteor.settings.whitelist = ([].concat Meteor.settings.whitelist).sort()

  endsWith = (string, suffix) ->
      string.indexOf(suffix, string.length - suffix.length) isnt -1

  validUserByEmail = (user) ->
    email = user?.services?.google?.email
    if email
      if endsWith email, "@#{Meteor.settings.validDomain}"
        return true
      if (_.indexOf Meteor.settings.whitelist, email, true) isnt -1
        return true
    return false

  # Setup security features
  Meteor.users.deny
    update: () ->
      return true

  Meteor.publish 'features', () ->
    user = Meteor.users.findOne @userId
    if validUserByEmail user
      console.log "Publishing to user #{user.profile.name} <#{user.services.google.email}>"
      return Features.find()
    else
      console.log "Not publishing to user #{user.profile.name} <#{user.services.google.email}>"
      return undefined

  Accounts.validateNewUser (user) ->
    if validUserByEmail user
      return true
    throw new Meteor.Error 403, "Sorry, you are not allowed to have access to this site."

  Features.allow
    insert: (userId, doc) ->
      return validUserByEmail Meteor.users.findOne userId
    update: (userId, doc, fieldNames, modifier) ->
      return validUserByEmail Meteor.users.findOne userId
    remove: (userId, doc) ->
      return validUserByEmail Meteor.users.findOne userId

  Meteor.startup ->
    # code to run on server at startup
