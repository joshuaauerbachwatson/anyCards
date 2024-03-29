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
	"regexp"
	"strconv"
)

// Anycards backend utility functions

// Preliminary validator and request logging support.  If valid, returns the POST body as a (possibly empty)
// map.  If invalid, returns nil (having already sent the error response).
func screenRequest(w http.ResponseWriter, r *http.Request) *map[string]interface{} {
	uri := r.RequestURI
	method := r.Method
	fmt.Println("Got request", method, uri)
	if method != http.MethodPost {
		indicateError(http.StatusMethodNotAllowed, "forbidden method", w)
		return nil
	}
	body := new(map[string]interface{})
	err := json.NewDecoder(r.Body).Decode(body)
	if err != nil {
		indicateError(http.StatusBadRequest, "malformed request body (not JSON?)", w)
		return nil
	}
	appToken := (*body)[argAppToken]
	if appToken == anycardsAppToken {
		return body
	}
	msg := fmt.Sprintf("unauthorized %s request", uri)
	indicateError(http.StatusUnauthorized, msg, w)
	return nil
}

// Secondary validator for post bodies containing gameToken.  Returns the gameToken (or "") and a valid
// indicator (bool).  Issues a response if invalid.
func validateGameToken(w http.ResponseWriter, body map[string]interface{}) (string, bool) {
	gameToken, ok := body["gameToken"].(string)
	if ok {
		if len(gameToken) == gameTokenLen && regexp.MustCompile(`^[a-zA-Z0-9]*$`).MatchString(gameToken) {
			return gameToken, true
		}
	}
	indicateError(http.StatusBadRequest, "missing or malformed game token", w)
	return "", false
}

// Secondary validator for post bodies containing player.  Returns the player (or "") and a valid
// indicator (bool).  Issues a response if invalid.
func validatePlayer(w http.ResponseWriter, gameToken string, body map[string]interface{}) (string, bool) {
	player, ok := body["player"].(string)
	if ok {
		maybe, err := strconv.Atoi(player)
		if err == nil && maybe >= 0 {
			return player, true
		}
	}
	indicateError(http.StatusBadRequest, "missing or malformed player value", w)
	return "", false
}

// Function to indicate an error, both logging it to the server console and reflecting it back to
// the client.
func indicateError(status int, msg string, w http.ResponseWriter) {
	fmt.Println(msg + "!")
	w.WriteHeader(status)
	w.Write(errorDictionary(msg))
}

// Get the gameToken, player, and game for a request.  The game need not previously exist but
// will be created on demand.  However, either the game token or the player value may be malformed.
// All errors result in an error response being sent and a return with a nil Game.
func getGameAndPlayer(w http.ResponseWriter, body map[string]interface{}) (string, string, *Game) {
	gameToken, ok := validateGameToken(w, body)
	if !ok {
		return "", "", nil
	}
	player, ok := validatePlayer(w, gameToken, body)
	if !ok {
		return gameToken, "", nil
	}
	game := games[gameToken]
	if game == nil {
		game = &Game{Players: make(map[string]int), State: map[string]interface{}{}}
		games[gameToken] = game
	} else {
		game.IdleCount = 0
	}
	game.Players[player] = 0
	return gameToken, player, game // game will be nil on error
}

// Convert an error message to an error dictionary using the key "error".
func errorDictionary(msg string) []byte {
	dict := map[string]string{"error": msg}
	toSend, _ := json.Marshal(dict) // assume no error
	return toSend
}
