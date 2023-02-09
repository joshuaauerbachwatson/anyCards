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

package main

import (
	"encoding/json"
	"fmt"
	"net/http"
)

// Source for the createGame Action.
// Inputs:
//
//	appToken: the value of the appToken used by the app.  Must match the environment variable ANYCARDS_APP_TOKEN.
//
// Outputs:
//
//	status == StatusOK if the appToken was valid
//	status == StatusUnauthorized if the appToken was not valid
//	gameToken: a 16 character random string to be used for admission to the game (only if StatusOK)
//
// If successful, the game is marked as existing and further developments (such as starting actual game play)
// are awaited.  The game can return to "merely existing" when all players of the game have withdrawn.
// This does not delete the game.  Only a deleteGame call can do that.  It is up to the creator to distribute
// the game token to potential players.
func createGame(w http.ResponseWriter, body map[string]string) {
	appToken := body[argAppToken]
	if appToken != anycardsAppToken {
		fmt.Println("Unauthorized creation request!")
		w.WriteHeader(http.StatusUnauthorized)
		return
	}
	gameToken := randomGameToken()
	game := new(Game)
	game.players = make(map[string]int)
	games[gameToken] = game
	responseData := map[string]string{argGameToken: gameToken}
	response, _ := json.Marshal(responseData) // are errors possible here? ... I think not
	w.Write(response)                         // no error handling for now
}
