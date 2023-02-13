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
	"os"
)

// Constants used in the backend

// The required app token for creating games, stored as a secret in the environment by the App Platform deploy.
// This is a "constant" by some definitions (immutable after initialization) but golang does not permit it to be
// declared 'const' (initializer is not a constant expression).
var anycardsAppToken = os.Getenv("ANYCARDS_APP_TOKEN")

const (
	// characters that are legal in a gameToken
	gameTokenChars    = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	numGameTokenChars = len(gameTokenChars)

	// Length of a game token in characters
	gameTokenLen = 12

	// URL paths representing verbs
	pathCreate   = "/create"
	pathDelete   = "/delete"
	pathNewState = "/newstate"
	pathPoll     = "/poll"
	pathWithdraw = "/withdraw"
	pathReset    = "/reset"
	pathDump     = "/dump"

	// Period at which the cleanup function is called, in seconds
	cleanupPeriod = 15

	// Default port to listen on if a port is not specified via the environment
	defaultPort = "80"

	// Timeouts for idle players and games, as multiples of the cleanup period
	// We use tight values as a development aid, but we need to make them looser eventually.
	playerTimeout = 45 / cleanupPeriod
	gameTimeout   = 300 / cleanupPeriod

	// Dictionary keys used by the various functions for inputs and outputs
	argAppToken  = "appToken"
	argGameToken = "gameToken"
	argForce     = "force"
	argGameState = "gameState"
	argPlayers   = "players"
	argState     = "state"
)
