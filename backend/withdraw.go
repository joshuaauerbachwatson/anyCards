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
//	gameToken: the secret token for the game provided by the game's creator (64 chars alphameric)
//	player: the player's "order number" (a string parsable as int) which serves as a unique id
//
// Outputs:
//
//	status == StatusOK if the gameToken matches a game, from which the player is withdrawn (if present)
//	status == StatusBadRequest if either argument is missing or ill-formed
//	status == StatusNotFound if the arguments are superficially ok but the gameToken fails to match an active game
//
// If the gameToken is syntactically valid but fails to match any game, the "not found" response is used
// rather than an auth failure.   We can't distinguish unauthorized access from a once-authorized token
// whose game has expired.
// If the player withdrawing is the last player of the game, the game is nevertheless left in place and could
// be "played again" by presenting its game token.  Games that are idle for long enough are removed.
// We do not use the "not found" response if the player is not in the game.  That is considered "success".
func withdraw(w http.ResponseWriter, body map[string]interface{}) {
	gameToken, player, game := getGameAndPlayer(w, body)
	if game == nil {
		return
	}
	fmt.Printf("request to withdraw player %s from game %s\n", player, gameToken)
	if game.Players[player] == nil {
		fmt.Printf("player %s is not in the game (already withdrawn?)\n", player)
		return
	}
	delete(game.Players, player)
	if game.Players[player] == nil {
		fmt.Printf("player %s was successfully withdrawn\n", player)
		return
	}
	indicateError(http.StatusInternalServerError, "player failed to be withdrawn", w)
}
