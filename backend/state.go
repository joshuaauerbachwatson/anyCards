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

// The state of one game
type Game struct {
	players   map[string]int // key is the player's "order" string, value is the idleCount
	idleCount int            // global idle count for the game as a whole
	state     string         // the game state (encoded JSON but not interpreted here)
}

// Map from game tokens to game states
var games = make(map[string]*Game)
