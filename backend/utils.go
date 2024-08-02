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
	"strings"

	jwtmiddleware "github.com/auth0/go-jwt-middleware/v2"
	"github.com/auth0/go-jwt-middleware/v2/validator"
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
	return body
}

// Special validator for admin requests
func isAdmin(w http.ResponseWriter, r *http.Request) bool {
	token := r.Context().Value(jwtmiddleware.ContextKey{}).(*validator.ValidatedClaims)
	claims := token.CustomClaims.(*CustomClaims)
	if !claims.HasPermission("admin:server") {
		indicateError(http.StatusForbidden, "You need to be an administrator to perform this operation.", w)
		return false
	}
	return true
}

// Secondary validator for post bodies containing gameToken.  Returns the gameToken (or "") and a valid
// indicator (bool).  Issues a response if invalid.
func validateGameToken(w http.ResponseWriter, body map[string]interface{}) (string, bool) {
	gameToken, ok := body[argGameToken].(string)
	if ok && isValidGameToken(gameToken) {
		return gameToken, true
	}
	indicateError(http.StatusBadRequest, "missing or malformed game token", w)
	return "", false
}

// Check validity of game token
func isValidGameToken(gameToken string) bool {
	return len(gameToken) == gameTokenLen && regexp.MustCompile(`^[a-zA-Z0-9]*$`).MatchString(gameToken)
}

// Secondary validator for post bodies containing player.  Returns the playerToken (or ""), the
// player order (or 0) and a valid indicator (bool).  Issues a response if invalid.
func validatePlayer(w http.ResponseWriter, body map[string]interface{}) (string, uint32, bool) {
	player, ok := body[argPlayer]
	if ok {
		token, ok := player.(string)
		if ok {
			order, ok := isValidPlayer(token)
			if ok {
				return token, order, true
			}
		}
	}
	indicateError(http.StatusBadRequest, "missing or malformed player value", w)
	return "", 0, false
}

// Check validity of player token.  The first part a base64 encoded player name, which is not checked.
// The second part is an "order number" represented as a string of ascii digits.  Note that 0 is never
// a valid player order number.  If valid, the order number is also returned.
func isValidPlayer(player string) (uint32, bool) {
	parts := strings.Split(player, ":")
	if len(parts) != 2 {
		return 0, false
	}
	maybe, err := strconv.Atoi(parts[1])
	if err != nil {
		return 0, false
	}
	return uint32(maybe), true
}

// Function to indicate an error, both logging it to the server console and reflecting it back to
// the client.
func indicateError(status int, msg string, w http.ResponseWriter) {
	fmt.Println(msg + "!")
	w.WriteHeader(status)
	w.Write(errorDictionary(msg))
}

// Get a single-valued query value from an http.Request, returning empty string if not present or if there
// are multiple values.
func getQueryValue(r *http.Request, key string) string {
	ans, ok := r.URL.Query()[key]
	if !ok {
		return ""
	}
	if len(ans) != 1 {
		return ""
	}
	return ans[0]
}

// Get the gameToken, playerToken, playerOrder game for a request.  The game need not previously exist but
// will be created on demand.  However, either the game token or the playerToken may be malformed.
// All errors result in an error response being sent and a return with a nil Game.
func getGameAndPlayer(w http.ResponseWriter, body map[string]interface{}) (string, string, uint32, *Game) {
	gameToken, ok := validateGameToken(w, body)
	if !ok {
		return "", "", 0, nil
	}
	playerToken, playerOrder, ok := validatePlayer(w, body)
	if !ok {
		return gameToken, "", 0, nil
	}
	game, _ := ensureGameAndPlayer(gameToken, playerToken, playerOrder, 0)
	return gameToken, playerToken, playerOrder, game // game will be nil on error
}

// Given game and player tokens that are syntactically valid but may or may not designate
// and actual game and player, make sure that the game and player exist and return the
// Game and Player structures.  A Game will always have a running Hub whether pre-existing or not.
// A newly created Player may not yet have a Client.
func ensureGameAndPlayer(gameToken string, playerToken string, playerOrder uint32,
	numPlayers int) (*Game, *Player) {

	game := games[gameToken]
	if game == nil {
		game = &Game{Players: make(map[uint32]*Player), State: map[string]interface{}{},
			Hub: newHub(), NumPlayers: numPlayers}
		games[gameToken] = game
		go game.Hub.run()
		fmt.Printf("New game created with token %s\n", gameToken)
	}
	if game.NumPlayers == 0 {
		fmt.Printf("Number of players in game %s set to %d\n", gameToken, numPlayers)
		game.NumPlayers = numPlayers
	} // TODO should we check for "too many leaders" here?
	if game.Players[playerOrder] == nil {
		game.Players[playerOrder] = &Player{Token: playerToken}
		fmt.Printf("Player %d added to game %s\n", playerOrder, gameToken)
	} else {
		game.Players[playerOrder].IdleCount = 0
	}
	return game, game.Players[playerOrder]
}

// Convert an error message to an error dictionary using the key "error".
func errorDictionary(msg string) []byte {
	dict := map[string]string{"error": msg}
	toSend, _ := json.Marshal(dict) // assume no error
	return toSend
}
