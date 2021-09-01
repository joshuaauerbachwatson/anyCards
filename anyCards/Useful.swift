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
import AVFoundation

// Miscellaneous Useful extensions and functions.  Note: some dependencies of this file are kept in Logger.swift for packaging reasons.

//
// Extensions
//

/* Java-like String.trim() */
extension String {
    func trim() -> String {
        return self.trimmingCharacters(in: NSCharacterSet.whitespaces)
    }
}

/* Determine if a a size exceeds another in either dimension */
extension CGSize {
    func exceeds(_ other: CGSize) -> Bool {
        return width > other.width || height > other.height
    }
}

/* Make CGPoint hashable, and allow x and y to be swapped */
extension CGPoint : Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.x)
        hasher.combine(self.y)
    }
    var swapped : CGPoint {
        return CGPoint(x: self.y, y: self.x)
    }
}

/* Also add a swapped member to CGSize */
extension CGSize {
    var swapped : CGSize {
        return CGSize(width: self.height, height: self.width)
    }
}

/* Convenient constructor for colors (uses three integers 0-255 for RGB) */
extension UIColor {
    convenience init(_ r: Int, _ g: Int, _ b: Int) {
        let div = CGFloat(255)
        self.init(red: r/div, green: g/div, blue: b/div, alpha: CGFloat(1.0))
    }
}

// 'Screenshot' initializers for UIImage from CALayer or UIView.  The image is created from the layer's content but does not reflect rotation
// that might be imparted by its transform.
extension UIImage {
    convenience init(view: UIView) {
        self.init(layer: view.layer)
    }
    convenience init(layer: CALayer, size: CGSize? = nil) {
        let sizeToUse = size ?? layer.bounds.size // use bounds, not frame, since frame might reflect a transform that will be ignored by the rendering
        UIGraphicsBeginImageContext(sizeToUse)
        layer.render(in:UIGraphicsGetCurrentContext()!)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        self.init(cgImage: image!.cgImage!)
    }
}

// Add 'center' property to CGRect and CALayer
extension CGRect {
    var center : CGPoint {
        get { return CGPoint(x: midX, y: midY) }
        set {
            let dx = midX - minX
            let dy = midY - minY
            origin = newValue - CGPoint(x: dx, y: dy)
        }
    }
}
extension CALayer {
    var center : CGPoint {
        get { return frame.center }
        set { frame.center = newValue }
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

// Add a border to an image
func addBorder(_ image: UIImage, _ borderSize: CGFloat) -> UIImage {
    let imageSize = image.size
    let borderedSize = CGSize(width: imageSize.width + 2 * borderSize, height: imageSize.height + 2 * borderSize)
    let bordered = UIView(frame: CGRect(origin: CGPoint.zero, size: borderedSize))
    bordered.backgroundColor = UIColor.black
    let inner = UIImageView(frame: CGRect(x: borderSize, y: borderSize, width: imageSize.width, height: imageSize.height))
    inner.image = image
    bordered.addSubview(inner)
    return UIImage(view: bordered)
}

// Display a dialog with a cancellation button that does nothing and a second button that does something
func confirmBeforeDoing(host: UIViewController, destructive: Bool, title: String, message: String, doNothing: String, doSomething: String,
                        handler: @escaping ()->Void) {
    let ignore = UIAlertAction(title: doNothing, style: .cancel) { _ in
        // Do nothing if this is chosen
    }
    let proceed = UIAlertAction(title: doSomething, style: destructive ? .destructive : .default) { _ in
        handler()
    }
    let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
    alert.addAction(ignore)
    alert.addAction(proceed)
    Logger.logPresent(alert, host: host, animated: true)
}

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

// Finds the highest used numeric suffix for a given file prefix. Returns -1 if there are no files with that prefix.  Also -1 for any systemic errors
func getMaxSuffixForFilePrefix(_ prefix: String) -> Int {
    let allFiles = (try? FileManager.default.contentsOfDirectory(atPath: getDocDirectory().path)) ?? []
    let targetFiles = allFiles.filter { $0.hasPrefix(prefix) }
    var last = -1
    for file in targetFiles {
        if let next = getSuffix(file, prefix.count) {
            last = max(last, next)
        }
    }
    return last
}

// Move a path by a given translation distance
func movePath(_ path: CGPath, by: CGPoint) -> CGPath? {
    var transform = CGAffineTransform(translationX: by.x, y: by.y)
    return path.copy(using: &transform)
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

// Play a sound.  Returns the player, which must be kept long enough to let the sound complete.
func playSound(_ name: String, _ ext: String) -> AVAudioPlayer? {
    guard let url = Bundle.main.url(forResource: name, withExtension: ext) else { return nil }
    try? AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playback, mode: AVAudioSession.Mode.default)
    try? AVAudioSession.sharedInstance().setActive(true)
    guard let player = try? AVAudioPlayer(contentsOf: url, fileTypeHint: nil) else { return nil }
    player.play()
    return player
}

// Random Bool
func randomBool() -> Bool {
    return arc4random_uniform(2) == 1
}

// Random double in the range -1.0...1.0
func randomDouble() -> Double {
    return drand48() * 2.0 - 1.0
}

// Choose a random origin for a rectangle of a given size to fit entirely inside another rectangle
func randomOrigin(_ size: CGSize, _ outer: CGRect) -> CGPoint {
    let minX = outer.minX
    let minY = outer.minY
    let maxX = outer.maxX - size.width
    let maxY = outer.maxY - size.height
    let x = minX + drand48() * (maxX - minX)
    let y = minY + drand48() * (maxY - minY)
    return CGPoint(x: x, y: y)
}

// Resize an image given the original image and a target rectangle
func resizeImage(_ original: UIImage, to: CGSize) -> UIImage {
    UIGraphicsBeginImageContextWithOptions(to, true, 0.0)
    original.draw(in: CGRect(origin: CGPoint.zero, size: to))
    let scaledImage = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    return scaledImage ?? original
}

// Rotate a CGPath around zero.
func rotatePath(_ path: CGPath, by: CGFloat) -> CGPath? {
    var transform = CGAffineTransform(rotationAngle: by)
    return path.copy(using: &transform)
}

// Rotate one point around another
func rotatePoint(_ point: CGPoint, around: CGPoint, by: CGFloat) -> CGPoint {
    let dx = point.x - around.x
    let dy = point.y - around.y
    let radius = sqrt(dx * dx + dy * dy)
    let azimuth = atan2(dy, dx) + by
    let x = around.x + radius * cos(azimuth)
    let y = around.y + radius * sin(azimuth)
    return CGPoint(x: x, y: y)
}

// Determine the safe area of a main view.  Since we are assuming at least iOS 11, we
// can use the safeAreaInsets property of the view to compute the result.
func safeAreaOf(_ view: UIView) -> CGRect {
    let insets = view.safeAreaInsets
    return view.bounds.inset(by: insets)
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

// Determine if a file exists, using our prefix / suffix style of naming
func userFileExists(prefix: String, suffix: Int) -> Bool {
    let path = getDocDirectory().appendingPathComponent(prefix + String(suffix)).path
    return FileManager.default.fileExists(atPath: path)
}
