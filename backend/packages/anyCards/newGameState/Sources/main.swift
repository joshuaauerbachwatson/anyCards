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

// Source for the newGameState Action.
// Inputs: gameToken - the token giving access to the game
//         gameState - the new value for the game state as a JSON-encoded String
// Outputs: a success indicator
func main(args: [String:Any]) -> [String:Any] {
    guard let gameToken = args["gameToken"] as? String else {
        return [ "error": "gameToken argument is required by this action" ]
    }
    guard let gameState = args["gameState"] as? String else {
        return [ "error": "gameState argument is required by this action" ]
    }
    do {
        let client = try redis()
        _ = try client.set(stateKey(gameToken), to: gameState).wait()
    } catch {
        return [ "error": "\(error)"]
    }
    return [ "success": true ]
}
