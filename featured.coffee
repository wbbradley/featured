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
        name: 'Stakeholder'
        desc: 'Person assigned to ensure product value, usability and market readiness'

    States:
      requirements:
        desc: 'Requirements Gathering'
        itemsByRole:
          Owner:
            owner: 'Dev Owner of the feature has been established'
            stakeholder: 'Key Stakeholders of the feature have been established.'
            requirements: 'Requirements have been gathered'
            mvp: 'Minimum viable product has been presented'
            successOwner: 'Success is well understood'
            targetDateReq: 'A target date is established'
          Stakeholder:
            established: 'This feature aligns with positive business value'
            goals: 'You understand and have expressed clearly the goals of the feature'
            mvpApproval: 'Minimum viable product has been approved'
            nongoals: 'You understand and have expressed clearly the non-goals of the feature'
            successStakeholder: 'Success is well understood'
            targetDateReqApproved: 'Target date makes sense but understand it may still change'
        next: 'design'

      design:
        desc: 'Design'
        itemsByRole:
          Owner:
            design: 'UX Design has been assembled.'
            assetsReq: 'Visual requirements or other required assets have been identified'
            deliverable: 'Requirements have been gathered from are entered into tracking software'
            estimates: 'Estimates are entered into tracking software'
            testGoalsSet: "Test goals have been established and shared"
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
            testsWritten: "You met testing goals around this product"
            demoed: 'Code is complete and has been demoed to at least one stakeholder'
            cleanup: 'You removed excess print statements, and DEBUG code'
            published: 'The feature is live'
          Stakeholder:
            seenDemo: 'You reviewed the complete product either on the staging server, or on the developer\'s computer'
        next: 'preProduction'

      preProduction:
        desc: 'Go Mode'
        itemsByRole:
          Owner:
            merged: "You merged the target branch (master) into your branch"
            codeReview: "You had a final code review"
            finalDemo: "You completed a final demo"
          Stakeholder:
            seenFinalDemo: 'You reviewed the complete product either on the staging server, or on the developer\'s computer'

      production:
        desc: 'Go Mode'
        itemsByRole:
          Owner:
            merged: "You've merged the target branch (master) into your branch"
            codeReview: "You've had a final code review"
            finalDemo: "You've completed a final demo"
            pushToProduction: "Pushed code to production"
            published: 'The feature is live'
            liveTest: "You've run through your test matrix with the live production code"
          Stakeholder:
            seenLive: "You\'ve reviewed the live changes"
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
    feature.items or= {}
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

  becomeStakeholder = (event) ->
    feature = getFeature event.target
    if not feature
      throw new Error "Can't find feature from event.target"
    userId = Meteor.user()._id
    if feature.stakeholderIds.indexOf(userId) is -1
      feature.stakeholderIds.push userId

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
    'click button[name=feature-stakeholder-grab]': becomeStakeholder

  Template.feature.events events

  @itemsHelperMaker = (role) ->
    (context, options) ->
      if not @_id or not @ownerId
        throw new Error "This doesn't look like a feature"
      ret = ''
      if @state is undefined
        return ""
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
          ownerId: @ownerId
          stakeholderIds: @stakeholderIds
      return ret

  Template.feature.helpers
    user: () ->
      Meteor.user()

    progress: () ->
      count = 0
      total = 0
      for state_name, state_desc of Workflow.States
        for role, items of state_desc.itemsByRole
          for name of items
            total = total + 1
            if @items[name]
              count = count + 1
      return "#{Math.floor(count * 100 / total)}%"
    username: (userId) ->
      user = Meteor.users.findOne userId
      if user
        return user.profile.name
      else
        return '<Unknown>'

    status: () ->
      Workflow.States[@state]?.desc or ""

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
      if @stakeholderIds.indexOf(Meteor.user()._id) isnt -1
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
        ownerId: Meteor.user()._id
        stakeholderIds: []
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
  Meteor.subscribe 'users'


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
      if _.indexOf(Meteor.settings.whitelist, email, true) isnt -1
        return true
    return false

  # Setup security features
  Meteor.users.deny
    update: () ->
      return true

  Meteor.publish 'users', () ->
    user = Meteor.users.findOne @userId
    if validUserByEmail user
      return Meteor.users.find()
    else
      return undefined

  Meteor.publish 'features', () ->
    user = Meteor.users.findOne @userId
    if validUserByEmail user
      return Features.find()
    else
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
