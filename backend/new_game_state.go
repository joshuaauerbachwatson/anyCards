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
	"fmt"
	"net/http"
)

// Source for the newGameState Action.
// Inputs:
//
//	 appToken:  (already validated at entry)
//		gameToken: the token giving access to the game
//		player: the player string (random number used as ordinal)
//		gameState - the new value for the game state as a JSON-encoded String
//
// Outputs:
//
//	status == StatusOK if the game exists or can be created and the player and gameState are admitted
//	status == StatusBadRequest if any argument is ill-formed
func newGameState(w http.ResponseWriter, body map[string]interface{}) {
	gameToken, player, game := getGameAndPlayer(w, body)
	if game == nil {
		return // error response already issued
	}
	gameState, ok := body[argGameState].(map[string]interface{})
	if !ok {
		indicateError(http.StatusBadRequest, "missing or malformed gameState argument", w)
		return
	}
	game.State = gameState
	game.Players[player] = 0
	fmt.Printf("New gamestate recorded for game %s\n", gameToken)
	w.WriteHeader(http.StatusOK)
}
