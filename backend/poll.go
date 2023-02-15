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
	"net/http"
	"sort"
	"strings"

	"golang.org/x/exp/maps"
)

// Source for the poll Action.  This action is both the means by which we know that the app is still running
// and also the means by which the app's state is updated with the latest information.
//
// TODO when we move away from http to a more connection-based protocol, we will start pushing information to
// clients and eliminate this action.
//
// Inputs:
//
//	gameToken - a token giving access to the game
//	player - the player's "order number" (an all-numeric String) which serves as a unique id
//
// Outputs:
//
//	players: the list of all active players as a blank separated string containing order numbers in ascending
//	  order.  Note we provide this only so that clients can enforce play order.  Eventually the server should be
//	  enforcing this.
//	gameState: the GameState structure as a JSON-encoded string
func poll(w http.ResponseWriter, body map[string]string) {
	_, _, game := getGameAndPlayer(w, body)
	if game == nil {
		return
	}
	players := sortAndEncode(game.Players)
	responseData := map[string]interface{}{argGameState: game.State, argPlayers: players}
	response, _ := json.Marshal(responseData) // are errors possible here? ... I think not
	w.Write(response)                         // no error handling for now
}

// Subroutine to sort and encode the player numbers
func sortAndEncode(players map[string]*int) string {
	keys := maps.Keys(players)
	sort.Strings(keys)
	return strings.Join(keys, " ")
}
