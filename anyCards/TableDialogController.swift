//
//  TableDialogController.swift
//  Common
//
//  Created by Joshua Auerbach on 2/14/18.
//  Copyright © 2018 Joshua Auerbach. All rights reserved.
//

import UIKit

// Base class for popover dialogs that make choices from items in a simple table view.   Sections are supported (in "grouped" style) but the implementation is
// biased toward simple cases with just one section.

// The class itself
class TableDialogController : UIViewController, UIPopoverPresentationControllerDelegate,  UITableViewDelegate,  UITableViewDataSource {

    // Constants
    private static let headerText = "Tap on a list item to choose it"
    private static let backgroundColor = UIColor.lightGray
    private static let headerTextColor = UIColor.white
    private static let headerBackground = UIColor.black
    private static let pickerTextColor = UIColor.black
    private static let pickerBackground = UIColor.white
    private static let expectedWidth = CGFloat(300)
    private static let margin = CGFloat(10)
    private static let spacing = CGFloat(6)
    private static let tabletCtlHeight = CGFloat(40)
    private static let phoneCtlHeight = CGFloat(20)
    private static let reuseIdentifier = "tableDialog"

    // Mitigate the obstanacy of Swift
    typealias T = TableDialogController

    // State
    let sectionCount : Int
    private let header = UILabel()
    private var picker : UITableView!  // Delayed init (viewDidLoad)
    private var width = CGFloat(0)  // Will be reset in viewDidLoad

    // Recompute ctlHeight for phones to avoid scrolling issues
    private static var ctlHeight : CGFloat {
        let isPhone = UIScreen.main.traitCollection.userInterfaceIdiom == .phone
        return isPhone ? T.phoneCtlHeight : T.tabletCtlHeight
    }

    // Initialized with the owning view, the size, and the anchor point (optionally, direction with a default of .up and section count with a default of 1)
    init(_ view: UIView, size: CGSize, anchor: CGPoint, direction: UIPopoverArrowDirection = .up, sectionCount: Int = 1) {
        self.sectionCount = sectionCount
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = UIModalPresentationStyle.popover
        preferredContentSize = size
        let popoverPC = self.popoverPresentationController
        popoverPC?.sourceView = view
        popoverPC?.sourceRect = CGRect(origin: anchor, size: CGSize.zero)
        popoverPC?.permittedArrowDirections = direction
        popoverPC?.delegate = self
    }

    // Necessary but useless
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // This is neceesary for popover to work on the iPhone
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
    }

    // Should be closely coordinated with the layout done in viewDidLoad.  This function calculates the approximate height needed to
    // compactly display a given number of rows.  For convenience it returns a size, not just a height, but the width is statically determined.
    class func getPreferredSize(_ rows : Int) -> CGSize {
        let headerY = margin
        let pickerY = headerY + ctlHeight + spacing
        return CGSize(width: expectedWidth, height: pickerY + rows * (ctlHeight + spacing) + margin)
    }

    // Create and layout the subviews
    override func viewDidLoad() {
        // Layout assumes preferred size was respected
        let x = T.margin
        width = preferredContentSize.width - 2 * T.margin
        let headerY = T.margin
        let pickerY = headerY + T.ctlHeight + T.spacing
        let pickerHeight = preferredContentSize.height - pickerY - T.spacing

        // Header
        header.text = T.headerText
        header.textColor = T.headerTextColor
        header.backgroundColor = T.headerBackground
        header.textAlignment = .center
        header.adjustsFontSizeToFitWidth = true
        header.frame = CGRect(x: x, y: headerY, width: width, height: T.ctlHeight)
        view.addSubview(header)

        // Table View
        let frame = CGRect(x: x, y: pickerY, width: width, height: pickerHeight)
        picker = UITableView(frame: frame, style: sectionCount > 1 ? .grouped: .plain) // Satisfies delayed init
        picker.rowHeight = T.ctlHeight + T.spacing
        picker.sectionHeaderHeight = picker.rowHeight
        picker.sectionFooterHeight = 0
        picker.separatorInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        picker.dataSource = self
        picker.delegate = self
        picker.frame = CGRect(x: x, y: pickerY, width: width, height: pickerHeight)
        picker.register(TableDialogCell.self, forCellReuseIdentifier: T.reuseIdentifier)
        view.addSubview(picker)
    }

    // animate the row selection when view appears.  Specializations provide the row via getCurrentRow()
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        let path = getCurrentPath()
        picker.selectRow(at: path, animated: true, scrollPosition: .none)
    }

    // Conform to requirements of this protocol method.  Specializations do the deletion via deletePath or deleteRow
    func tableView(_ tableView: UITableView, commit: UITableViewCell.EditingStyle, forRowAt path: IndexPath) {
        if commit == .delete {
            deletePath(path)
            tableView.deleteRows(at: [path], with: UITableView.RowAnimation.fade)
        } // Ignore insertions for now
    }

    // Conform to requirements of this protocol method.  Specializations initialize the the row text in initializePath
    // or initializeRow
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: T.reuseIdentifier, for: indexPath)
        if let label = cell.textLabel {
            initializePath(label, indexPath)
        }
        return cell
    }

    // Conform to the requirements of this protocol method.  Specializations take row-specific actions.
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if pathSelected(indexPath) {
            Logger.logDismiss(self, host: (presentingViewController ?? self), animated: true)
        }
    }

    // Implement the optional numberOfSections here to avoid the need for subclasses to worry about it since we need to know
    // about sections anyway.  Subclasses still need to implement the 'path' methods for multiple sections.
    func numberOfSections(in tableView: UITableView) -> Int {
        return sectionCount
    }

    // Subclasses must provide real implementations of either the 'row' methods (single section) or the 'path' methods (multiple sections)

    // Called when a row is selected.  Returns true to dismiss the dialog, false to handle dismissal separately
    func rowSelected(_ row: Int) -> Bool {
        Logger.logFatalError("Must implement 'rowSelected'")
    }

    // Provide the information for each row's label
    func initializeRow(_ label: UILabel, _ row: Int) {
        Logger.logFatalError("Must implement 'initializeRow'")
    }

    // Get the currently selected row
    func getCurrentRow() -> Int {
        Logger.logFatalError("Must implement 'getCurrentRow'")
    }

    // Delete from the model given a row number
    func deleteRow(_ row: Int) {
        Logger.logFatalError("Must implement 'deleteRow'")
    }

    // This is also a protocol conformance method but has no generic aspects
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        Logger.logFatalError("Must implement 'tableView(_:numberOfRowsInSection:)'")
    }

    // Subclasses must provide overrides of these methods iff using sections (defaults work only for single section case)

    // Called when a path is selected.  Returns true to dismiss the dialog, false to handle dismissal separately
    func pathSelected(_ path: IndexPath) -> Bool {
        if path.section == 0 {
            return rowSelected(path.row)
        }
        Logger.logFatalError("Must implement 'pathSelected' when there are multiple sections")
    }

    // Provide the information for each path's label
    func initializePath(_ label: UILabel, _ path: IndexPath) {
        if path.section == 0 {
            initializeRow(label, path.row)
            return
        }
        Logger.logFatalError("Must implement 'initializePath' when there are multiple sections")
    }

    // Get the currently selected path
    func getCurrentPath() -> IndexPath {
        if sectionCount == 1 {
            return IndexPath(row: getCurrentRow(), section: 0)
        }
        Logger.logFatalError("Must implement 'getCurrentPath' when there are multiple sections")
    }

    // Delete from the model given a path
    func deletePath(_ path: IndexPath) {
        if path.section == 0 {
            deleteRow(path.row)
            return
        }
        Logger.logFatalError("Must implement 'deletePath' when there are multiple sections")
    }

    // Customize the rows to ensure texts are visible across a range of possible settings for font size
    class TableDialogCell : UITableViewCell {
        override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
            super.init(style: style, reuseIdentifier: reuseIdentifier)
            if let textLabel = self.textLabel {
                textLabel.adjustsFontSizeToFitWidth = true
            }
        }

        required init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
}
