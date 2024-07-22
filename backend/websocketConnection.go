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

// Code incorporated from the Gorilla Websocket Chat example, which has the following copyright

// Copyright 2013 The Gorilla WebSocket Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the GorillaWebsocketLicenseCENSE file.

package main

import (
	"bytes"
	"fmt"
	"log"
	"net/http"
	"time"

	"github.com/gorilla/websocket"
)

const (
	// Time allowed to write a message to the peer.
	writeWait = 10 * time.Second

	// Time allowed to read the next pong message from the peer.
	pongWait = 60 * time.Second

	// Send pings to peer with this period. Must be less than pongWait.
	pingPeriod = (pongWait * 9) / 10

	// Maximum message size allowed from peer.
	maxMessageSize = 512
)

var (
	newline = []byte{'\n'}
	space   = []byte{' '}
)

var upgrader = websocket.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
}

// Client is a middleman between the websocket connection and the hub.
type Client struct {
	hub *Hub

	// The websocket connection.
	conn *websocket.Conn

	// Buffered channel of outbound messages.
	send chan []byte

	// Termination indicator.  All goroutines should exit when they see this
	// and the main logic should not use the Client but rather create a new one.
	terminated bool
}

// Destroy closes out all goroutines of this client, closes the connection, stops the ticker, will exit, the connection is closed, the hub
// is notified with "deregister" and the destruction is recorded
func (c *Client) Destroy() {
	if c.terminated {
		// Don't do this multiple times
		return
	}
	c.terminated = true
	c.hub.unregister <- c
	c.conn.Close()
}

// readPump pumps messages from the websocket connection to the hub.
//
// The application runs readPump in a per-connection goroutine. The application
// ensures that there is at most one reader on a connection by executing all
// reads from this goroutine.
func (c *Client) readPump() {
	defer func() {
		c.Destroy()
	}()
	c.conn.SetReadLimit(maxMessageSize)
	c.conn.SetReadDeadline(time.Now().Add(pongWait))
	c.conn.SetPongHandler(func(string) error { c.conn.SetReadDeadline(time.Now().Add(pongWait)); return nil })
	for {
		if c.terminated {
			return
		}
		_, message, err := c.conn.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				log.Printf("error: %v", err)
			}
			break
		}
		message = bytes.TrimSpace(bytes.Replace(message, newline, space, -1))
		c.hub.broadcast <- message
	}
}

// writePump pumps messages from the hub to the websocket connection.
//
// A goroutine running writePump is started for each connection. The
// application ensures that there is at most one writer to a connection by
// executing all writes from this goroutine.
func (c *Client) writePump() {
	ticker := time.NewTicker(pingPeriod)
	defer func() {
		ticker.Stop()
		c.Destroy()
	}()
	for {
		if c.terminated {
			return
		}
		select {
		case message, ok := <-c.send:
			c.conn.SetWriteDeadline(time.Now().Add(writeWait))
			if !ok {
				// The hub closed the channel.
				c.conn.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}

			w, err := c.conn.NextWriter(websocket.TextMessage)
			if err != nil {
				return
			}
			w.Write(message)

			// Add queued chat messages to the current websocket message.
			n := len(c.send)
			for i := 0; i < n; i++ {
				w.Write(newline)
				w.Write(<-c.send)
			}

			if err := w.Close(); err != nil {
				return
			}
		case <-ticker.C:
			c.conn.SetWriteDeadline(time.Now().Add(writeWait))
			if err := c.conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}

// newWebsocket handles websocket upgrade requests from the app.  Auth0 token validation has
// already occurred but we need to parse the header information to identity the player and game
// If there is a problem with that, we avoid the upgrade.
func newWebSocket(w http.ResponseWriter, r *http.Request) {
	playerValue := getHeader(r, playerHeader)
	gameToken := getHeader(r, gameHeader)
	fmt.Printf("newWebsocket: player=%s and game=%s\n", playerValue, gameToken)
	if playerValue == "" || gameToken == "" {
		indicateError(http.StatusBadRequest, "Missing required header information for websocket", w)
		return
	}
	game, ok := games[gameToken]
	if !ok {
		indicateError(http.StatusBadRequest, "Websocket cannot be opened for non-existing game", w)
		return
	}
	player, ok := game.Players[playerValue]
	if !ok {
		indicateError(http.StatusBadRequest, "Websocket cannot be opened until the player has joined the game", w)
		return
	}
	// We have a valid player and game so it's ok to upgrade
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Println(err)
		return
	}
	// Create and remember Client
	if player.Client != nil {
		// Make sure old client is dead if found
		player.Client.Destroy()
	}
	player.Client = &Client{hub: game.Hub, conn: conn, send: make(chan []byte, 256)}
	game.Hub.register <- player.Client
	player.IdleCount = 0

	// Allow collection of memory referenced by the caller by doing all work in
	// new goroutines.
	go player.Client.writePump()
	go player.Client.readPump()
}
