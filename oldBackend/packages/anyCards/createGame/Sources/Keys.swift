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

import RediStack
import Foundation

// Contains some convenience functions for making the redis keys needed by anyCards actions.

// The all players key stores the players of the game as a redis "hash".
func allPlayersKey(_ gameToken: String) -> RedisKey {
    return RedisKey("game_\(gameToken)_players")
}

// The state key stores the latest posted GameState structure for the game.  It is stored
// as a String (containing JSON).  The action doesn't interpret it at all, just stores it.
func stateKey(_ gameToken: String) -> RedisKey {
    return RedisKey("game_\(gameToken)_state")
}

// The cleanup key stores the epoch time of the last time cleanup was run.  Cleanup removes
// players that have not been heard from "recently enough" (as defined by the cleanup functions).
func cleanupKey(_ gameToken: String) -> RedisKey {
    return RedisKey("game_\(gameToken)_cleanup")
}

// An individual player key is defined within the redis hash stored at the all players key
// The key value is the player "order" string (a random Int32 number converted to a String).
// The value is hte epoch time of the last time the player polled for information about the game.
// This is used to determine whether the player is "still connected" to the game.
func playerKey(_ order: String) -> RedisHashFieldKey {
    return RedisHashFieldKey(order)
}
