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

// Source for the withdraw Action.
// Inputs:
//
//	gameToken: the secret token for the game provided by the game's initiator (64 chars alphameric)
//	player: the player's "order number" (a string parsable as int) which serves as a unique id
//
// Outputs:
//
//	status == StatusOK if the gameToken matches a game, from which the player is withdrawn (if present)
//	status == StatusBadRequest if either argument is missing or ill-formed
//
// If the gameToken is syntactically valid but fails to match any game, the "not found" response is used
// rather than an auth failure.   We can't distinguish unauthorized access from a once-authorized token
// whose game has expired.
// If the player withdrawing is the last player of the game (or the game is already empty), the game is deleted.
// We do not use the "not found" response if the player is not in the game.  That is considered "success".
func withdraw(w http.ResponseWriter, body map[string]interface{}) {
	gameToken, player, game := getGameAndPlayer(w, body)
	if game == nil {
		return
	}
	fmt.Printf("request to withdraw player %s from game %s\n", player, gameToken)
	delete(game.Players, player)
	if len(game.Players) == 0 {
		fmt.Printf("game %s has no remaining players, deleting\n", gameToken)
		delete(games, gameToken)
	}
}
