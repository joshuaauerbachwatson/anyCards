/*
 * Copyright (c) 2021-present, Joshua Auerbach
 *
 * Licensed to the Apache Software Foundation (ASF) under one or more
 * contributor license agreements.  See the NOTICE file distributed with
 * this work for additional information regarding copyright ownership.
 * The ASF licenses this file to You under the Apache License, Version 2.0
 * (the "License"); you may not use this file except in compliance with
 * the License.  You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import nimbella_key_value
import RediStack
import Foundation

// Source for the poll Action.  This action is issued by the app every 2 seconds.  It
//   is both the means by which we know that the app is still running and also the means
//   by which the app's state is updated with the latest information.
// Inputs: gameToken - a token giving access to the game
//         player - the player's "order number" (an all-numeric String) which serves as a unique id
// Outputs: players - the list of all active players as a blank separated string containing order numbers
//          gameState - the GameState structure as a JSON-encoded string
// Note that the player list appears twice.  As part of the GameState, each player is represented by a
// Player object (which pairs a human-oriented name with the order string).   Players are sorted by "order"
// which gives the order of play in the game.  In the independent "players" string returned by this
// action, players are represented only by their order number.   The string is not necessarily sorted by
// order.  The two views can differ but each executing app should strive to reconcile them such that they
// are eventually consistent.
func main(args: [String:Any]) -> [String:Any] {
    guard let gameToken = args["gameToken"] as? String else {
        return [ "error": "gameToken argument is required by this action" ]
    }
    guard let player = args["player"] as? String else {
        return [ "error": "player argument is required by this action" ]
    }
    do {
        let client = try redis()
        // Enter the timestamp for the polling player
        _ = try client.send(RedisCommand<Int>.hset(playerKey(player), to: currentTime(),
                                                   in: allPlayersKey(gameToken))).wait()
        // Determine if cleanup is to be run and run it if so
        maybeRunCleanup(client, gameToken)
        // Get the players into the right form
        let playerKeys = try client.send(RedisCommand<[RedisHashFieldKey]>.hkeys(in: allPlayersKey(gameToken))).wait()
        let playerStrings: [String] = playerKeys.map { $0.rawValue }
        let players = playerStrings.joined(separator: " ")
        // Get the GameState as well
        let gameState = try client.get(stateKey(gameToken)).wait()?.string ?? ""
        return [ "players": players, "gameState": gameState ]
    } catch {
        return [ "error": "\(error)"]
    }
}
