# Author: mvdw 
# Mail: <mvdw at airmail dot cc>
# Distributed under terms of the GNU2 license.

# A test that:
# 1) Makes a client
# 2) Shows all the clients. 
# 3) Shows the content of the recently created client.
# 4) Removes that client again.
# 5) Shows all the clients. 
testCreate = ->
    db.client.create({name:"foo", password:"bar", email:"foo@bar.com"})
    .then (x) ->
        db.client.all()
        .then (y) ->
            console.log y
            db.client.one(y[-1..])
            .then (z) ->
                console.log z
                redis.get("client:#{z.email}")
                .then (o) ->
                    console.log '->', z.email, o
                db.client.remove(y[-1..])
                .then (a) ->
                    console.log a, y[-1..]
                    db.client.all()
                    .then (b) ->
                        console.log b
# A test that:
# 1) Makes a client
# 2) Shows all the clients. 
# 3) Shows the content of the recently created client.
# 4) Validates their password like a new auth request.
# 5) Indicate if you succeeded or not.
# 6) Remove that client again.
# 7) Shows all the clients. 
testAuth = ->
    db.client.create({name:"foo", password:"bar", email:"foo@bar.com"})
    .then (x) ->
        db.client.all()
        .then (y) ->
            console.log y
            db.client.one(y[-1..])
            .then (z) ->
                console.log z
                db.client.authenticate('foo@bar.com', 'bar')
                .then (result) ->
                    console.log '1 is authed, 0 is failed -> ', result
                .catch (error) ->
                    console.log 'memes ->', error
                console.log 'passed ->'
                db.client.remove(y[-1..])
                .then (a) ->
                    console.log a, y[-1..]
                    db.client.all()
                    .then (b) ->
                        console.log b
# A test that:
# 1) Makes a client
# 2) Shows all the clients.
# 3) Shows the content of the recently created client
# 4) Update that client with a value.
# 5) Shows the content of the recently created client
# 6) Removes that client again.
# 7) Shows all the clients.
testUpdate = ->
    db.client.create({name:"foo", password:"bar", email:"foo@bar.com"})
    .then (x) ->
        db.client.all()
        .then (y) ->
            console.log y
            db.client.one(y[-1..])
            .then (z) ->
                console.log z
                db.client.update(y[-1..],{name: 'blep'})
                .then (a) ->
                    console.log a, y[-1..]
                    db.client.one(y[-1..])
                    .then (b) ->
                        console.log b
                        db.client.remove(y[-1..])
                        .then (c) ->
                            console.log c, y[-1..]
                            db.client.all()
                            .then (d) ->
                                console.log d

#db.ticket.create(5, {title:'hi', description:'about'})
#.then (x) ->
#    console.log x
#.catch (x) ->
#    console.log x

#db.ticket.remove(1)
#.then (x) ->
#    console.log x
#.catch (y) ->
#    console.log y

#db.ticket.update(1, {title:'kek'})
#.then (x) ->
#    console.log x
#.catch (y) ->
#    console.log y
#

db.ticket.one(1)
.then (x) ->
    console.log x
.catch (y) ->
    console.log y

