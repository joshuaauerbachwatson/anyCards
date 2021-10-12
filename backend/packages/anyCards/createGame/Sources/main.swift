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
// Inputs: appToken - the value of the appToken used by the app.
//                    Must match the environment variable ANYCARDS_APP_TOKEN.
// Outputs: gameToken - a 16 character random string to be used for admission to the game
// The game is marked as existing and further developments (such as starting actual game play)
// are awaited.  THe game can return to "merely existing" when all players of the game have withdrawn.
// This does not delete the game.  Only a deleteGame call can do that.
func main(args: [String:Any]) -> [String:Any] {
    guard let expectedToken = ProcessInfo.processInfo.environment["ANYCARDS_APP_TOKEN"] else {
        return [ "error": "Action mis-configured (ANYCARDS_APP_TOKEN is not in the environment)"]
    }
    guard let actualToken = args["appToken"] as? String else {
        return [ "error": "appToken argument is required by this action" ]
    }
    if actualToken != expectedToken {
        return [ "error": "createGame was invoked outside the expected context; no game created" ]
    }
    let gameToken = random64CharString()
    let client: RedisClient
    do {
        client = try redis()
        _ = try client.set(cleanupKey(gameToken), to: String(Date().timeIntervalSinceReferenceDate)).wait()
    } catch {
        return [ "error": "\(error)"]
    }
    return [ "gameToken": gameToken ]
}

func random64CharString() -> String {
    let chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    var ans = ""
    for _ in 0 ..< 64 {
        ans.append(chars.randomElement()!)
    }
    return ans
}
