# AnyCards -- A multi-person card game with no built-in rules

This repository contains the Swift language source for an iOS multi-person game.  Each player uses his own device.  iPads are preferred for the best experience but modern iPhones (with reasonable screen resolution) work as well.

This respository also contains the Go language source for an optional backend, allowing the game to be played by geographically dispersed players.  The game may also be played by players in proximity without the need for a server.

## The Game

The game provides a deck of cards (not necessarily a standard one, the selection to be made by the user who is first to play).  The players use their separate devices to play a card game with the cards.  The players have a common view of a playing surface and each player may optionally have a private hand.  The game provides for an orderly succession of turns but does not otherwise build in the rules of any particular card game.  It will support the playing of a wide variety of games (those that don't require non-card accessories such as chips, or non-card-based moves such as bidding).  Achieving agreement about what game to play and enforcing its rules may require voice or message contact between players (not provided by the game).

## Building the Game App from Source

It is possible to build both the iOS and the backend portions of the game from source but you are then on your own figuring out where to deploy the server and how to distribute the iOS portion.  Authentication between the app and the backend involves a secret that is not committed to this repo.  It must be compiled into the app and be present in the environment of the server when the server is started.   You can use a random string for your secret but that ties the app you build to the server you deploy.

To build the app, you will need XCode.  Simply open XCode on the provided folder `anyCards.xcodeproj`.  You will see that there is a file, `Secrets.swift` that is defined to the project but not present in the repo.  You must add this file in order to build.  The file must define the two `String` constants `ActionRoot` and `AppToken`.  If you do not intend to use the server (play only in proximity) the values do not matter (creation of server based games will then fail).   To play with a server, the `ActionRoot` must be the `https` URL where the server can be contacted and the `AppToken` must be a random string of characters that you will make available to the server.

To build the server, you need `go` version (at least) `1.19`.  Simply build it with `go build`.  Deploying the resulting server is beyond the scope of this document but should be straightforward using various available cloud services.

## Obtaining the game from me and using my server

For a while I had a beta of this app available in TestFlight.  However, that build has expired.  Since I am not actively working on the app, I decided not to push out new builds under the beta for a while.   Once I resume doing that, it will be possible to install via TestFlight.  The beta app will use a secret compatible with a copy of the server that I have deployed.  If you are interested in trying the app as a user, let me know.

## Evolutionary Thoughts

### Pluggable Game Rules

I originally thought this "no built-in rules" idea was neat but I now fear that it makes the game too amorphous, and pushes in the direction of requiring more communication channels (voice or text) so that players can make decisions about what to play, etc.  So, I will explore the idea of "pluggable rule sets" so that AnyCards can be initiated to play a specific game (Gin Rummy, Old Maid, War ...).  The initiating user simple chooses from a menu of game offerings and the chosen game is part of the invitation sent to other players.

### Greater Role for the Backend

Right now, the game is a peer distributed system.  Each instance of the app is its own model-view-controller engine and the backend is just acting as a multicast service.  What is multicast is a sequence of game states.  The only rule (whose turn it is) is enforced in the apps, not the backend.

It is possible to give the server a greater role.  The plugin structure for rule sets could reside in the server, rather than in the apps.  The apps would still have a model-view-controller structure, but the controller would have a client relationship with the backend.   A new game state would have to be submitted to the backend for validation before being reflected to the view.  Thus, I could, over time, offer more card games simply by updating the server and without having to issue new apps.  New apps are only required when new views and new UI controls are needed to support the new games.  For example, to add bridge or poker we'd need UI controls for bids and bets. Specializing the front-end for new games will be a later follow-on, not something I'm about to do.

## License, contributions

The code in the repository is covered by the [Apache license](http://www.apache.org/licenses/LICENSE-2.0).  There is an issue tracker but no policy about accepting contributions.   If you fork this repository, have useful changes, and wish to contribute them, please open an issue and I will come up with a policy for handling PRs.
