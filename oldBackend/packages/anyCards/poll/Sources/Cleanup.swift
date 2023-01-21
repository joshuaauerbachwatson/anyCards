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

// Contains functions for managing the cleanup of departed players from games and the cleanup
// of the entire game state when the game has no players.

// Check if cleanup needs to be run and run it if so
func maybeRunCleanup(_ client: RedisClient, _ gameToken: String) {
    let cleanupString = try? client.get(cleanupKey(gameToken)).wait()?.string
    if cleanupNeeded(cleanupString) {
        // Run cleanup
        let allPlayersKey = allPlayersKey(gameToken)
        guard let playerKeys = try? client.send(RedisCommand<[RedisHashFieldKey]>.hkeys(
               in: allPlayersKey)).wait() else {
            return
        }
        let now = Date().timeIntervalSinceReferenceDate
        for key in playerKeys {
            let lastSeen = try? client.send(RedisCommand<RESPValue>.hget(key, from: allPlayersKey)).wait()?.string
            if cleanupNeeded(lastSeen, now) {
                _ = try? client.send(RedisCommand<Int>.hdel(key, from: allPlayersKey)).wait()
            }
        }
    }
}

// A conventional representation of the current time
func currentTime() -> String {
    return String(Date().timeIntervalSinceReferenceDate)
}

// Predicate to determine if cleanup needs to be run (in general or if a specific player is stale)
// The cleanup String argument is an epoch time in the past as a String.  The optional second argument
// is the epoch time now (may be passed in to avoid too many Date() constructions)
func cleanupNeeded(_ cleanupString: String?, _ now: Double? = nil) -> Bool {
    guard let cleanup = cleanupString, let lastCleanup = Double(cleanup) else {
        return true
    }
    let cleanupAge = (now ?? Date().timeIntervalSinceReferenceDate) - lastCleanup
    return cleanupAge < 30.0
}
