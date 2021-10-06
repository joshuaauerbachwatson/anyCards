/*
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

// Source for the createGame Action.
// Inputs: appToken - the value of the appToken used by the app.  Must match the environment variable ANYCARDS_APP_TOKEN.
// Outputs: gameToken - a 16 character random string to be used as a password by the calling app and other app instances
// The game is marked as existing but has no player list or game state.  These are added by other operations.
// Once a game exists, it persists even when its user list becomes empty again.  Games are deleted explicitly.
// The idea is that a "game" is really a community of users who like to play AnyCards together, and encompasses
// any number of "game sessions" that could actually be playing different kinds of games (different rules, etc.).
func main(args: [String:Any]) -> [String:Any] {
    guard let expectedToken = ProcessInfo.processInfo.environment["ANYCARDS_APP_TOKEN"] else {
        return [ "error": "Action mis-configured (ANYCARDS_APP_TOKEN is not in the environment)"]
    }
    guard let actualToken = args["appToken"] as? String else {
        return [ "error": "appToken argument is required by this action" ]
    }
    if actualToken != expectedToken {
        return [ "error": "createGame was invoked outside the expected action context; no game created" ]
    }
    let gamePass = randomPassword()
    let client: RedisClient
    let key = RedisKey("game_" + gamePass + "_exists")
    do {
        client = try redis()
        _ = try client.set(key, to: "").wait()
    } catch {
        return [ "error": "\(error)"]
    }
    return [ "gameToken": gamePass ]
}

func randomPassword() -> String {
    let chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    var ans = ""
    for _ in 0 ..< 64 {
        ans.append(chars.randomElement()!)
    }
    return ans
}
