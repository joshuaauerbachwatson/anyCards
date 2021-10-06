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

// Source for the deleteGame Action.
// Inputs: gameToken - the token for the game to be deleted
//         force - true iff the game is to deleted unconditionally (even if it seems to be in progress)
// Outputs: success indication
// It is an error to delete a non-existing game.  Normally it is an error to delete a game that is "in progress"
// (possessing either a player list or game state).  This is overridden by the force flag.
func main(args: [String:Any]) -> [String:Any] {
    guard let gameToken = args["gameToken"] as? String else {
        return [ "error": "appToken argument is required by this action" ]
    }
    var force: Bool = false
    if let boolForce = args["force"] as? Bool {
        force = boolForce
    } else if let stringForce = args["force"] as? String {
        force = Bool(stringForce) ?? false
    }
    let existsKey = RedisKey("game_" + gameToken + "_exists")
    let playersKey = RedisKey("game_" + gameToken + "_players")
    let stateKey = RedisKey("game_" + gameToken + "_state")
    do {
        let client = try redis()
        let gameExists = try client.send(RedisCommand<Int>.exists(existsKey)).wait()
        if gameExists != 1 {
            return [ "error": "Game \(gameToken) does not exist" ]
        }
        let inProgress = try client.send(RedisCommand<Int>.exists(playersKey, stateKey)).wait()
        if inProgress > 0 && !force {
            return [ "error": "Game \(gameToken) is in progress and 'force' was not specified" ]
        }
        _ = try client.delete([ existsKey, playersKey, stateKey ]).wait()
    } catch {
        return [ "error": "\(error)"]
    }
    return [ "success": true ]
}
