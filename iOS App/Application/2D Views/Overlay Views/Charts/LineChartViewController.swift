//
// *********************************************************************************************
// Copyright © 2019. Oracle and/or its affiliates. All rights reserved.
// Licensed under the Universal Permissive License v 1.0 as shown at
// http://oss.oracle.com/licenses/upl
// *********************************************************************************************
// Accelerator Package: Augmented CX
// Date: 8:21 AM 9/28/18
// *********************************************************************************************
// File: LineChartViewController.swift
// *********************************************************************************************
// 

import UIKit
import Charts
import os

class LineChartViewController: OverlayViewController, ChartViewDelegate {
    
    // MARK: - Enums
    
    /**
     Enumeration of the different data set labels that are applied in the graph.  The labels correlate to specific data sets and formatting.
    */
    enum DataSetLabel: String {
        case historicalData = "Historical Data"
        case liveData = "Live Data"
    }
    
    // MARK: - IBOutlets
    
    @IBOutlet weak var navigationBar: UINavigationBar!
    @IBOutlet weak var backButton: UIBarButtonItem!
    @IBOutlet weak var lineChartView: LineChartView!
    @IBOutlet weak var historicalDataButton: UIButton!
    @IBOutlet weak var liveDataButton: UIButton!
    @IBOutlet weak var liveDataOnLabel: UILabel!
    @IBOutlet weak var predictionActivityIndicator: UIActivityIndicatorView!
    
    // MARK: - Properties
    
    /**
     The IoT device ID for the sensor that we are pulling data for.
     */
    var deviceId: String?
    
    /**
     The sensor that we will display charting for.
     */
    var sensor: ARSensor?
    
    //TODO: Move this to a configuration item
    /**
     The number of messages that will be retrieved from IoTCS and the boundary of the x axis in the chart.
     */
    private static let deviceMessageLimit = 50
    
    /**
     Array of the historical messages retrieved from IoTCS.
     */
    private var historicalMessages: [SensorMessage]?
    
    /**
     Array of the live messages retrieved from IoTCS.
     */
    private var liveMessages: [SensorMessage]?
    
    /**
     Timer used to query for live data to IoTCS.
     */
    private var sensorTimer: Timer?
    
    /**
     Flag to indicate if a request to IoTCS is currently in process.
     */
    private var iotRequestInProcess: Bool = false
    
    /**
     Flag to indicate if a request to Prediction Service is currently in process.
     */
    private var predictionRequestInProcess: Bool = false
    
    /**
     The historical data chart dataset and its configuration.
     */
    private lazy var historicalDataSet: LineChartDataSet = {
        let dataSet = LineChartDataSet()
        dataSet.label = DataSetLabel.historicalData.rawValue
        dataSet.axisDependency = .left
        dataSet.setColor(UIColor(red: 51/255, green: 181/255, blue: 229/255, alpha: 1))
        dataSet.setCircleColor(.lightGray)
        dataSet.lineWidth = 2
        dataSet.circleRadius = 3
        dataSet.fillAlpha = 65/255
        dataSet.fillColor = UIColor(red: 51/255, green: 181/255, blue: 229/255, alpha: 1)
        dataSet.highlightColor = UIColor(red: 244/255, green: 117/255, blue: 117/255, alpha: 1)
        dataSet.drawCircleHoleEnabled = false
        dataSet.drawFilledEnabled = true
        
        return dataSet
    }()
    
    /**
     The live data chart dataset and its configuration.
     */
    private lazy var liveDataSet: LineChartDataSet = {
        let dataSet = LineChartDataSet()
        dataSet.label = DataSetLabel.liveData.rawValue
        dataSet.axisDependency = .left
        dataSet.setColor(.black)
        dataSet.setCircleColor(.blue)
        dataSet.lineWidth = 2
        dataSet.circleRadius = 3
        dataSet.fillAlpha = 65/255
        dataSet.fillColor = UIColor(red: 255/255, green: 245/255, blue: 128/255, alpha: 1)
        dataSet.highlightColor = UIColor(red: 244/255, green: 117/255, blue: 117/255, alpha: 1)
        dataSet.drawCircleHoleEnabled = false
        dataSet.drawFilledEnabled = true
        
        return dataSet
    }()
    
    // MARK: - UIViewController Methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationBar.items?[0].title = self.title
        
        // Set button opacity so we can add animations
        self.historicalDataButton.alpha = 0
        self.liveDataButton.alpha = 0
        self.liveDataOnLabel.alpha = 0
        
        // Do any additional setup after loading the view.
        lineChartView.delegate = self
        lineChartView.dragXEnabled = true
        lineChartView.xAxis.enabled = false
        
        // If the data key is not set, then we don't know which sensor to pick up from the IoT payload.  Stop action.
        guard let dataKey = self.sensor?.name else { return }
        
        // Run the get device info query after historical data to prevent the chart from flashing
        guard let deviceId = self.deviceId else { return }
        
        guard let activityVc = UIStoryboard(name: "ActivityOverlay", bundle: nil).instantiateInitialViewController() as? ActivityOverlayViewController else { return }
        self.addChild(activityVc)
        self.view.addSubview(activityVc.view)
        activityVc.view.backgroundColor = UIColor(displayP3Red: 0, green: 0, blue: 0, alpha: 0.75)
        activityVc.activityLabel.text = "Getting Device Data"
        
        ICSBroker.shared.getDeviceInfo(deviceId) { result in
            var deviceInfo: IoTDevice?
            
            switch result {
            case .success(let data):
                deviceInfo = data
                
                break
            default:
                
                break
            }
            
            DispatchQueue.main.async {
                activityVc.view.removeFromSuperview()
                activityVc.removeFromParent()
                
                self.historicalDataButton.isEnabled = true
                self.liveDataButton.isEnabled = true
                
                UIView.animate(withDuration: 0.25, animations: {
                    self.historicalDataButton.alpha = 1
                    self.liveDataButton.alpha = 1
                })
            }
            
            // Set the IoT Device Data
            guard let modelWithAttributes = deviceInfo?.deviceModels?.first(where:{ $0.attributes != nil && $0.attributes!.count > 0 }) else { return }
            guard let attributes = modelWithAttributes.attributes else { return }
            guard let sensorAttr = attributes.first(where: { $0.name == dataKey }) else { return }
            guard let rangeStr = sensorAttr.range else { return }
            let range = rangeStr.split(separator: ",")
            guard range.count == 2 else { return }
            guard let maxValue = self.sensor?.operatingLimits?.max else { return }
            let limitLine = ChartLimitLine(limit: maxValue, label: "Max")
            limitLine.lineWidth = 2
            
            DispatchQueue.main.async {
                self.lineChartView.leftAxis.addLimitLine(limitLine)
            }
            
            // Show the messages
            self.showDataSet(.historicalData)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // If the data key was not set, then the chart won't have context for which data to show.  Close the overlay if this happens.
        if self.deviceId == nil || self.sensor == nil {
            let alert = UIAlertController(title: "No Data", message: "The IoT device or sensor key is not set. If this error appears, please contact the developer to correct the issue. This overlay will close", preferredStyle: .alert)
            let action = UIAlertAction(title: "OK", style: .default) { (action) in
                DispatchQueue.main.async {
                    self.overlayDelegate?.closeRequested(sender: self.view)
                }
            }
            alert.addAction(action)
            self.present(alert, animated: true, completion: nil)
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        self.sensorTimer?.invalidate() // Ensure that the timer is invalidated before closing view.
    }
    
    // MARK: - IBActions
    
    @IBAction func backButtonHandler(_ sender: UIBarButtonItem) {
        overlayDelegate?.closeRequested(sender: self.view)
    }
    
    @IBAction func historicalDataPressHandler(_ sender: UIButton) {
        guard sender === self.historicalDataButton else { return }
        
        let index = lineChartView.data?.dataSets.firstIndex(where: { $0.label == DataSetLabel.historicalData.rawValue })
        
        if index != nil {
            hideDataSet(.historicalData)
        } else {
            showDataSet(.historicalData)
        }
    }
    
    @IBAction func liveDataPressHandler(_ sender: UIButton) {
        guard sender === self.liveDataButton else { return }
        
        DispatchQueue.main.async {
            let dataSet = self.lineChartView.data?.dataSets.first(where: { $0.label == DataSetLabel.liveData.rawValue })
            
            if self.sensorTimer != nil && self.sensorTimer!.isValid {
                self.setLiveDataTimer(false)
            }
            else if self.sensorTimer == nil && dataSet != nil {
                self.liveMessages = nil
                self.hideDataSet(.liveData)
            }
            else if self.sensorTimer == nil && dataSet == nil {
                self.showDataSet(.liveData)
            }
        }
    }
    
    // MARK: - ChartViewDelegate Methods
    
    /**
     Handler method called when a chart value is selected that will display the point details and is used to send requests to machine learning for failure predictions at that value.
     
     - Parameter chartView: The chart view where the value was selected.
     - Parameter entry: The selected entry.
     - Parameter highlight: The highlight class to apply to the selected entry.
    */
    func chartValueSelected(_ chartView: ChartViewBase, entry: ChartDataEntry, highlight: Highlight) {
        let marker = SensorBalloonMarker(color: .lightGray, font: UIFont(name: "Helvetica", size: 12)!, textColor: .black, insets: UIEdgeInsets(top: 7.0, left: 7.0, bottom: 20.0, right: 7.0))
        marker.refreshContent(entry: entry, highlight: highlight)
        chartView.marker = marker
    }
    
    // MARK: - Chart Data Methods
    
    /**
     Method that will display a data set on the chart.  The label of the dataset is used to determine if the chart already displays the dataset desired.
     
     - Parameter label: The label of the dataset to display.
     */
    private func showDataSet(_ label: DataSetLabel) {
        guard lineChartView.data?.dataSets.first(where: { $0.label == label.rawValue }) == nil else {
            #if DEBUGIOT
            os_log("data already visible")
            #endif
            return
        }
        
        switch label{
        case .historicalData:
            let dataSet = self.lineChartView?.lineData?.dataSets.first(where: { $0.label == DataSetLabel.historicalData.rawValue }) ?? self.historicalDataSet
            dataSet.clear()
            
            // Live data will be affected by re-retrieving historical data, so remove it and reset it while getting history.
            self.hideDataSet(.liveData)
            
            self.getHistoricalData { (messages) in
                guard let messages = messages else { return }
                
                for (index, message) in messages.enumerated() {
                    guard let value = message.payload?.data?[self.sensor!.name!] else { continue }
                    
                    let chartDataEntry = ChartDataEntry(x: Double(index), y: value)
                    chartDataEntry.data = message as AnyObject
                    let _ = dataSet.addEntry(chartDataEntry)
                }
                
                DispatchQueue.main.async {
                    self.liveDataButton.isEnabled = true
                }
                
                self.dataHandler(dataSet: dataSet)
            }
            
            break
        case .liveData:
            self.setLiveDataTimer()
            break
        }
    }
    
    /**
     Hides a dataset that is currently displayed on the chart.  The label of the dataset is used to determine if the dataset actually exists on the chart.
     
     - Parameter label: The label of the dataset to hide.
     */
    private func hideDataSet(_ label: DataSetLabel) {
        DispatchQueue.main.async {
            guard let data = self.lineChartView.data else { return }
            
            guard let dataSet = data.dataSets.first(where: { $0.label == label.rawValue }) else { return }
            
            data.removeDataSet(dataSet)
            
            dataSet.clear()
            
            if self.lineChartView.data?.dataSetCount == 0 {
                self.lineChartView.clear()
                self.liveDataButton.isEnabled = false
            }
            
            // Handle data set specific issues on hide
            switch label {
            case .historicalData:
                break
            case .liveData:
                self.setLiveDataTimer(false)
                break
            }
            
            self.resetChartView()
        }
    }
    
    /**
     Hides a dataset that is currently displayed on the chart.  The label of the dataset is used to determine if the dataset actually exists on the chart.
     
     - Parameter dataset: A dataset object to hide.
     */
    private func hideDataSet(_ dataSet: ChartDataSet) {
        switch dataSet.label {
        case DataSetLabel.historicalData.rawValue:
            hideDataSet(DataSetLabel.historicalData)
        case DataSetLabel.liveData.rawValue:
            hideDataSet(DataSetLabel.liveData)
        default:
            return
        }
    }
    
    // MARK: - Integration Methods
    
    /**
     Helper method to pop an error message when an error occurs.
     
     - Parameter message: The message to display in the error popup.
     - Parameter title: An override for the title "Error".
     */
    private func displayIntegrationError(_ message: String, title: String = "Error") {
        DispatchQueue.main.async {
            if self.view.subviews.count > 0 {
                self.view.subviews.last?.removeFromSuperview()
            }
            
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            let action = UIAlertAction(title: "OK", style: .default, handler: nil)
            alert.addAction(action)
            
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    /**
     Queries ICS/IoTCS for the historical data.
     
     - Parameter completion: Completion method to call after the request process is finished.
     */
    private func getHistoricalData(completion: @escaping ([SensorMessage]?) -> ()) {
        guard let deviceId = self.deviceId else { return }
        
        #if DEBUGIOT
        os_log("Getting historical data from IoTCS")
        #endif
        
        guard let activityVc = UIStoryboard(name: "ActivityOverlay", bundle: nil).instantiateInitialViewController() as? ActivityOverlayViewController else { return }
        
        DispatchQueue.main.async {
            self.addChild(activityVc)
            self.view.addSubview(activityVc.view)
            activityVc.view.backgroundColor = UIColor(displayP3Red: 0, green: 0, blue: 0, alpha: 0.75)
            activityVc.activityLabel.text = "Getting Historical Data"
        }
        
        ICSBroker.shared.getHistoricalDeviceMessages(deviceId, completion: { result in
            DispatchQueue.main.async {
                activityVc.view.removeFromSuperview()
                activityVc.removeFromParent()
            }
            
            switch result {
            case .success(let data):
                guard let items = data.items else {
                    self.displayIntegrationError("No items returned from IoTCS.")
                    completion(nil)
                    return
                }
                
                let sorted = items.sorted(by: { (first, second) -> Bool in
                    guard first.eventTime != nil && second.eventTime != nil else { return false }
                    
                    return first.eventTime! < second.eventTime!
                })
                
                completion(sorted)
                
                break
            default:
                completion(nil)
                break
            }
        }, limit: LineChartViewController.deviceMessageLimit)
    }
    
    /**
     Sets a timer and quieries ICS/IoTCS for the latest message at the time that the timer fires.
     
     - Parameter on: Flag to indicate if the timer should be turned on or off.
     */
    private func setLiveDataTimer(_ on: Bool = true) {
        guard let deviceId = self.deviceId else { return }
        
        #if DEBUGIOT
        os_log("Setting timer on state to: %@", on ? "on" : "off")
        #endif
        
        // Timer will be on main thread, so invalidate it there.
        DispatchQueue.main.async {
            if self.sensorTimer != nil {
                self.sensorTimer!.invalidate()
                self.sensorTimer = nil
                
                UIView.animate(withDuration: 0.25, animations: {
                    self.historicalDataButton.isEnabled = true
                    self.liveDataOnLabel.alpha = 0
                })
            }
        }
        
        self.iotRequestInProcess = false
        
        if on {
            self.historicalMessages = nil
            
            let defaultInterval = UserDefaults.standard.double(forKey: SensorConfigs.sensorRequestInterval.rawValue)
            let interval:Double = defaultInterval < 1 ? 5 : defaultInterval // if the default interval is not set then use 5 seconds by default
            
            DispatchQueue.main.async {
                UIView.animate(withDuration: 0.25, animations: {
                    // Disable history button while live data is running
                    self.historicalDataButton.isEnabled = false
                    
                    self.liveDataOnLabel.alpha = 1
                })
                
                self.sensorTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { (timer) in
                    if !self.iotRequestInProcess {
                        self.iotRequestInProcess = true
                        
                        ICSBroker.shared.getHistoricalDeviceMessages(deviceId, completion: { result in
                            self.iotRequestInProcess = false
                            
                            var message: SensorMessage?
                            
                            switch result {
                            case .success(let data):
                                message = data.items?[0]
                                
                                break
                            default:
                                self.displayIntegrationError("Error getting IoT Device Data.", title: "Live Data Error")
                                return
                            }
                            
                            guard message != nil else {
                                self.displayIntegrationError("Error getting IoT Device Data.", title: "Live Data Error")
                                return
                            }
                            
                            if self.liveMessages == nil {
                                self.liveMessages = []
                            }
                            
                            self.liveMessages!.append(message!)
                            
                            let liveDataSet = self.lineChartView?.lineData?.dataSets.first(where: { $0.label == DataSetLabel.liveData.rawValue }) ?? self.liveDataSet
                            let historicalDataSet = self.lineChartView?.lineData?.dataSets.first(where: { $0.label == DataSetLabel.historicalData.rawValue }) ?? self.historicalDataSet
                            
                            let scaleDownDataSet: (IChartDataSet) -> () = { dataSet in
                                if dataSet.entryCount > 0 {
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
                            }
                            
                            // Remove from historical data
                            if historicalDataSet.entryCount > 0 {
                                let _ = historicalDataSet.removeFirst()
                                
                                scaleDownDataSet(historicalDataSet)
                            }
                            
                            // If the historical data set is empty, such as removing the last value when live data is showing, then remove it from view.
                            if historicalDataSet.entryCount == 0 && self.lineChartView.data != nil && self.lineChartView.data!.contains(dataSet: historicalDataSet) {
                                self.lineChartView.data!.removeDataSet(historicalDataSet)
                            }
                            
                            // Remove entry if list is longer than the limit
                            if self.liveMessages!.count > LineChartViewController.deviceMessageLimit {
                                self.liveMessages!.removeFirst()
                                
                                repeat{
                                    let _ = liveDataSet.removeFirst()
                                } while liveDataSet.entryCount > self.liveMessages!.count
                            }
                            
                            scaleDownDataSet(liveDataSet)
                            
                            guard let value = message!.payload?.data?[self.sensor!.name!] else { return }
                            
                            let liveDataXOffset = Double(historicalDataSet.entryCount) + Double(liveDataSet.entryCount)
                            let newChartEntry = ChartDataEntry(x: (liveDataXOffset + Double(liveDataSet.entryCount)), y: value)
                            newChartEntry.data = message as AnyObject
                            let _ = liveDataSet.addEntry(newChartEntry)
                            
                            let setLiveData: () -> () = {
                                self.dataHandler(dataSet: liveDataSet)
                            }
                            
                            if historicalDataSet.entryCount > 0 {
                                self.dataHandler(dataSet: historicalDataSet, completion: {
                                    setLiveData()
                                })
                            } else {
                                setLiveData()
                            }
                        }, limit: 1)
                    }
                }
                
                self.sensorTimer!.fire()
            }
        }
    }
    
    /**
     Helper method to display a dataset on the chart and rearrage the chart view for the new data.
     
     - Parameter dataSet: The dataset to display on the chart.
     - Parameter completion: Completion method to call after the request process is finished.
     */
    private func dataHandler (dataSet: IChartDataSet, completion: (() -> ())? = nil) {
        DispatchQueue.main.async {
            if self.lineChartView.data == nil || (self.lineChartView.data != nil && self.lineChartView.data!.dataSets.count == 0) {
                let lineData = LineChartData(dataSet: dataSet)
                self.lineChartView.data = lineData
            }
            else if !self.lineChartView.data!.dataSets.contains(where: { $0.label == dataSet.label }) {
                self.lineChartView.data!.addDataSet(dataSet)
            }
            
            self.resetChartView()
            
            completion?()
        }
    }
    
    /**
     Helper method to reset the view of the chart base on the current data sets attached.
    */
    private func resetChartView() {
        DispatchQueue.main.async {
            self.lineChartView.notifyDataSetChanged()
            self.lineChartView.lastHighlighted = nil
            self.lineChartView.setVisibleXRange(minXRange: 0, maxXRange: Double(LineChartViewController.deviceMessageLimit + 5))
            self.lineChartView.resetZoom()
            self.lineChartView.setNeedsDisplay()
            self.lineChartView.fitScreen()
            self.lineChartView.marker = nil
        }
    }
}
