# AnyCards -- A multi-person card game with no built-in rules

This repository contains the Swift language source for an iOS multi-person game.  Each player uses his own device.  iPads are preferred for the best experience but modern iPhones (with reasonable screen resolution) work as well.

Historically, AnyCards was a monolithic app but it has been redone to use the [unigame](https://github.com/joshuaauerbachwatson/unigame) framework.  That framework was split off from AnyCards when I realized that it could be easily reused for other games.

## The Game

The game provides a deck of cards (not necessarily a standard one, the selection to be made by the user who is first to play).  The players use their separate devices to play a card game with the cards.  The players have a common view of a playing surface and each player may optionally have a private hand.  The game provides for an orderly succession of turns but does not otherwise build in the rules of any particular card game.  It will support the playing of a wide variety of games (those that don't require non-card accessories such as chips, or non-card-based moves such as bidding).  Achieving agreement about what game to play and enforcing its rules may require voice or message contact between players (not provided by the game).

## License, contributions

The code in the repository is covered by the [Apache license](http://www.apache.org/licenses/LICENSE-2.0).  There is an issue tracker but no policy about accepting contributions.   If you fork this repository, have useful changes, and wish to contribute them, please open an issue and I will come up with a policy for handling PRs.
