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
	"fmt"
	"time"
)

// Cleanup function, expected to be invoked at regular intervals.  The constants
// gameTimeout and playerTimeout express how many times a player or game can be
// found idle by this function before they are removed.  This assumes that the idle counts
// are zeroed every time a game is touched or a player is heard from.
func cleanup() {
	for token, game := range games {
		if game.idleCount > gameTimeout {
			fmt.Println("cleanup deleting idle game", token)
			delete(games, token)
			continue
		}
		for player, idleCount := range game.players {
			if idleCount > playerTimeout {
				fmt.Printf("cleanup deleting player %s from game %s\n", player, token)
				delete(game.players, player)
			}
		}
	}
}

// Start a ticker to do cleanup every 'cleanupPeriod' seconds
func startCleanupTicker() {
	ticker := time.NewTicker(cleanupPeriod * time.Second)
	go func() {
		for {
			<-ticker.C
			cleanupCounter++
			cleanup()
		}
	}()
}
