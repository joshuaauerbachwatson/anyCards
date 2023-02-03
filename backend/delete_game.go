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
	"net/http"
)

// Source for the deleteGame Action.
// It is an error to delete a non-existing game.  Normally it is an error to delete a game that is "in progress"
// (possessing either a player list or game state).  This is overridden by the force flag.
//
// Inputs:
//
//		gameToken: the token for the game to be deleted
//		    force: if present with a non-empty string value, the game is to deleted unconditionally
//		           (even if it seems to be in progress)
//
//	 Other inputs are ignored.  The 'force' input is optional.
//
// Outputs:
//
//	    status == StatusOK if the game was found and deleted
//		status == StatusBadRequest if the required 'gameToken' argument is missing or ill-formed
//		status == StatusNotFound if the game was not found
//		status == StatusForbidden if the game was found but is in progress and force was not specified
func deleteGame(w http.ResponseWriter, body map[string]string) {
	status := http.StatusOK
	game, ok := getGameToken(w, body)
	if !ok {
		return
	}
	gameState := games[game]
	if gameState == nil {
		status = http.StatusNotFound
	} else if len(gameState.players) > 0 && body[argForce] == "" {
		status = http.StatusForbidden
	} // else ok
	if status == http.StatusOK {
		delete(games, game)
	}
	w.WriteHeader(status)
}
