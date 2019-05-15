// 
// *********************************************************************************************
// Copyright © 2019. Oracle and/or its affiliates. All rights reserved.
// Licensed under the Universal Permissive License v 1.0 as shown at
// http://oss.oracle.com/licenses/upl
// *********************************************************************************************
// Accelerator Package: Augmented CX
// Date: 12/20/18 10:04 AM
// *********************************************************************************************
// File: NodeImagePageViewOverlayController.swift
// *********************************************************************************************
// 

import UIKit
import os

class NodeImagePageViewOverlayController: OverlayPageViewController, UIPageViewControllerDelegate, UIPageViewControllerDataSource {
    
    // MARK: - IBOutlet
    
    @IBOutlet var panRecognizer: UIPanGestureRecognizer!
    
    // MARK: - Properties
    
    private(set) var imageViewControllers: [UIViewController]?
    
    var initialIndex = 0
    
    // MARK: - UIView Methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.dataSource = self
        self.delegate = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if initialIndex > 0 {
            guard let controllers = self.imageViewControllers else { return }
            let controller = controllers[initialIndex]
            
            self.setViewControllers([controller], direction: UIPageViewController.NavigationDirection.forward, animated: true, completion: nil)
        }
    }
    
    // MARK: - UIPageViewControllerDataSource Methods
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard let imageViewControllers = self.imageViewControllers else { return nil }
        guard let index = imageViewControllers.firstIndex(of: viewController) else { return nil }
        let prevIndex = index - 1
        guard prevIndex > -1 else { return nil }
        
        return imageViewControllers[prevIndex]
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard let imageViewControllers = self.imageViewControllers else { return nil }
        guard let index = imageViewControllers.firstIndex(of: viewController) else { return nil }
        let nextIndex = index + 1
        guard nextIndex < imageViewControllers.count else { return nil }
        
        return imageViewControllers[nextIndex]
    }
    
    func presentationCount(for pageViewController: UIPageViewController) -> Int {
        return self.imageViewControllers?.count ?? 0
    }
    
    func presentationIndex(for pageViewController: UIPageViewController) -> Int {
        return self.initialIndex
    }
    
    //MARK: - Custom Methods
    
    /**
     Sets the pages controllers and adds a close button to each so that close can be performed from any image.
     
     - Parameter controller: Array of UIViewController objects to apply the close button to and show as a page.
    */
    func setPageControllers(_ controllers: [UIViewController]) {
        // Add a close button to each view
        for controller in controllers {
            let closeButton = UIButton(type: .custom)
            closeButton.setTitle("Close", for: .normal)
            closeButton.frame.size = CGSize(width: 100, height: 14)
            closeButton.addTarget(self, action: #selector(closePageView(_:)), for: .touchUpInside)
            
            let x = (self.view.frame.size.width - closeButton.frame.size.width - self.view.safeAreaInsets.right)
            let y = self.view.safeAreaInsets.top + 35
            let origin = CGPoint(x: x, y: y)
            
            closeButton.frame.origin = origin
            
            controller.view.addSubview(closeButton)
        }
        
        self.imageViewControllers = controllers
    }
    
    /**
     Handler method for close button press.
     
     - Parameter sender: The button sending the request.
    */
    @objc private func closePageView(_ sender: UIButton) {
        #if DEBUG
        os_log("Close Button Tapped")
        #endif
        
        self.dismiss(animated: true, completion: nil)
    }
}
