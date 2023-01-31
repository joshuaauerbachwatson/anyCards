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

// Handles periodic cleanup of players and games that have been idle long enough

package main

import (
	"net/http"
)

const (
	cleanupPeriod = 2  // approx interval between calls, in minutes
	playerTimeout = 6  // number of minutes a player is allowed to be idle
	gameTimeout   = 60 // number of minutes a game is allowed to be idle
)

func cleanup(w http.ResponseWriter, r *http.Request) {
	gt := gameTimeout / cleanupPeriod
	pt := playerTimeout / cleanupPeriod
	for token, game := range games {
		if game.idleCount > gt {
			delete(games, token)
		}
		for player, idleCount := range game.players {
			if idleCount > pt {
				delete(game.players, player)
			}
		}
	}
}
