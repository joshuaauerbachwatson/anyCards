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

import nimbella_key_value
import RediStack

func main(args: [String:Any]) -> [String:Any] {
    do {
        let redisClient = try redis()
        try redisClient.set("foo", to: "bar").wait()
        let result = try redisClient.get("foo").wait()?.string
        if (result != "bar") {
            return [ "error": "Result of get was not 'bar'" ]
        }
        let deleted = try redisClient.delete(["foo"]).wait()
        if (deleted != 1) {
            return [ "error": "result of delete was not '1'" ]
        }
        let newResult = try redisClient.get("foo").wait()
        if (newResult != nil) {
            return [ "error": "delete did not have the desired effect" ]
        }
    } catch {
        return [ "error": "\(error)"]
    }
    return [ "success": true ]
}
