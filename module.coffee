#
# Author: mvdw
# Mail: <mvdw at airmail dot cc>
# Distributed under terms of the GNU2 license.
#

Redis       = require 'ioredis'
Q           = require 'q'
Crypto      = require 'crypto'

redis       = new Redis()

db =
    options:
        priorities:
            ["High", "Normal", "Low"]

        priority:
            "High": "danger",
            "Normal": "primary"
            "Low": "default"

        statuses:
            ["In Progress", "Closed", "Open", "Rejected"]

        status:
            "In Progress": "warning"
            "Closed": "default"
            "Open": "success"
            "Rejected": "danger"

        workers:
            ["Mirko", "Terence", "Joey", "Steven"]

    client:
        authenticate: (email, password) ->
            "use strict"

            defer = Q.defer()

            # Retrieve the client uid which contains all the userdata.
            redis.get("client:#{email}")
            .then (uid) ->
                # The client doesn't exist.
                if uid is null
                    return defer.reject new Error "Your email cannot be found in our database"

                # Retrieve the hash that contains the userdata.
                redis.hgetall("client:#{uid}")
                .then (client) ->
                    # The client suddenly stopped existing. This means there is
                    # a client -> uid mismatch and well. That's fucked up.
                    if client is null
                        return defer.reject new Error "We fucked up badly. Contact us. Really"

                    # Salt the supplied password.
                    password = Crypto.createHash('sha256').update(password + client.salt).digest('hex')

                    client.id = uid

                    # Validate the supplied (hashed) password with the saved hash.
                    if password is client.password
                        defer.resolve client
                    else
                        defer.resolve null

                .catch (error) -> return defer.reject error
            .catch (error) -> return defer.reject error

            defer.promise

        update: (uid, attributes) ->
            "use strict"

            result = {}
            defer = Q.defer()

            # The functions that 'validate's wheter we went through all the attributes.
            validate = ->
                counter = (counter or 0) + 1
                if counter is Object.keys(attributes).length
                    defer.resolve result

            # Retrieve the hash that contains the userdata.
            redis.hgetall "client:#{uid}"
            .then (client) ->
                # If the client doesn't exist.
                if client is null
                    return defer.reject new Error "Client does not exist"

                result = client

                # For every attribute in attributes.
                for attribute of attributes
                    # Update or add to the client hash (db).
                    redis.hset("client:#{uid}", attribute, attributes[attribute])
                    # Update or add to the client hash (local).
                    result[attribute] = attributes[attribute]

                    validate()

            .catch (error) -> return defer.reject error

            defer.promise
        remove: (uid) ->
            "use strict"

            defer = Q.defer()

            redis.hgetall "client:#{uid}"
            .then (client) ->
                # Make sure that the client actually exists.
                if Object.keys(client).length is 0 or client is null
                    return defer.reject new Error "You can't delete what doesn't exist."

                # Delete the userdata hash.
                redis.del "client:#{uid}"
                .then (result) ->
                    # Delete the reference link between the uid and the userdata.
                    redis.del "client:#{client.email}"
                    .then (result) ->
                        # Delete the client for the set of client entries.
                        redis.srem "clients", uid
                        .then (result) ->
                           # Decrease the total user counter.
                            redis.decr "client:count"
                            .then (result) ->
                                defer.resolve 1
                           .catch (error) -> return defer.reject error
                        .catch (error) -> return defer.reject error
                    .catch (error) -> return defer.reject error
                .catch (error) -> return defer.reject error
            .catch (error) -> return defer.reject error

            defer.promise

        create: (client) ->
            "use strict"

            defer = Q.defer()

            # Retrieve the client count so we know what uid to assign.
            redis.get "client:count"
            .then (uid) ->
                # Set the uid when not set.
                if uid is null or uid < 0
                    uid = 0
                    redis.set "client:count", uid

                redis.get "client:#{client.email}"
                .then (email) ->
                    # We need to make sure the email doesn't exist (is null)
                    if email isnt null
                        return defer.reject new Error "Email already exists."

                    redis.hlen "client:#{uid}"
                    .then (hash) ->
                        # We also need to make sure the uid isn't taken yet.
                        # This is to be sure and should never really trigger.
                        if hash isnt 0
                            return defer.reject new Error "Hash already exists."

                        # Create the salt and hash.
                        client.salt = Crypto.pseudoRandomBytes(20).toString('hex')
                        client.password = Crypto.createHash('sha256').update(client.password + client.salt).digest('hex')

                        # Apply the client object as a hash.
                        redis.hmset "client:#{uid}", client
                        .then (result) ->
                            # Create the reference link between the uid and the userdata.
                            redis.set "client:#{client.email}", uid
                            .then (result) ->
                                # Append the client for the set of client entries.
                                redis.sadd "clients", uid
                                .then (result) ->
                                    # Increase the total user counter.
                                    redis.incr "client:count"
                                    .then (result) ->
                                        defer.resolve client
                                    .catch (error) -> return defer.reject error
                                .catch (error) -> return defer.reject error
                            .catch (error) -> return defer.reject error
                        .catch (error) -> return defer.reject error
                    .catch (error) -> return defer.reject error
                .catch (error) -> return defer.reject error
            .catch (error) -> return defer.reject error

            defer.promise

        get: (uid, attribute) ->
            "use strict"

            defer = Q.defer()

            redis.hgetall "client:#{uid}"
            .then (keys) ->
                keys.id = uid
                if attribute?
                    defer.resolve keys[attribute]
                else
                    defer.resolve keys
            .catch (error) -> return defer.reject error

            defer.promise

        all: ->
            "use strict"

            defer = Q.defer()

            redis.smembers "clients"
            .then (list) ->
                defer.resolve list
            .catch (error) -> return defer.reject error

            defer.promise

    ticket:
        create: (ticket, uid) ->
            "use strict"

            defer = Q.defer()

            redis.get "ticket:count"
            .then (tid) ->
                if tid is null or tid < 0
                    tid = 0
                    redis.set "ticket:count", tid

                ticket.created = "#{new Date().toLocaleDateString()} #{new Date().toLocaleTimeString()}"
                ticket.updated = "#{new Date().toLocaleDateString()} #{new Date().toLocaleTimeString()}"
                ticket.status = "Open"
                ticket.assigned = ""
                ticket.client = uid

                redis.sadd "client:#{uid}:ticket", tid
                .then (result) ->
                    redis.hmset "ticket:#{tid}", ticket
                    .then (result) ->
                        redis.sadd "tickets", tid
                        .then (result) ->
                            redis.incr "ticket:count"
                            .then (result) ->
                                defer.resolve ticket
                            .catch (error) -> return defer.reject error
                        .catch (error) -> return defer.reject error
                    .catch (error) -> return defer.reject error
                .catch (error) -> return defer.reject error
            .catch (error) -> return defer.reject error

            defer.promise

        remove: (tid) ->
            "use strict"

            defer = Q.defer()

            redis.hgetall "ticket:#{tid}"
            .then (ticket) ->
                # Make sure that the client actually exists.
                if Object.keys(ticket).length is 0 or ticket is null
                    return defer.reject new Error "You can't delete what doesn't exist."

                redis.srem "client:#{ticket.client}:ticket", tid
                .then (result) ->
                    redis.srem "tickets", tid
                    .then (result) ->
                        redis.del "ticket:#{tid}"
                        .then (result) ->
                            redis.decr "ticket:count"
                            .then (result) ->
                                defer.resolve 1
                            .catch (error) -> return defer.reject error
                        .catch (error) -> return defer.reject error
                    .catch (error) -> return defer.reject error
                .catch (error) -> return defer.reject error
            .catch (error) -> return defer.reject error

            defer.promise

        update: (tid, attributes) ->
            "use strict"

            result = {}
            pcom = []
            defer = Q.defer()

            # The functions that 'validate's wheter we went through all the attributes.
            validate = ->
                counter = (counter or 0) + 1
                if counter is Object.keys(attributes).length
                    defer.resolve result

            # Retrieve the hash that contains the userdata.
            redis.hgetall "ticket:#{tid}"
            .then (ticket) ->
                # If the client doesn't exist.
                if ticket is null
                    return defer.reject new Error "Ticket does not exist"

                result = ticket

                attributes.updated = "#{new Date().toLocaleDateString()} #{new Date().toLocaleTimeString()}"

                # For every attribute in attributes.
                for attribute of attributes
                    # Update or add to the client hash (db).
                    pcom.push(redis.hset("ticket:#{tid}", attribute, attributes[attribute]))
                    # Update or add to the client hash (local).
                    result[attribute] = attributes[attribute]
                Q.all(pcom)
                .then (data) ->
                    defer.resolve(result)
                .catch (error) -> return defer.reject error


            .catch (error) -> return defer.reject error

            defer.promise

        get: (tid, attribute) ->
            "use strict"

            defer = Q.defer()

            redis.hgetall "ticket:#{tid}"
            .then (keys) ->
                keys.id = tid
                if attribute?
                    defer.resolve keys[attribute]
                else
                    defer.resolve keys
            .catch (error) -> return defer.reject error

            defer.promise

        all: ->
            "use strict"

            defer = Q.defer()

            redis.smembers "tickets"
            .then (list) ->
                defer.resolve list
            .catch (error) -> return defer.reject error

            defer.promise
    comment:
        from: (tid) ->
            "use strict"

            result = []
            # the comments promises
            pcom = []
            defer = Q.defer()

            validate = (m) ->
                counter = (counter or 0) + 1
                if counter is Object.keys(m).length
                    if result.length is 0
                        defer.resolve []
                    else
                        defer.resolve result

            redis.exists "ticket:#{tid}"
            .then (exists) ->
                if exists is 0
                    return defer.reject new Error "Ticket does not exist"
                redis.smembers "ticket:#{tid}:comments"
                .then (members) ->
                    if members.length is 0
                        return defer.resolve([])
                    for member in members
                        pcom.push(redis.hgetall("ticket:#{tid}:comment:#{member}"))
                    Q.all(pcom)
                    .then (comments) ->
                        defer.resolve(comments)
                    .catch (error) -> return defer.reject error
                .catch (error) -> return defer.reject error
            .catch (error) -> return defer.reject error

            defer.promise

        create: (tid, comment) ->
            "use strict"

            defer = Q.defer()

            redis.exists "ticket:#{tid}"
            .then (exists) ->
                if exists is 0
                    return defer.reject new Error "Ticket does not exist"
                comment.created = "#{new Date().toLocaleDateString()} #{new Date().toLocaleTimeString()}"
                redis.smembers "ticket:#{tid}:comments"
                .then (members) ->
                    redis.sadd "ticket:#{tid}:comments", members.length
                    .then (result) ->
                        comment.id = members.length
                        redis.hmset "ticket:#{tid}:comment:#{members.length}", comment
                        .then (result) ->
                            defer.resolve comment
                        .catch (error) -> return defer.reject error
                    .catch (error) -> return defer.reject error
                .catch (error) -> return defer.reject error
            .catch (error) -> return defer.reject error

            defer.promise

        remove: (tid, cid) ->
            "use strict"

            defer = Q.defer()

            redis.exists "ticket:#{tid}"
            .then (exists) ->
                if exists is 0
                    return defer.reject new Error "You can't delete what doesn't exist"
                redis.del "ticket:#{tid}:comment:#{cid}"
                .then (result) ->
                    redis.srem "ticket:#{tid}:comments", cid
                    .then (result) ->
                        defer.resolve 1
                    .catch (error) -> return defer.reject error
                .catch (error) -> return defer.reject error
            .catch (error) -> return defer.reject error

            defer.promise

module.exports = db
