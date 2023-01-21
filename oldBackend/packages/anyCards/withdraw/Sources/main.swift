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

// Source for the withdraw Action.
// Inputs: gameToken - the secret token for the game
//         player - the player's "order number" (an all-numeric String) which serves as a unique id
// Outputs: a success indicator
// The player is withdrawn from the game.  If it's time, cleanup is performed, which may delete
// other players.   If there are no players left in the game, the game state is deleted.  The
// cleanup key is not deleted, leaving the game capable of being "played again" by users possessing
// the token.
func main(args: [String:Any]) -> [String:Any] {
    guard let gameToken = args["gameToken"] as? String else {
        return [ "problem": "gameToken argument is required by this action" ]
    }
    guard let player = args["player"] as? String else {
        return [ "problem": "player argument is required by this action" ]
    }
    do {
        let allPlayersKey = allPlayersKey(gameToken)
        let client = try redis()
        let withdrawn = try client.send(RedisCommand<Int>.hdel(playerKey(player), from: allPlayersKey)).wait()
        if withdrawn == 0 {
            return [ "problem": "problem deleting player from game"]
        }
        // Run cleanup if appropriate
        maybeRunCleanup(client, gameToken)
        // Check if game is dormant and delete game state if so
        let numPlayers = try client.send(RedisCommand<Int>.hlen(of: allPlayersKey)).wait()
        if numPlayers == 0 {
            _ = try client.delete(stateKey(gameToken)).wait()
        }
    } catch {
        return [ "problem": "\(error)"]
    }
    return [ "success": "true" ]
}
