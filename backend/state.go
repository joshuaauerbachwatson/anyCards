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

// Stores the (volatile, in memory) state of all the active games.

package main

import (
	"encoding/json"
	"fmt"
	"net/http"
)

// The state of one game
type Game struct {
	Players   map[string]int         `json:"players"`   // key is the player's "order" string, value is the idleCount
	IdleCount int                    `json:"idleCount"` // global idle count for the game as a whole
	State     map[string]interface{} `json:"state"`     // the game state (not interpreted here)
}

type DumpedState struct {
	CleanupCounter int              `json:"cleanupCounter"`
	Games          map[string]*Game `json:"games"`
}

// Map from game tokens to game states
var games = make(map[string]*Game)

// Counter for the number of times cleanup has run
var cleanupCounter int

// Handler for an admin function to dump the entire state of the server.
// This is an aid during development.  We might need something more sophisticated
// for observability in the long run.
func dump(w http.ResponseWriter, body map[string]interface{}) {
	ans := DumpedState{CleanupCounter: cleanupCounter, Games: games}
	encoded, err := json.MarshalIndent(ans, "", "  ")
	if err != nil {
		indicateError(http.StatusInternalServerError, err.Error(), w)
		return
	}
	fmt.Println("dump called")
	fmt.Println(string(encoded))
	w.Write(append(encoded, byte('\n')))
}

// Handler for an admin function to reset to the empty state
func reset(w http.ResponseWriter, body map[string]interface{}) {
	fmt.Println("reset called")
	games = make(map[string]*Game)
	cleanupCounter = 0
}
