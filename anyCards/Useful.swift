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

// Miscellaneous Useful extensions and functions.

//
// Extensions
//

/* Convenient constructor for colors (uses three integers 0-255 for RGB) */
extension UIColor {
    convenience init(_ r: Int, _ g: Int, _ b: Int) {
        let div = CGFloat(255)
        self.init(red: r/div, green: g/div, blue: b/div, alpha: CGFloat(1.0))
    }
}

/* Java-like String.trim() */
extension String {
    func trim() -> String {
        return self.trimmingCharacters(in: NSCharacterSet.whitespaces)
    }
}

// Simplify some common call sequences to CATransaction
extension CATransaction {
    static func beginNoAnimation() {
        begin()
        setAnimationDuration(0)
    }
    static func withNoAnimation(_ actions: ()->()) {
        beginNoAnimation()
        actions()
        commit()
    }
}

// Allow a size to be chararactized as landscape-y or portrait-y
extension CGSize {
var landscape: Bool {
        get {
            return width > height
        }
    }
}

//
// Operators
//

/* Permit addition of two points (allows a translation to be applied to a point) */
func + (_ p: CGPoint, _ q: CGPoint) -> CGPoint {
    return CGPoint(x: p.x + q.x, y: p.y + q.y)
}

/* Permit subtraction of two points (allows a translation to be applied to a point in a negative direction) */
func - (_ p: CGPoint, _ q: CGPoint) -> CGPoint {
    return CGPoint(x: p.x - q.x, y: p.y - q.y)
}

/* Permits a point (translation) to be added to a rectangle */
func + (_ rect: CGRect, _ q: CGPoint) -> CGRect {
    return CGRect(origin: rect.origin + q, size: rect.size)
}

/* Permits a point (translation) to be subtracted from a rectangle */
func - (_ rect: CGRect, _ q: CGPoint) -> CGRect {
    return CGRect(origin: rect.origin - q, size: rect.size)
}

/* Multiplies a point by a scale factor */
func * (_ point: CGPoint, _ scale: CGFloat) -> CGPoint {
    return CGPoint(x: point.x * scale, y: point.y * scale)
}

/* Multiplies a size by a scale factor (using CGAffineTransform) */
func * (_ size: CGSize, _ scale: CGFloat) -> CGSize {
    return size.applying(CGAffineTransform(scaleX: scale, y: scale))
}

/* Applies a scale factor to a rectangle (using CGAffineTransform) */
func * (_ rect: CGRect, _ scale: CGFloat) -> CGRect {
    return rect.applying(CGAffineTransform(scaleX: scale, y: scale))
}

//
// Functions (alphabetical)
//

// Crop an image to a given rectangle
func cropImage(_ original: UIImage, _ rect: CGRect) -> UIImage {
    // A correct cropping requires the image to be in the "up" orientation, so we first assure that.
    let imageToCrop = ensureUpOrientation(original)
    // Cropping is available at the CGImage level, so get that form
    guard let cgi = imageToCrop.cgImage else { return original }  // Hopefully, won't return here (our images should have CGImage properties)
    // Adjust cropping rectangle to the scale of the image
    let scale = imageToCrop.scale
    let cropRect = rect.applying(CGAffineTransform(scaleX: scale, y: scale))
    // Perform cropping
    guard let newcgi = cgi.cropping(to: cropRect) else { return original } // Again, hoping ...
    // Restore to UIImage form, restoring scale as well.
    let ans = UIImage(cgImage: newcgi, scale: scale, orientation: .up)
    return ans
}

// Ensure that an image is in the "up" orientation by redrawing it if not
func ensureUpOrientation(_ image: UIImage)->UIImage {
    if image.imageOrientation == .up {
        return image
    }
    UIGraphicsBeginImageContextWithOptions(image.size, true, 1.0)
    image.draw(at: .zero)
    let newImage = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    return newImage ?? image
}

// Get documents directory as a URL.  This method will crash the app if there is no documents directory, but I believe that never happens.
func getDocDirectory() -> URL {
    if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
        return docs
    }
    // There is no point in logging the error since (1) when debugging the fatalError will report its text on the console and (2) in production there is no
    // way to log the error without a doc directory
    fatalError("Documents directory is missing")
}

// Get the size of a file, if possible (returns nil if the attempt fails, but I don't believe this is likely)
func getFileSize(_ path: String) -> UInt64? {
    let fileAttributes = try? FileManager.default.attributesOfItem(atPath: path)
    let size = fileAttributes?[FileAttributeKey.size]
    return (size as? NSNumber)?.uint64Value
}

// Get the suffix portion of a file name in prefix/suffix form
func getSuffix(_ file: String, _ prefixLen: Int) -> Int? {
    let indexFrom = file.index(file.startIndex, offsetBy: prefixLen)
    return Int(file.suffix(from: indexFrom))
}

// Determine the safe area of a main view.  Since we are assuming at least iOS 11, we
// can use the safeAreaInsets property of the view to compute the result.
func safeAreaOf(_ view: UIView) -> CGRect {
    let insets = view.safeAreaInsets
    return view.bounds.inset(by: insets)
}

// Parse a file name into prefix and suffix form while looking for a particular prefix; useful when scanning a folder for files of a given kind
// Boolean return aids in chaining when scanning for multiple kinds in a single pass
@discardableResult
func screenFileName(_ file: String, prefix: String, into: inout [Int]) -> Bool {
    if file.hasPrefix(prefix), let suffix = getSuffix(file, prefix.count) {
        into.append(suffix)
        return true
    }
    return false
}

// Provide a shuffled version of an array
func shuffle<T>(_ array : [T]) -> [T] {
    var holder = [T]()
    holder.append(contentsOf: array)
    var ans = [T]()
    while !holder.isEmpty {
        let toRemove = Int(arc4random_uniform(UInt32(holder.count)))
        ans.append(holder.remove(at: toRemove))
    }
    return ans
}

// Special packaging of bummer for noting holes in the implementation during development (shouldn't be called in production).
// To allow it to be called in tight places, it will present on the console if no host is given to present the dialog.
// If a host is given, the dialog is always attempted but does not always work since the host could be busy with another dialog or
// may not be fully initialized.  We don't test for these conditions because there isn't a solidly reliable test.   If the dialog
// fails, it will result in a message on the console, but a less informative one.
func notImplemented(_ function: String, host maybeHost: UIViewController?) {
    if let host = maybeHost {
        bummer(title: "Not Implemented", message: "You need to write the code for \(function)", host: host)
    } else {
        print("Not implemented: you need to write the code for \(function)")
    }
}

