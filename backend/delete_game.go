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
	gameToken, ok := getGameToken(w, body)
	if !ok {
		return
	}
	game := games[gameToken]
	if game == nil {
		indicateError(http.StatusNotFound, "gameToken does not designate a game", w)
		return
	} else if len(game.Players) > 0 && body[argForce] == "" {
		indicateError(http.StatusForbidden, "there are still players and 'force' was not specified", w)
		return
	} // else ok
	fmt.Printf("deleting game %s\n", gameToken)
	fmt.Printf("%d games prior to deletion\n", len(games))
	delete(games, gameToken)
	fmt.Printf("%d games after deletion\n", len(games))
	w.WriteHeader(http.StatusOK)
}
