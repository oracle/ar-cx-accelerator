// 
// *********************************************************************************************
// Copyright © 2019. Oracle and/or its affiliates. All rights reserved.
// Licensed under the Universal Permissive License v 1.0 as shown at
// http://oss.oracle.com/licenses/upl
// *********************************************************************************************
// Accelerator Package: Augmented CX
// Date: 11/13/18 7:35 PM
// *********************************************************************************************
// File: LineChartTableViewCell.swift
// *********************************************************************************************
// 

import UIKit
import Charts

class LineChartTableViewCell: UITableViewCell {
    
    // MARK: - IBOUtlets
    
    @IBOutlet weak var chartView: LineChartView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    // MARK: - Enums
    
    enum PredefinedDataSets: CaseIterable {
        case red, blue, green, yellow
    }
    
    // MARK: - Initializer
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        if #available(iOS 13.0, *) {
            self.activityIndicator.style = .medium
        } else {
            self.activityIndicator.style = traitCollection.userInterfaceStyle == .light ? .gray : .white
        }
    }
    
    // MARK: - Data Set Methods
    
    /**
     A red data chart dataset and its configuration.
     
     - Parameter label: The label to set on the chart.
     
     - Returns: A LineChartDataSet object the the configured parameters.
     */
    static func getRedDataSet(_ label: String) -> LineChartDataSet {
        let dataSet = LineChartDataSet()
        dataSet.label = label
        dataSet.axisDependency = .left
        dataSet.setColor(.red)
        dataSet.setCircleColor(.red)
        dataSet.lineWidth = 2
        dataSet.circleRadius = 3
        dataSet.fillAlpha = 65/255
        dataSet.fillColor = UIColor(red: 51/255, green: 181/255, blue: 229/255, alpha: 1)
        dataSet.highlightColor = UIColor(red: 244/255, green: 117/255, blue: 117/255, alpha: 1)
        dataSet.drawCircleHoleEnabled = false
        dataSet.drawFilledEnabled = false
        dataSet.valueTextColor = .white
        
        return dataSet
    }
    
    /**
     A blue data chart dataset and its configuration.
     
     - Parameter label: The label to set on the chart.
     
     - Returns: A LineChartDataSet object the the configured parameters.
     */
    static func getBlueDataSet(_ label: String) -> LineChartDataSet {
        let dataSet = LineChartDataSet()
        dataSet.label = label
        dataSet.axisDependency = .left
        dataSet.setColor(.blue)
        dataSet.setCircleColor(.blue)
        dataSet.lineWidth = 2
        dataSet.circleRadius = 3
        dataSet.fillAlpha = 65/255
        dataSet.fillColor = UIColor(red: 255/255, green: 0, blue: 0, alpha: 1)
        dataSet.highlightColor = UIColor(red: 244/255, green: 117/255, blue: 117/255, alpha: 1)
        dataSet.drawCircleHoleEnabled = false
        dataSet.drawFilledEnabled = false
        dataSet.valueTextColor = .white
        
        return dataSet
    }
    
    /**
     A green data chart dataset and its configuration.
     
     - Parameter label: The label to set on the chart.
     
     - Returns: A LineChartDataSet object the the configured parameters.
     */
    static func getGreenDataSet(_ label: String) -> LineChartDataSet {
        let dataSet = LineChartDataSet()
        dataSet.label = label
        dataSet.axisDependency = .left
        dataSet.setColor(.green)
        dataSet.setCircleColor(.green)
        dataSet.lineWidth = 2
        dataSet.circleRadius = 3
        dataSet.fillAlpha = 65/255
        dataSet.fillColor = UIColor(red: 255/255, green: 245/255, blue: 128/255, alpha: 1)
        dataSet.highlightColor = UIColor(red: 244/255, green: 117/255, blue: 117/255, alpha: 1)
        dataSet.drawCircleHoleEnabled = false
        dataSet.drawFilledEnabled = false
        dataSet.valueTextColor = .white
        
        return dataSet
    }
    
    /**
     A yellow data chart dataset and its configuration.
     
     - Parameter label: The label to set on the chart.
     
     - Returns: A LineChartDataSet object the the configured parameters.
     */
    static func getYellowDataSet(_ label: String) -> LineChartDataSet {
        let dataSet = LineChartDataSet()
        dataSet.label = label
        dataSet.axisDependency = .left
        dataSet.setColor(.yellow)
        dataSet.setCircleColor(.yellow)
        dataSet.lineWidth = 2
        dataSet.circleRadius = 3
        dataSet.fillAlpha = 65/255
        dataSet.fillColor = UIColor(red: 255/255, green: 245/255, blue: 128/255, alpha: 1)
        dataSet.highlightColor = UIColor(red: 244/255, green: 117/255, blue: 117/255, alpha: 1)
        dataSet.drawCircleHoleEnabled = false
        dataSet.drawFilledEnabled = false
        dataSet.valueTextColor = .white
        
        return dataSet
    }
}
