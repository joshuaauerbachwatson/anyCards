/**
 * Copyright (c) 2021-present, Joshua Auerbach
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import UIKit

// Class to manage a simple logging facility (to disk).  The emphasis is on simple low-volume logging with the fewest possible frills.

// The 'log' method exists in two forms:
//      1.  To open the log on a specific path use openLog(String)->FileHandle?
//          To log to the resulting handle use log(FileHandle, String).
//      2.  The alternate log(String) caches the filehandle in a static variable and assume a specific naming scheme (and capacity limit).
//             There is no public 'open' method in this case.

// Implicit logging with the standard naming is recommended for apps.  The alternative can be used by app extensions to store the log in a shared container.

// Also includes some useful global functions packaged here rather than in "Useful" because they are used here or in app extensions (and Useful has stuff
// that's hard to incorporate into app extensions).
class Logger {
    private init() {} // All static

    // Constants
    static let LogPrefix = "log"
    private static let LogThreshhold : UInt64 = 1024 * 1024
    private static let KeepThreshhold = 8
    private static let LogOpenAnomalyTemplate = "Unable to open the log at %@"
    private static let FileSizeAnomaly = "Unable to determine file size"
    private static let OpenMessage = "Log opened"

    // State (held in static variables since all methods are static)
    private static let formatter = makeDateFormatter()
    private static var logHandle : FileHandle? = nil
    private static var noImplicitLogging = false

    // Public API

    // Log a message of any kind to the implicit log location
    static func log(_ message: String) {
        #if targetEnvironment(simulator)
            print(message)
        #endif
        if let logHandle = self.logHandle {
            // Typical case
            log(logHandle, message)
        } else if noImplicitLogging {
            // After previous failure, do not keep trying
        } else if let logHandle = openLog() {
            // First time, with success
            log(logHandle, message)
            self.logHandle = logHandle
        } else {
            // First time, with failure
            noImplicitLogging = true
        }
    }

    // Log to a specific log location.  Given a nil handle, this method does nothing but is harmless
    static func log(_ handle: FileHandle?, _ message: String) {
        let toLog = formatter.string(from: Date()) + " " + message + "\n"
        if let handle = handle, let data = toLog.data(using: .utf8) {
           handle.write(data)
        }
    }

    // Log the dismissal of one view controller by another (performs the dismissal also)
    static func logDismiss(_ dismissed: UIViewController, host: UIViewController, animated: Bool) {
        log("Dismissing " + String(describing: type(of: dismissed)) + ", returning to " + String(describing: type(of: host)))
        host.dismiss(animated: animated)
    }

    // Log a message to the implicit log for a fatal error and then call fatalError
    static func logFatalError(_ message: String) -> Never {
        log("Fatal Error: " + message)
        fatalError(message)
    }

    // Log the presentation of one view controller by another (performs the presentation also)
    static func logPresent(_ presented: UIViewController, host: UIViewController, animated: Bool) {
        log("Presenting " + String(describing: type(of: presented)))
        host.present(presented, animated: animated)
    }

    // Open a log to a specific location.  This can fail silently if the file doesn't exist, and it is up to the caller to handle that case.
    static func openLog(_ path: String) -> FileHandle? {
        if let handle = FileHandle(forWritingAtPath: path) {
            handle.seekToEndOfFile()
            return handle
        } else {
            return nil
        }
    }

    // Get the indices of all logs that exist, newest first.  This is helpful when preparing to transmit a problem report
    static func getAllLogIndices() -> [Int] {
        var logs = [Int]()
        let allFiles = (try? FileManager.default.contentsOfDirectory(atPath: getDocDirectory().path)) ?? []
        for file in allFiles {
            screenFileName(file, prefix: LogPrefix, into: &logs)
        }
        return logs.sorted().reversed()
    }

    // Make a log path from an index
    static func makeLogPath(_ index: Int) -> String {
        return getDocDirectory().appendingPathComponent(LogPrefix).path + String(index)
    }

    // Private implementation methods.

    // One-time initialization of date formatter
    private static func makeDateFormatter() -> ISO8601DateFormatter {
        let ans = ISO8601DateFormatter()
        ans.formatOptions = [.withFullDate, .withFullTime, .withSpaceBetweenDateAndTime]
        return ans
    }

    // One-time initialization of the implicit log
    private static func openLog() -> FileHandle? {
        let fmgr = FileManager.default

        // First scan for existing logs
        let logs = getAllLogIndices()

        var logPath : String

        // If there is no existing log, make a new log with suffix 0.
        if logs.isEmpty {
            logPath = makeLogPath(0)
            fmgr.createFile(atPath: logPath, contents: nil)
        } else {

            // Otherwise, check the size of the newest log.  If we're unable to determine the size we just proceed to reuse but we put an entry in the log
            // saying that we had this anomaly.  It seems better to reuse rather than not, because not reusing will result in one log per session and
            // potentially not enough retained information.  Reusing runs the risk that "some day" the one used log becomes too large, but that can only
            // happen if there are no other occasions to look at it and see that file size determination is failing.
            logPath = makeLogPath(logs[0])
            let fileSize = getFileSize(logPath)
            if (fileSize ?? 0) > LogThreshhold {
                logPath = makeLogPath(logs[0] + 1)
                fmgr.createFile(atPath: logPath, contents: nil)
                discardOldLogs(logs)
            } else if fileSize == nil, let handle = openLog(logPath) {
                log(handle, OpenMessage)
                log(handle, FileSizeAnomaly)
                return handle
            }
        }
        // LogPath now contains the path to use and the file either pre-existed or was just created (therefore, exists with high probability)

        // Open the log.  It's weird for this to fail having come this far, but possible, at least in theory.  We print a message in that case.
        if let handle = openLog(logPath) {
            log(handle, OpenMessage)
            return handle
        } else {
            print(String(format: LogOpenAnomalyTemplate, logPath))
            return nil
        }
    }

    // Discard old logs once you have enough accumulated
    private static func discardOldLogs(_ logs: [Int]) {
        if logs.count > KeepThreshhold {
            for i in KeepThreshhold..<logs.count {
                if let url = URL(string: makeLogPath(i)) {
                    try? FileManager.default.removeItem(at: url)
                }
            }
        }
    }
}
