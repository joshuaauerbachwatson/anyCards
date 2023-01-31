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

// The backend to the anyCards game, to be gradually evolved into something better.

package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
)

// Preliminary validator and logging support
func screenRequest(w http.ResponseWriter, r *http.Request) bool {
	uri := r.RequestURI
	method := r.Method
	fmt.Println("Got request", method, uri)
	if method != http.MethodPost {
		fmt.Println("Forbidden!")
		w.WriteHeader(http.StatusForbidden)
		return true
	}
	return false
}

// Main entry point
func main() {
	// Set up handlers.  Note: we are currently following the old passive multicast logic that we used in
	// the serverless implementation.  Ultimately, the role of this server should increase to include knowledge
	// of what game is being played and enforcement of the rules.
	http.HandleFunc("/create", func(w http.ResponseWriter, r *http.Request) {
		if screenRequest(w, r) {
			return
		}
		createGame(w, r)
	})
	http.HandleFunc("/delete", func(w http.ResponseWriter, r *http.Request) {
		if screenRequest(w, r) {
			return
		}
		deleteGame(w, r)
	})
	http.HandleFunc("/newstate", func(w http.ResponseWriter, r *http.Request) {
		if screenRequest(w, r) {
			return
		}
		newGameState(w, r)
	})
	http.HandleFunc("/poll", func(w http.ResponseWriter, r *http.Request) {
		if screenRequest(w, r) {
			return
		}
		poll(w, r)
	})
	http.HandleFunc("/withdraw", func(w http.ResponseWriter, r *http.Request) {
		if screenRequest(w, r) {
			return
		}
		poll(w, r)
	})
	http.HandleFunc("/cleanup", func(w http.ResponseWriter, r *http.Request) {
		if screenRequest(w, r) {
			return
		}
		cleanup(w, r)
	})

	// Permit port override (default 80)
	port := os.Getenv("PORT")
	if port == "" {
		port = "80"
	}

	// Bind to port address
	bindAddr := fmt.Sprintf(":%s", port)
	fmt.Printf("==> Server listening at %s\n", bindAddr)

	// Start serving requests
	err := http.ListenAndServe(fmt.Sprintf(":%s", port), nil)
	// No reasonable recovery at this point, just crash
	log.Fatal(err)
}
