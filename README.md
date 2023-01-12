# AnyCards -- A multi-person card game with no built-in rules

This repository contains the Swift language source for an iOS (iPad-preferred) multi-person game.

## The Game

The game will provide a deck of cards (not necessarily a standard one, the selection to be made by the initiating user).  The players use their separate iPads to play a card game with the cards.  The players have a common view of a playing surface and each player may optionally have a private hand.  The game provides for an orderly succession of turns but does not otherwise build in the rules of any particular card game.  It will support the playing of a wide variety of games (those that don't require non-card accessories such as chips, or non-card-based moves such as bidding).

## Evolutionary Thoughts

### Pluggable Game Rules

I originally thought this "no built-in rules" idea was neat but I now fear that it makes the game too amorphous, and pushes in the direction of requiring more communication channels (voice or text) so that players can make decisions about what to play, etc.  So, I will explore the idea of "pluggable rule sets" so that AnyCards can be initiated to play a specific game (Gin Rummy, Old Maid, War ...).  The initiating user simple chooses from a menu of game offerings and the chosen game is part of the invitation sent to other players.

### Pluggable UI?

I also think the limitation to card games with no non-card elements is too narrow.  It not only precludes all non-card games but also card games like poker or bridge that have betting or bidding phases.   But, of course, to support arbitrary games means having arbitrary UIs; to support that, means evolving toward a complete game construction framework.  I'm not ready to tackle that, but, a more modest idea (multiple more or less independenty developed games with distinct UIs sharing the backend) synergizes with some of the ideas in the next section.

### Greater Role for the Backend

Right now, the game is a peer distributed system.  Each instance of the app is its own model-view-controller engine and the backend (if any) is just acting as a multicast service.  What is multicast is a sequence of game states.  The only rule (whose turn it is) is enforced in the apps, not the backend.

In fact, the only working embodiment of the game today uses Apple Multi-peer communication.  A version using a serverless backend hosted by Nimbella was implemented but I didn't quite get it working before Nimbella shut down.

I could easily migrate the existing backend to DigitalOcean Functions but I don't actually think serverless is the right model for this.  It requires the apps to poll for new state constantly, since you can't hold a connection open with serverless.  It requires some sort of database (I used Redis in the Nimbella implementation) to hold the game state. If I ran a more conventional server, information could be "pushed" more like a pub-sub system.  I could keep game state in memory.  The occasional server crash would wipe out only the current ongoing games.

Of course, there is _some_ state besides the state of the active games.  This consists of player identities and authentication information.  Here I would explore offloading as much as possible of that to third-party service like Auth0.  A server crash would lose records of any bearer tokens that had been issued and force everyone to login again via the third-party service.  I think that will prove to be workable but we'll have to see.

Once we standardize on a "real" backend server, it is possible to give it a greater role.  The plugin structure for rule sets could reside in the server, rather than in the apps.  The apps would still have a model-view-controller structure, but the controller would have a client relationship with the backend.   A new game state would have to be submitted to the backend for validation before being reflected to the view.  Thus, I could, over time, offer more card games simply by updating the server and without having to issue new apps.  New apps are only required when new views and new UI controls are needed to support the new games.  For example, to add bridge or poker we'd need UI controls for bids and bets.  To support non-card games, we'd need non-card-based UIs, etc.  Specializing the front-end for new games will be a later follow-on, not something I'm about to do.

### Backend Implementation Language and Source Control

The Nimbella serveress backend was written in Swift.  I thought it would be cool to write the frontend and backend in the same language.  I now see that there is little benefit from this language similarity.  Swift on Linux is not fully mature and I found it hard to maintain and evolve the backend when it was written in a language not well suited to the task.  I will write the new backend in either TypeScript or Go.

The Nimbella backend is actually sourced from the this repository (in a distinct directory not covered by the top-level `xcode` project file).  I am not decided on whether to continue this "monorepo" approach or not for the new backend.

## Status

At this moment, the game can actually be built and played in its one working form (using Apple Multi-peer communication).  However, as I start ripping it apart and instituting the changes outlined in the previous section, it is likely to go through a period of not working at all.  Once I get the backend server up and running and have some solution for user identity management and authentication, it will become playable again with the most permissive "rule set" (order of play but no other rules).  Adding other rule sets will be gradual.

## Distribution

The game is not in the Apple app store and I have not decided yet whether to publish it there.  Since this is open source, I may use Apple's ad hoc distribution recommendations instead of publishing it.

## License, contributions

The code in the repository is covered by the [Apache license](http://www.apache.org/licenses/LICENSE-2.0).  There is an issue tracker but no policy about accepting contributions.   If you fork this repository, have useful changes, and wish to contribute them, please open an issue and I will come up with a policy for handling PRs.
