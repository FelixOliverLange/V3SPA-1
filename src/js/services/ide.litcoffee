    mod = angular.module 'vespa.services'


A service designed to encapulate all of the data interaction
required by the IDE. Responsible for making queries, understanding
errors, and generally being awesome.

    mod.service 'IDEBackend',
      class IDEBackend
        constructor: (@VespaLogger, @$rootScope,
        @SockJSService, @$q)->

          @current_policy = 
            application: ""
            dsl: ""
            json: null
            id: null
            dbid: null
            valid: false

          @hooks = 
            dsl_changed: []
            app_changed: []
            json_changed: []
            validate_error: []

Add a hook on certain changes in the backend. The action
will be called as appropriate.

        add_hook: (event, action)=>
          @hooks[event] ?= []
          @hooks[event].push(action)
          console.log("Hooks for #{event} are now:")
          console.log(@hooks[event])

        unhook: (event, action)=>
          @hooks[event] = _.filter @hooks[event], (hook_fn)->
            action != hook_fn
          console.log("Hooks for #{event} are now:")
          console.log(@hooks[event])

An easy handle to update the stored representation of
the DSL. Any required callbacks (like updating the
application representation) can be done from here

        update_dsl: (newtext)=>
          @current_policy.dsl = newtext

Return the JSON representation if valid, and null if it is
invalid

        get_json: =>
          if @current_policy.valid
            return @current_policy.json

Send a request to the server to validate the current
contents of @current_policy

        validate_dsl: =>
          deferred = @$q.defer()

          req =
            domain: 'lobster'
            request: 'validate'
            payload: @current_policy.dsl

          @SockJSService.send req, (result)=>
            if result.error  # Service error
              deferred.reject result.payload

            else  # valid response. Must parse
              @current_policy.json = JSON.parse result.payload
              if @current_policy.json.errors.length > 0
                @current_policy.valid = false
                for hook in @hooks.validate_error
                  hook(@current_policy.json.errors)

              else
                @current_policy.valid = true
                _.each @hooks.json_changed, (hook)=>
                  hook(@current_policy.json)

              deferred.resolve()

          return deferred.promise

Load a policy from the server

        load_policy: (id)=>
          deferred = @$q.defer()

          req = 
            domain: 'policy'
            request: 'get'
            payload: id

          @SockJSService.send req, (data)=>
            if data.error
              deferred.reject(data.payload)

            @current_policy.application = data.payload.application
            @current_policy.dsl = data.payload.dsl
            @current_policy.dbid = data.payload._id.$oid
            @current_policy.id = data.payload.id
            @current_policy.valid = false

            for hook in @hooks.dsl_changed
              hook(@current_policy.dsl)

            for hook in @hooks.app_changed
              hook(@current_policy.application)

            $.growl 
              title: "Loaded"
              message: "#{@current_policy.id}"

            deferred.resolve(@current_policy)

          return deferred.promise

Save a modified policy to the server

        save_policy: =>
          throw new Error("not yet implemented")

Upload a new policy to the server

        upload_policy: (data)=>

