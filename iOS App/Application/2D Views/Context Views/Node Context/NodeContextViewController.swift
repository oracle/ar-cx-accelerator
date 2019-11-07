//
// *********************************************************************************************
// Copyright © 2019. Oracle and/or its affiliates. All rights reserved.
// Licensed under the Universal Permissive License v 1.0 as shown at
// http://oss.oracle.com/licenses/upl
// *********************************************************************************************
// Accelerator Package: Augmented CX
// Date: 8:21 AM 9/28/18
// *********************************************************************************************
// File: NodeContextViewController.swift
// *********************************************************************************************
// 

import UIKit
import Charts
import os

protocol NodeContextDelegate: class {
    /**
     Informs the delegate class that the list service requests button was pressed.
     
     - Parameter sender: The controller sending the request to the delegate.
     - Parameter completion: Callback method called after the action taken by the delegate is completed.
    */
    func listServiceRequestsHandler(_ sender: NodeContextViewController?, completion: (() -> ())?)
    
    /**
     Informs the delegate class that the list notes button was pressed.
     
     - Parameter sender: The controller sending the request to the delegate.
     - Parameter nodeName: The name of the seleceted node on the 3D model.
     - Parameter completion: Callback method called after the action taken by the delegate is completed.
     */
    func listNotesHandler(_ sender: NodeContextViewController?, nodeName: String, completion: (() -> ())?)
    
    /**
     Informs the delegate class that the print button was pressed.
     
     - Parameter sender: The controller sending the request to the delegate.
     - Parameter completion: Callback method called after the action taken by the delegate is completed.
     */
    func printItemHandler(_ sender: NodeContextViewController?, completion: (() -> ())?)
    
    /**
     Informs the delegate class that the order item button was pressed.
     
     - Parameter sender: The controller sending the request to the delegate.
     - Parameter completion: Callback method called after the action taken by the delegate is completed.
     */
    func orderItemHandler(_ sender: NodeContextViewController?, completion: (() -> ())?)
    
    /**
     Informs the delegate class that the show PDF action was pressed.
     
     - Parameter sender: The controller sending the request to the delegate.
     - Parameter answer: The answer which links to the PDF to be displayed.
     - Parameter completion: Callback method called after the action taken by the delegate is completed.
     */
    func showPdfHandler(_ sender: NodeContextViewController?, answer: AnswerResponse, completion: (() -> ())?)
    
    /**
     Informs the delegate class that the sensors button was pressed to either hide or show sensors.
     
     - Parameter sender: The controller sending the request to the delegate.
     - Parameter completion: Callback method called after the action taken by the delegate is completed.
     */
    func showSensorsHandler(_ sender: NodeContextViewController?, completion: (() -> ())?)
    
    /**
     Informs the delegate class that a procedure was selected was pressed.
     
     - Parameter sender: The controller sending the request to the delegate.
     - Parameter procedure: The procedure that was selected by the user.
     - Parameter completion: Callback method called after the action taken by the delegate is completed.
     */
    func proceduresHandler(_ sender: NodeContextViewController?, procedure: ARProcedure, completion: (() -> ())?)
    
    /**
     Informs the delegate class that an image was selected from the image carousel.
     
     - Parameter sender: The controller sending the request to the delegate.
     - Parameter index: The index of the image that was selected from the collection view.
     - Parameter completion: Callback method called after the action taken by the delegate is completed.
     */
    func imageTappedHandler(_ sender: NodeContextViewController?, index: Int, completion: (() -> ())?)
    
    /**
     Informs the delegate class that a node context action was selected.
     
     - Parameter sender: The controller sending the request to the delegate.
     - Parameter action: The action that was selected.
     - Parameter completion: Callback method called after the action taken by the delegate is completed.
     */
    func nodeContextActionHandler(_ sender: NodeContextViewController?, action: ARNodeContext.TableRow.Action, completion: (() -> ())?)
}

class NodeContextViewController: UIViewController, ContextViewController, UITableViewDelegate, UITableViewDataSource, UICollectionViewDelegate, UICollectionViewDataSource, UIGestureRecognizerDelegate, ChartViewDelegate {
    
    // MARK: - IBOutlets
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet var panRecognizer: UIPanGestureRecognizer!
    @IBOutlet weak var draggerView: UIView!
    @IBOutlet weak var draggerHandle: UIImageView!
    
    //MARK: - Enums
    
    /**
     Enum to identify the table sections that will appear in the table view.
    */
    enum tableSections: Int, CaseIterable {
        case actions = 0,
        charts,
        images,
        procedures,
        bulletins,
        manuals
    }
    
    /**
     Enum to identify the action buttons available in the view.
     */
    enum actionButtons: String, CaseIterable {
        case srHistory = "srHistoryButton",
        listNotes = "listNotesButton",
        threeDPrint = "threeDPrintButton",
        order = "orderButton",
        sensors = "sensorsButton"
    }
    
    // MARK: - Properties
    
    /**
     Delegate object for this class.
     */
    weak var delegate: NodeContextDelegate?
    
    /**
     The default width that this controller should assign to its view on resize and display.
     */
    private var viewWidth: CGFloat?
    
    /**
     The minimum width that the view can be resized to by dragging
     */
    private var minWidth: CGFloat = 222
    /**
     The deviceId of the selected node.
     */
    private var applicationId: String?
    
    /**
     The deviceId of the selected node.
     */
    private var deviceId: String?
    
    /**
     The name of the node selected in the AR space in case we need to display it as text.
     */
    private var nodeName: String?
    
    /**
     Array to maintain which sections are hidden.
    */
    private var hiddenSections: [Int] = []
    
    /**
     Object that will hold the line chart data sets when charting is displayed in the context view.
     */
    private var chartData: LineChartData?
    
    /// The number of entries to show in the sensor chart.
    var chartEntriesToShow = 25
    
    /**
     Programmatic creation of the srHistory button.
     */
    lazy var srHistoryButton: UIButton? = {
        let buttonColor = #colorLiteral(red: 0.1685094237, green: 0.384334594, blue: 0.258785367, alpha: 1)
        let button = try? UIButton.roundRectButton(icon: FontAwesomeSolid.handsHelping, label: "Svc Requests", backgroundColor: buttonColor, textColor: UIColor.white, fontSize: 9, frame: CGRect(x: 2, y: 2, width: 58, height: 58))
        button?.addTarget(self, action: #selector(self.listServiceRequestHandler(_:)), for: .touchUpInside)
        button?.restorationIdentifier = NodeContextViewController.actionButtons.srHistory.rawValue
        
        return button
    }()
    
    /**
     Programmatic creation of the srHistory button.
     */
    lazy var noteHistoryButton: UIButton? = {
        let buttonColor = #colorLiteral(red: 0.1724567413, green: 0.3490424454, blue: 0.4038673043, alpha: 1)
        let button = try? UIButton.roundRectButton(icon: FontAwesomeSolid.newspaper, label: "Notes", backgroundColor: buttonColor, textColor: UIColor.white, frame: CGRect(x: 2, y: 2, width: 58, height: 58))
        button?.addTarget(self, action: #selector(self.listNotesHandler(_:)), for: .touchUpInside)
        button?.restorationIdentifier = NodeContextViewController.actionButtons.listNotes.rawValue
        
        return button
    }()
    
    /**
     Programmatic creation of the threeDPrint button.
     */
    lazy var threeDPrintButton: UIButton? = {
        let buttonColor = #colorLiteral(red: 0.5450543761, green: 0.5215986967, blue: 0.5018989444, alpha: 1)
        let button = try? UIButton.roundRectButton(icon: FontAwesomeSolid.print, label: "3D Print", backgroundColor: buttonColor, textColor: UIColor.white, frame: CGRect(x: 2, y: 2, width: 58, height: 58))
        button?.addTarget(self, action: #selector(self.printItemHandler(_:)), for: .touchUpInside)
        button?.restorationIdentifier = NodeContextViewController.actionButtons.threeDPrint.rawValue
        
        return button
    }()
    
    /**
     Programmatic creation of the order button.
     */
    lazy var orderButton: UIButton? = {
        let buttonColor = #colorLiteral(red: 0.3372283578, green: 0.3137445748, blue: 0.2940791547, alpha: 1)
        let button = try? UIButton.roundRectButton(icon: FontAwesomeSolid.receipt, label: "Order", backgroundColor: buttonColor, textColor: UIColor.white, frame: CGRect(x: 2, y: 2, width: 58, height: 58))
        button?.addTarget(self, action: #selector(self.orderItemHandler(_:)), for: .touchUpInside)
        button?.restorationIdentifier = NodeContextViewController.actionButtons.order.rawValue
        
        return button
    }()
    
    /**
     Programmatic creation of the sensors button.
     */
    lazy var sensorsButton: UIButton? = {
        let buttonColor = #colorLiteral(red: 0.6823546886, green: 0.3372728527, blue: 0.1725513339, alpha: 1)
        let button = try? UIButton.roundRectButton(icon: FontAwesomeSolid.tachometerAlt, label: "Sensors", backgroundColor: buttonColor, textColor: UIColor.white, frame: CGRect(x: 2, y: 2, width: 58, height: 58))
        button?.addTarget(self, action: #selector(self.showSensorsHandler(_:)), for: .touchUpInside)
        button?.restorationIdentifier = NodeContextViewController.actionButtons.sensors.rawValue
        
        return button
    }()
    
    /**
     Contains the UIButtons that will appear in the action buttons collection view.
    */
    private var actionButtons: [UIButton] = []
    
    /**
     Object that contains metadata that will describe the selected node in the AR experience.
     */
    private(set) var arNodeContext: ARNodeContext?
    
    /**
     An array of answers to show as the list of bulletins.
     */
    private(set) var bulletins: [AnswerResponse]?
    
    /**
     An array of answers to show as the list of manuals.
     */
    private(set) var manuals: [AnswerResponse]?

    // MARK: - UIViewController Methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.moveFrameOutOfView()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super .viewDidAppear(animated)
        
        self.resizeForContent()
    }
    
    // MARK: - IBActions
    
    @IBAction func showSensorsHandler(_ sender: UIButton) {
        sender.isEnabled = false
        
        sender.logClick()
        
        delegate?.showSensorsHandler(self) {
            DispatchQueue.main.async {
                sender.isEnabled = true
            }
        }
    }
    
    @IBAction func listServiceRequestHandler(_ sender: UIButton) {
        sender.isEnabled = false
        
        sender.logClick()
        
        delegate?.listServiceRequestsHandler(self) {
            DispatchQueue.main.async {
                sender.isEnabled = true
            }
        }
    }
    
    @IBAction func listNotesHandler(_ sender: UIButton) {
        guard let nodeName = self.nodeName else { return }
        
        sender.logClick()
        
        sender.isEnabled = false
        
        delegate?.listNotesHandler(self, nodeName: nodeName) {
            DispatchQueue.main.async {
                sender.isEnabled = true
            }
        }
    }
    
    @IBAction func printItemHandler(_ sender: UIButton) {
        sender.isEnabled = false
        
        sender.logClick()
        
        delegate?.printItemHandler(self) {
            DispatchQueue.main.async {
                sender.isEnabled = true
            }
        }
    }
    
    @IBAction func orderItemHandler(_ sender: UIButton) {
        sender.isEnabled = false
        
        sender.logClick()
        
        delegate?.orderItemHandler(self) {
            DispatchQueue.main.async {
                sender.isEnabled = true
            }
        }
    }
    
    // MARK: - UIGestureRecognizerDelegate Methods
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return false
    }
    
    @IBAction func panning(_ sender: UIPanGestureRecognizer) {
        guard let parent = self.parent else { return }
        
        let frameHeight = self.view.frame.size.height
        let newX: CGFloat = sender.location(in: parent.view).x
        
        // If the drag is greater than the min width setting, then resize
        if newX > self.minWidth && newX < parent.view.frame.size.width {
            let newSize = CGSize(width: newX, height: frameHeight)
            self.view.frame.size = newSize
            
            if sender.state == .ended {
                self.tableView.reloadData()
            }
        }
        // If less than, move the panel to hide
        else if newX <= self.minWidth {
            let velocity = sender.velocity(in: parent.view)
            
            let xOffset = -self.view.frame.size.width + newX + parent.view.safeAreaInsets.left
            let y = self.view.frame.origin.y
            let newOrigin = CGPoint(x: xOffset, y: y)
            
            self.view.frame.size = CGSize(width: self.minWidth, height: self.view.frame.size.height)
            self.view.frame.origin = newOrigin
            
            if sender.state == .ended {
                if velocity.x < -500 {
                    
                    let hideX = -self.view.frame.size.width + self.draggerView.frame.size.width + parent.view.safeAreaInsets.left
                    let hidePoint = CGPoint(x: hideX, y: y)
                    
                    UIView.animate(withDuration: 0.25, animations: {
                        self.view.frame.origin = hidePoint
                    }) { (done) in
                        os_log(.debug, "Moved")
                    }
                } else {
                    self.resizeForContent()
                }
            }
        }
    }
    
    
    // MARK: - UITableViewDataSource Methods
    
    func numberOfSections(in tableView: UITableView) -> Int {
        let contextSectionCount = arNodeContext?.tableSections?.count ?? 0
        return tableSections.allCases.count + contextSectionCount
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        if self.hiddenSections.contains(section) {
            return 0
        }
        
        switch section {
        case tableSections.actions.rawValue:
            return 1
        case tableSections.charts.rawValue:
            return arNodeContext != nil && arNodeContext!.sensors != nil && arNodeContext!.sensors!.count > 0 ? 1 : 0
        case tableSections.images.rawValue:
            return arNodeContext != nil && arNodeContext!.images != nil && arNodeContext!.images!.count > 0 ? 1 : 0
        case tableSections.bulletins.rawValue:
            return bulletins != nil ? bulletins!.count : 0
        case tableSections.manuals.rawValue:
            return manuals != nil ? manuals!.count : 0
        case tableSections.procedures.rawValue:
            return arNodeContext != nil && arNodeContext!.procedures != nil ? arNodeContext!.procedures!.count : 0
        default:
            guard let nodeSection = self.nodeContextSection(from: section) else { return 0 }
            guard let rows = nodeSection.rows else { return 0 }
            
            return rows.count
        }
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let cell: NodeContextHeaderTableViewCell = tableView.dequeueReusableCell(withIdentifier: "SectionHeaderCell")! as! NodeContextHeaderTableViewCell
        
        cell.hideButton.addTarget(self, action: #selector(hideSectionHandler(_:)), for: .touchUpInside)
        cell.hideButton.tag = section
        
        if self.hiddenSections.contains(section) {
            if let icon = FontAwesomeSolid.plusSquare.rawValue.toUnicodeCharacter {
                cell.hideButton.setTitle("\(icon)", for: .normal)
            }
        }
        
        switch section {
        case tableSections.actions.rawValue:
            cell.headerLabel.text = "Actions"
        case tableSections.charts.rawValue:
            cell.headerLabel.text = "Sensor History"
        case tableSections.images.rawValue:
            cell.headerLabel.text = "Images"
        case tableSections.bulletins.rawValue:
            cell.headerLabel.text = "Bulletins"
        case tableSections.manuals.rawValue:
            cell.headerLabel.text = "Manuals"
        case tableSections.procedures.rawValue:
            cell.headerLabel.text = "Procedures"
        default:
            guard let nodeSection = self.nodeContextSection(from: section) else { break }
            guard let name = nodeSection.name else { break }
            
            cell.headerLabel.text = name
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        var height: CGFloat = 44
        
        switch section {
        case tableSections.actions.rawValue:
            height = self.actionButtons.count > 0 ? height : 0
        case tableSections.charts.rawValue:
            height = arNodeContext != nil && arNodeContext!.sensors != nil && arNodeContext!.sensors!.count > 0 ? height : 0
        case tableSections.images.rawValue:
            height = arNodeContext != nil && arNodeContext!.images != nil && arNodeContext!.images!.count > 0 ? height : 0
        case tableSections.bulletins.rawValue:
            height = self.bulletins != nil && self.bulletins!.count > 0 ? height : 0
        case tableSections.manuals.rawValue:
            height = self.manuals != nil && self.manuals!.count > 0 ? height : 0
        case tableSections.procedures.rawValue:
            height = arNodeContext != nil && arNodeContext!.procedures != nil && arNodeContext!.procedures!.count > 0 ? height : 0
        default:
            break
        }
        
        return height
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell: UITableViewCell = tableView.dequeueReusableCell(withIdentifier: "LoadingCell")!
        
        switch indexPath.section {
        case tableSections.actions.rawValue:
            cell = tableView.dequeueReusableCell(withIdentifier: "AllButtons") as! AllButtonsTableViewCell
            (cell as! AllButtonsTableViewCell).collectionView.reloadData()
            cell.accessoryType = .none
            cell.imageView?.image = nil
        case tableSections.charts.rawValue:
            cell = tableView.dequeueReusableCell(withIdentifier: "LineChartCell") as! LineChartTableViewCell
            (cell as! LineChartTableViewCell).activityIndicator.startAnimating()
            (cell as! LineChartTableViewCell).chartView.noDataText = ""
            (cell as! LineChartTableViewCell).chartView.xAxis.labelTextColor = .white
            (cell as! LineChartTableViewCell).chartView.leftAxis.labelTextColor = .white
            (cell as! LineChartTableViewCell).chartView.rightAxis.enabled = false
            (cell as! LineChartTableViewCell).chartView.legend.textColor = .white
            cell.accessoryType = .none
            cell.imageView?.image = nil
            
            if self.chartData == nil {
                self.getIoTHistory(chartCell: (cell as! LineChartTableViewCell), completion: nil)
            } else {
                (cell as! LineChartTableViewCell).chartView.data = self.chartData!
                (cell as! LineChartTableViewCell).activityIndicator.stopAnimating()
            }
        case tableSections.images.rawValue:
            cell = tableView.dequeueReusableCell(withIdentifier: "ImagesCell") as! ImagesTableViewCell
            (cell as! ImagesTableViewCell).collectionView.reloadData()
            cell.accessoryType = .none
            cell.imageView?.image = nil
        case tableSections.bulletins.rawValue:
            cell = tableView.dequeueReusableCell(withIdentifier: "ContextSubtitleCell")!
            let data = self.bulletins![indexPath.row]
            cell.textLabel!.text = data.title
            cell.detailTextLabel!.text = String(format: "Version: %@", data.version ?? "0")
            cell.accessoryType = .disclosureIndicator
            cell.imageView?.image = nil
        case tableSections.manuals.rawValue :
            cell = tableView.dequeueReusableCell(withIdentifier: "ContextSubtitleCell")!
            let data = self.manuals![indexPath.row]
            cell.textLabel!.text = data.title
            cell.detailTextLabel!.text = String(format: "Version: %@", data.version ?? "0")
            cell.accessoryType = .disclosureIndicator
            cell.imageView?.image = nil
        case tableSections.procedures.rawValue:
            cell = tableView.dequeueReusableCell(withIdentifier: "ContextSubtitleCell")!
            let data = arNodeContext!.procedures![indexPath.row]
            cell.textLabel!.text = data.name
            cell.detailTextLabel!.text = data.description
            cell.imageView?.image = data.image?.getImage()?.scaleImage(CGSize(width: 30, height: 30))
            cell.accessoryType = .disclosureIndicator
        default:
            guard let nodeSection = self.nodeContextSection(from: indexPath.section) else { return cell }
            guard let rows = nodeSection.rows else { return cell }
            let data = rows[indexPath.row]
            
            cell = tableView.dequeueReusableCell(withIdentifier: "ContextSubtitleCell")!
            cell.textLabel!.text = data.title
            cell.detailTextLabel!.text = data.subtitle
            cell.imageView?.image = data.image?.getImage()?.scaleImage(CGSize(width: 30, height: 30))
            cell.accessoryType = .none
            
            if data.action != nil {
                cell.accessoryType = .disclosureIndicator
            }
            
            break
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        var height: CGFloat = 44
        let halfFrameWidth = self.view.frame.width / 2
        
        switch indexPath.section {
        case tableSections.actions.rawValue:
            if self.actionButtons.count > 0 {
                let tableWidth = self.view.frame.size.width
                let buttonLength: Double = 66
                let buttonRatio = Double(tableWidth) / buttonLength
                let rowRatio = Double(self.actionButtons.count) / buttonRatio.rounded(.down)
                let numRows = rowRatio.rounded(.up)
                height = CGFloat(buttonLength * numRows)
            }
        case tableSections.charts.rawValue:
            height = halfFrameWidth >= 150 ? halfFrameWidth : 150
        case tableSections.images.rawValue:
            height = 150
        default:
            break
        }
        
        return height
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        // If the table view is smaller than the parent view, then resize the parent to match the table.
        guard let lastVisibleIndexPath = tableView.indexPathsForVisibleRows?.last else { return }
        
        if indexPath == lastVisibleIndexPath {
            self.resizeForContent()
        }
    }
    
    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        // Our convention for this table is that any cell with a disclosure indicator accepts a tap
        guard let cell = tableView.cellForRow(at: indexPath) else { return false }
        return cell.accessoryType == .disclosureIndicator
    }
    
    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        #if DEBUG
        os_log(.debug, "Will select row at path: %@", indexPath.debugDescription)
        #endif
        
        return indexPath
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        #if DEBUG
        os_log(.debug, "Did select row at: %@", indexPath.debugDescription)
        #endif
        
        switch indexPath.section {
        case tableSections.bulletins.rawValue:
            guard let article = self.bulletins?[indexPath.row] else { return }
            
            AppEventRecorder.shared.record(name: "Open Bulletin Pressed", eventStart: Date(), eventEnd: nil, eventLength: 0.0, uiElement: article.title, arAnchor: nil, arNode: self.nodeName, jsonString: nil, completion: nil)
            
            self.delegate?.showPdfHandler(self, answer: article, completion: nil)
            
            break
        case tableSections.manuals.rawValue:
            guard let article = self.manuals?[indexPath.row] else { return }
            
            AppEventRecorder.shared.record(name: "Open Manual Pressed", eventStart: Date(), eventEnd: nil, eventLength: 0.0, uiElement: article.title, arAnchor: nil, arNode: self.nodeName, jsonString: nil, completion: nil)
            
            self.delegate?.showPdfHandler(self, answer: article, completion: nil)
            
            break
        case tableSections.procedures.rawValue:
            guard let procedure = self.arNodeContext?.procedures?[indexPath.row] else { return }
            
            AppEventRecorder.shared.record(name: "Open Procedure Pressed", eventStart: Date(), eventEnd: nil, eventLength: 0.0, uiElement: procedure.name, arAnchor: nil, arNode: self.nodeName, jsonString: nil, completion: nil)
            
            self.delegate?.proceduresHandler(self, procedure: procedure, completion: nil)
            
            break
        default:
            guard let nodeSection = self.nodeContextSection(from: indexPath.section) else { return }
            guard let rows = nodeSection.rows else { return }
            guard let action = rows[indexPath.row].action else { return }
            
            AppEventRecorder.shared.record(name: "Open Custom Context Action Pressed", eventStart: Date(), eventEnd: nil, eventLength: 0.0, uiElement: action.url, arAnchor: nil, arNode: self.nodeName, jsonString: nil, completion: nil)
            
            self.delegate?.nodeContextActionHandler(self, action: action, completion: nil)
            
            return
        }
    }
    
    //MARK: - UICollectionViewDataSource Methods
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if collectionView.restorationIdentifier == "AllButtonsCollectionView" {
            return self.actionButtons.count
        }
        else if collectionView.restorationIdentifier == "ImagesCollectionView" {
            return self.arNodeContext?.images?.count ?? 0
        }
        
        return 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        var cell: UICollectionViewCell!
        
        if collectionView.restorationIdentifier == "AllButtonsCollectionView" {
            let button = self.actionButtons[indexPath.row]
            cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ActionButtonCell", for: indexPath)
            cell.contentView.addSubview(button)
        }
        else if collectionView.restorationIdentifier == "ImagesCollectionView" {
            cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ImageCell", for: indexPath)
            
            let image = self.arNodeContext?.images?[indexPath.row].getImage()
            let imageView = UIImageView(image: image)
            imageView.frame = CGRect(x: 0, y: 0, width: cell.frame.size.width, height: cell.frame.size.height)
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
            
            cell.contentView.addSubview(imageView)
            cell.layoutIfNeeded()
            
            let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.imageTapped(_:)))
            tapRecognizer.numberOfTapsRequired = 1
            tapRecognizer.numberOfTouchesRequired = 1
            cell.addGestureRecognizer(tapRecognizer)
        }
        
        return cell
    }
    
    //MARK: - View Manipulation Methods
    
    /**
     Moves this controllers out of the visible area based on the parent view's frame.
     */
    internal func moveFrameOutOfView(){
        guard let parentView = self.parent?.view else { return }
        
        let yPosition = parentView.frame.size.height / 2 - view.frame.size.height / 2
        view.frame.size.width = CGFloat(self.viewWidth ?? 222)
        view.frame.origin.x = -view.frame.size.width
        view.frame.origin.y = yPosition
    }
    
    /**
     Resizes the view based on the orientation of the device and the height of the frame.
     
     - Parameter duration: The length in seconds that the movement animation will take.
     - Parameter completion: Callback method called once the animation has completed.
     */
    func resizeForContent(_ duration: Double = 0.25, completion: (() -> ())? = nil) {
        guard let parentView = self.parent?.view else { return }
        
        UIView.animate(withDuration: duration, animations: {
            self.tableView.layoutIfNeeded()
            
            let eightyPercentOfHeight = (parentView.frame.size.height * 0.8)
            let contentHeight = self.tableView.contentSize.height
            let viewHeight = contentHeight < eightyPercentOfHeight ? contentHeight : eightyPercentOfHeight
            
            self.view.frame.size = CGSize(width: self.view.frame.size.width, height: viewHeight + 10)
            
            //Calculate new yposition from frame size change
            let yPosition =  parentView.frame.size.height / 2 - self.view.frame.size.height / 2
            
            self.view.frame.origin.x = parentView.safeAreaInsets.left
            self.view.frame.origin.y = yPosition
        }, completion: { (res) in
            completion?()
        })
    }
    
    /**
     Animates the removal of the view and then removes it from the superview.
     
     - Parameter completion: Callback method called once the animation has completed.
     */
    func removeView(completion: (() -> ())?) {
        UIView.animate(withDuration: 0.25, animations: {
            self.view.frame.origin.x = -self.view.frame.size.width
        }) { (res) in
            DispatchQueue.main.async {
                self.view.removeFromSuperview()
                
                self.removeFromParent()
            }
            
            completion?()
        }
    }
    
    // MARK: - Data Manipulation Methods
    
    /**
     Changes the contents of this controller based on the selection of a new part in the AR view.
     
     - Parameter name: The name of the SCNNode/Part that was selected.
     - Parameter device: The ID of the device that was selected.
     - Parameter appId: The application ID of the device that was selected.
     */
    func setNode(name: String, device: String, appId: String){
        // Ensure that there is actually a name change
        guard name != self.nodeName else { return }
        
        // Set the node name on this class.
        self.nodeName = name
        self.deviceId = device
        self.applicationId = appId
        
        // Remove existing actions or kb results when setting part name as they should be reset with the new part for context
        self.arNodeContext = nil
        self.bulletins = nil
        self.manuals = nil
        
        self.actionButtons.removeAll()
        
        let reloadTable: () -> () = {
            DispatchQueue.main.async {
                guard !self.tableView.hasUncommittedUpdates else { return }
                self.tableView.reloadData()
                self.tableView.endUpdates()
                self.resizeForContent()
            }
        }
        
        reloadTable()
        
        // get knowledgebase data
        let answerSearch = String(format: "*%@*", name)
        var bulletinsRetrieved = false
        var manualsRetrieved = false
        
        let knowledgeRequestHandler: () -> () = {
            guard name == self.nodeName else {
                #if DEBUG
                os_log(.debug, "Node name does not match name assigned to class. Will not proceed with knowledge.")
                #endif
                
                return
            }
            
            // Give a very slight delay in the check as a quick API response seems to reload the table before manual data is available
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                if bulletinsRetrieved && manualsRetrieved {
                    reloadTable()
                }
            }
        }
        
        // Get bulletins for item selected
        self.getKnowledgeArticles(contentType: "TECH_BULLETINS", titleSearches: [answerSearch]) { (answers) in
            #if DEBUG
            os_log(.debug, "Bulletins request finished")
            #endif
            
            bulletinsRetrieved = true
            
            guard let answers = answers, answers.count > 0 else { return }
            
            self.bulletins = answers
            
            knowledgeRequestHandler()
        }
        
        // Get manuals for item selected
        self.getKnowledgeArticles(contentType: "MANUALS", titleSearches: [answerSearch]) { (answers) in
            #if DEBUG
            os_log(.debug, "Manuals request finished")
            #endif
            
            manualsRetrieved = true
            
            guard let answers = answers, answers.count > 0 else { return }
            
            self.manuals = answers
            
            knowledgeRequestHandler()
        }
        
        // Get node data (specifications, procedures, etc.) for node name selected
        self.getNodeData { (nodeContext) in
            // Ensure the node context has data and that this record is for the node name currently assigned to this controller
            guard let nodeContext = nodeContext, nodeContext.name == name else { return }
            
            self.arNodeContext = nodeContext
            
            // Reload immediately once node data is accessed.
            reloadTable()
            
            // Get nodes for this node
            DispatchQueue.main.async {
                self.getNotesForNode(nodeContext, completion: { (notes) in
                    guard let notes = notes, nodeContext.name == self.arNodeContext?.name else { return }
                    
                    self.arNodeContext?.setNotes(notes)
                    
                    // Reload the table again with the notes
                    reloadTable()
                })
            }
        }
    }
    
    /**
     Allows for adding contextual buttons at defined positions in the button collection view.
     
     - Parameter button: The button to add to the action buttons collection.
     - Parameter index: The index to place the button.
     */
    func addActionButton(_ button: UIButton, at index: Int? = nil) {
        guard !self.actionButtons.contains(button) else { return }
        
        if index == nil {
            self.actionButtons.append(button)
        } else {
            self.actionButtons.insert(button, at: index!)
        }
        
        tableView.reloadData()
    }
    
    /**
     Removes an action button from the action buttons array and updates the tableview and collection view to reflect the change.
     
     - Parameter identifier: The reusable identifier of the button to remove.
     */
    func removeActionButton(_ identifier: String) {
        let filtered = self.actionButtons.filter { $0.restorationIdentifier != identifier }
        self.actionButtons = filtered
        
        tableView.reloadData()
    }
    
    /**
     Removes all action buttons from view.
     */
    func removeActionButtons() {
        self.actionButtons.removeAll()
        
        tableView.reloadData()
    }
    
    /**
     Performs requests to the knowledge / ICS models to get answer data.
     
     - Parameter contentType: The KB contentType that should be used in the search.
     - Parameter titleSearches: An array of strings to filter search by using the answers title.
     - Parameter completion: Callback method once the KB query is completed.
     - Parameter answers: An array of answers.
     */
    private func getKnowledgeArticles(contentType: String, titleSearches: [String], completion: @escaping (_ answers: [AnswerResponse]?) -> ()) {
        guard let nodeName = self.nodeName else { completion(nil); return }
        
        #if DEBUG
        os_log(.debug, "Searching KB for %@", nodeName)
        #endif
        
        do {
            try (UIApplication.shared.delegate as! AppDelegate).integrationBroker.getAnswers(contentType: contentType, titleSearch: titleSearches, limit: 50, offset: 0, completion: { result in
                switch result {
                case .success(let data):
                    guard let answers = data.items else { completion(nil); return }
                    
                    completion(answers)
                    
                    break
                default:
                    completion(nil)
                    break
                }
            })
        } catch {
            completion(nil)
        }
    }
    
    /**
     Performs requests to ICS model to get metadata for the selected node.
     
     - Parameter completion: Callback method once the query is completed.
     - Parameter nodeContext: The data retrieved from the API call.
     */
    private func getNodeData(completion: @escaping (_ nodeContext: ARNodeContext?) -> ()) {
        guard let nodeName = self.nodeName else { completion(nil); return }
        
        #if DEBUG
        os_log(.debug, "Getting node data for %@", nodeName)
        #endif
        
        (UIApplication.shared.delegate as? AppDelegate)?.integrationBroker?.getNodeData(nodeName: nodeName, completion: { (result) in
            switch result {
            case .success(let data):
                completion(data)
                break
            case .failure(let failure):
                failure.log()
                completion(nil)
                break
            }
        })
    }
    
    /**
     Gets the notes array for the node that was selected.
     
     - Parameter nodeContext: The node context object of the node.
     - Parameter completion: The completion called after the API call is performed.
     - Parameter notes: The array of notes returned by the API call.
    */
    private func getNotesForNode(_ nodeContext: ARNodeContext, completion: @escaping (_ notes: [Note]?) -> ()) {
        guard let deviceId = self.deviceId else { completion(nil); return }
        
        do {
            try (UIApplication.shared.delegate as! AppDelegate).integrationBroker.getNotes(deviceId: deviceId, nodeName: nodeContext.name, completion: { result in
                switch result {
                case .success(let data):
                    completion(data.items)
                    break
                default:
                    completion(nil)
                    break
                }
            })
        } catch {
            completion(nil)
        }
    }
    
    // MARK: - Chart Methods
    
    /**
     Retrieves the last number of entries from IoTCS to display in the chart view based on how many are defined in self.chartEntriesToShow.
     
     - Parameter chartCell: The tableviewcell that will contain the chartview, objects, and related data.
     - Parameter completion: A callback that is called once the IoTCS request is complete and the chart is updated.
    */
    private func getIoTHistory(chartCell: LineChartTableViewCell, completion: (() -> ())?) {
        guard let appId = self.applicationId else { completion?(); return }
        guard let deviceId = self.deviceId else { completion?(); return }
        guard let arNodeContext = self.arNodeContext else { completion?(); return }
        guard let sensors = arNodeContext.sensors else { completion?(); return }
        
        self.chartData = LineChartData()
        
        (UIApplication.shared.delegate as! AppDelegate).integrationBroker.getHistoricalDeviceMessages(appId, deviceId, completion: { result in
            var items: [SensorMessage]?
            
            switch result {
            case .success(let data):
                items = data.items
                break
            default:
                chartCell.chartView.noDataText = "There was an error getting data from IoTCS."
                completion?()
                return
            }
            
            guard items != nil else {
                chartCell.chartView.noDataText = "There was an error getting data from IoTCS."
                completion?()
                return
            }
            
            var newDataSets: [LineChartDataSet] = []
            
            for (index, sensor) in sensors.enumerated() {
                guard let sensorName = sensor.name else { continue }
                
                let dataSetIndex = index % LineChartTableViewCell.PredefinedDataSets.allCases.count
                let dataSetType = LineChartTableViewCell.PredefinedDataSets.allCases[dataSetIndex]
                var dataSet: LineChartDataSet!
                
                switch dataSetType {
                case .red:
                    dataSet = LineChartTableViewCell.getRedDataSet(sensorName)
                    break
                case .yellow:
                    dataSet = LineChartTableViewCell.getYellowDataSet(sensorName)
                    break
                case .blue:
                    dataSet = LineChartTableViewCell.getBlueDataSet(sensorName)
                    break
                case .green:
                    dataSet = LineChartTableViewCell.getGreenDataSet(sensorName)
                    break
                }
                
                for (itemsIndex, message) in items!.enumerated() {
                    let val: Double = message.payload?.data?[sensorName] as? Double ?? 0.0
                    
                    let i = Double(itemsIndex)
                    
                    _ = dataSet.append(ChartDataEntry(x: i, y: val))
                }
                
                newDataSets.append(dataSet)
            }
            
            DispatchQueue.main.async {
                for dataSet in newDataSets {
                    self.chartData?.addDataSet(dataSet)
                }
                
                chartCell.chartView.data = self.chartData
                chartCell.chartView.notifyDataSetChanged()
                chartCell.chartView.lastHighlighted = nil
                chartCell.chartView.resetZoom()
                chartCell.chartView.setNeedsDisplay()
                chartCell.chartView.fitScreen()
                chartCell.chartView.marker = nil
                
                chartCell.activityIndicator.stopAnimating()
            }
            
            completion?()
        }, limit: self.chartEntriesToShow)
    }
    
    /**
     Allows an external class, like the ARViewController which is getting IoT data via a timer, to push those updated into the chart view and change the data set.
     
     - Parameter message: The sensor message struct with applicable data for updating the chart.
     */
    func addSensorMessage(_ message: SensorMessage) {
        let chartIndexPath = IndexPath(row: 0, section: 1)
        guard let chartCell = self.tableView.cellForRow(at: chartIndexPath) as? LineChartTableViewCell else {
            return
        }
        
        guard let chartData = self.chartData, let arNodeContext = self.arNodeContext, let sensors = arNodeContext.sensors else {
            return
        }
        
        // get the data sets from the chart that we will need to update
        var sensorDataSets: [LineChartDataSet] = []
        for sensor in sensors {
            guard let dataSet = chartData.dataSets.first(where: { $0.label == sensor.name }) as? LineChartDataSet else { continue }
            sensorDataSets.append(dataSet)
        }
        
        let shiftXAxis: (IChartDataSet) -> () = { dataSet in
            var index = 0
            repeat {
                guard let entry = dataSet.entryForIndex(index) else {
                    index = index + 1
                    return
                }
                entry.x = entry.x - 1
                
                index = index + 1
            } while index < dataSet.entryCount
        }
        
        for dataSet in sensorDataSets {
            // remove the first value from each set
            if dataSet.count > self.chartEntriesToShow {
                _ = dataSet.remove(at: 0)
                shiftXAxis(dataSet)
            }
            
            // ensure that the dataset has a label that we can map to a sensor value
            guard let label = dataSet.label else { continue }
            
            // add the new value
            let val = message.payload?.data?[label] as? Double ?? 0.0
            let i = Double(dataSet.count)
            _ = dataSet.append(ChartDataEntry(x: i, y: val))
        }
        
        self.chartData = LineChartData(dataSets: sensorDataSets)
        
        chartCell.chartView.data = self.chartData!
        chartCell.chartView.notifyDataSetChanged()
        chartCell.chartView.resetZoom()
        chartCell.chartView.setNeedsDisplay()
    }
    
    // MARK: - Custom Handlers
    
    /**
     Handler method called when the hide/show buttons are pressed in the table header rows.
     
     - Parameter sender: The sending hide/show button.
     */
    @objc func hideSectionHandler(_ sender: UIButton) {
        let section = sender.tag
        
        if self.hiddenSections.contains(section) {
            #if DEBUG
            os_log(.debug, "Showing section %@", section.description)
            #endif
            
            guard let index = self.hiddenSections.firstIndex(of: section) else { return }
            self.hiddenSections.remove(at: index)
        } else {
            #if DEBUG
            os_log(.debug, "Hiding section %@", section.description)
            #endif
            
            var paths: [IndexPath] = []
            var rowIndex = 0
            let count = tableView.numberOfRows(inSection: section)
            
            #if DEBUG
            os_log(.debug, "Will hide %d rows.", count)
            #endif
            
            repeat {
                let path = IndexPath(item: rowIndex, section: section)
                paths.append(path)
                
                rowIndex = rowIndex + 1
            } while rowIndex < count
            
            self.hiddenSections.append(section)
        }
        
        self.tableView.reloadData()
    }
    
    /**
     Gets the TableSection object from the Node Context based on the table index.
     
     - Parameter tableSection: The section in the UITableView currently being processed.
     
     - Returns: The ARNodeContext.TableSection object that corresponds to the passed table section.
     */
    private func nodeContextSection(from tableSection: Int) -> ARNodeContext.TableSection? {
        // Ensure that the section is within range of the table section count + sections from node context.
        guard let nodeSections = self.arNodeContext?.tableSections else { return nil }
        
        let sectionCount = nodeSections.count + tableSections.allCases.count
        
        guard tableSection < sectionCount else { return nil }
        
        let index = tableSection - tableSections.allCases.count
        
        guard index > -1  else { return nil }
        
        return nodeSections[index]
    }
    
    /**
     Handler method that collects which image was tapped and passes it to the delegate for action in the app.
     
     - Parameter sender: The sending gesture recognizer.
    */
    @objc private func imageTapped(_ sender: UITapGestureRecognizer) {
        #if DEBUG
        os_log(.debug, "Image Tapped")
        #endif
        
        AppEventRecorder.shared.record(name: "Context Node Image Pressed", eventStart: Date(), eventEnd: nil, eventLength: 0.0, uiElement: String(describing: type(of: sender.self)), arAnchor: nil, arNode: self.nodeName, jsonString: nil, completion: nil)
        
        guard let imageCell = sender.view as? UICollectionViewCell else { return }
        guard let collection = imageCell.superview as? UICollectionView else { return }
        guard let index = collection.indexPath(for: imageCell) else { return }
        
        self.delegate?.imageTappedHandler(self, index: index.row, completion: nil)
    }
}
