# AnyCards -- A multi-person card game with no built-in rules

This repository contains the Swift language source for an iOS (iPad-preferred) multi-person game.

## The Game

The game will provide a deck of cards (not necessarily a standard one, the selection to be made by the initiating user).  The players use their separate iPads to play a card game with the cards.  The players have a common view of a playing surface and each player may optionally have a private hand.  The game provides for an orderly succession of turns but does not otherwise build in the rules of any particular card game.  It will support the playing of a wide variety of games (those that don't require non-card accessories such as chips or a specialized scoring board).   Score-keeping will be supported but will be somewhat ad hoc.  Human-to-human communication is TBD but will probably just use a voice channel.

App-to-app communication is somewhat pluggable.   It is currently implemented only for Apple Multi-peer, requiring proximity (in which case no voice channel support will be needed).   There was a planned plugin for using Apple Game Center to support the communication, but it does not exist yet and may not, because testing with game center servers has historically been unreliable.   The current plan is to field a third plugin that will use a serverless backend hosted by [Nimbella](https://nimbella.com) to keep game state in a key-value store and manage the player coordination.   Neither the Apple Game Center nor the Nimbella stack will directly support a voice channel so that will have to be designed separately and only loosely integrated with the rest of the app.

## Status

The game is currently under development and may or may not be useful in its current form.

## Distribution

The game is not in the Apple app store and I have not decided yet whether to publish it there.  Since this is open source, I may use Apple's ad hoc distribution recommendations instead of publishing it.

## License, contributions

The code in the repository is covered by the [Apache license](http://www.apache.org/licenses/LICENSE-2.0).  I am setting up an issue tracker but do not yet have a policy about accepting contributions.   If you fork this repository, have useful changes, and wish to contribute them, please open an issue and I will come up with a policy for handling PRs.
