//
// *********************************************************************************************
// Copyright © 2019. Oracle and/or its affiliates. All rights reserved.
// Licensed under the Universal Permissive License v 1.0 as shown at
// http://oss.oracle.com/licenses/upl
// *********************************************************************************************
// Accelerator Package: Augmented CX
// Date: 10/14/19 9:18 AM
// *********************************************************************************************
// File: LoadingTableViewCell.swift
// *********************************************************************************************
// 

import UIKit

class LoadingTableViewCell: UITableViewCell {
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var loadingLabel: UILabel!
    
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
}
