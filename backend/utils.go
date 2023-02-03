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
	"math/rand"
	"net/http"
	"regexp"
	"strconv"
)

// Anycards backend utility functions

// Preliminary validator and request logging support.  If valid, returns the POST body as a (possibly empty)
// map.  If invalid, returns nil (having already sent the error response).
func screenRequest(w http.ResponseWriter, r *http.Request) *map[string]string {
	uri := r.RequestURI
	method := r.Method
	fmt.Println("Got request", method, uri)
	if method != http.MethodPost {
		fmt.Println("Forbidden method!", method)
		w.WriteHeader(http.StatusMethodNotAllowed)
		return nil
	}
	body := new(map[string]string)
	err := json.NewDecoder(r.Body).Decode(body)
	if err == nil {
		return body
	}
	fmt.Println("Erroneous body!")
	w.WriteHeader(http.StatusBadRequest)
	return nil
}

// Secondary validator for post bodies containing gameToken.  Returns the gameToken (or "") and a valid
// indicator (bool).  Issues a response if invalid.
func getGameToken(w http.ResponseWriter, body map[string]string) (string, bool) {
	gameToken := body["gameToken"]
	if len(gameToken) == 64 && regexp.MustCompile(`^[a-zA-Z0-9]*$`).MatchString(gameToken) {
		game := games[gameToken]
		if game != nil {
			game.idleCount = 0
		}
		return gameToken, true
	}
	fmt.Println("Erroneous gameToken!", gameToken)
	w.WriteHeader(http.StatusBadRequest)
	return "", false
}

// Secondary validator for post bodies containing player.  Returns the player (or "") and a valid
// indicator (bool).  Issues a response if invalid.
func getPlayer(w http.ResponseWriter, gameToken string, body map[string]string) (string, bool) {
	player := body["player"]
	maybe, err := strconv.Atoi(player)
	if err == nil && maybe >= 0 {
		game := games[gameToken]
		if game != nil {
			game.players[player] = 0
		}
		return player, true
	}
	fmt.Println("Erroneous player value!", player)
	w.WriteHeader(http.StatusBadRequest)
	return "", false
}

// Convenience wrapper for getting the game and player, validating args in the process, and
// determining whether the game exists.  All errors result in an error response being sent
// and a return with a nil Game.
func getGameAndPlayer(w http.ResponseWriter, body map[string]string) (string, string, *Game) {
	gameToken, ok := getGameToken(w, body)
	if !ok {
		return "", "", nil
	}
	player, ok := getPlayer(w, gameToken, body)
	if !ok {
		return gameToken, "", nil
	}
	game := games[gameToken]
	if game == nil {
		fmt.Println("gameToken doesn't designate a game!", gameToken)
		w.WriteHeader(http.StatusNotFound)
	}
	return gameToken, player, game
}

// Simple random generator for game tokens
func randomGameToken() string {
	b := make([]byte, 64)
	for i := range b {
		b[i] = gameTokenChars[rand.Intn(numGameTokenChars)]
	}
	return string(b)
}
