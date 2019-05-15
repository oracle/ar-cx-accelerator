// 
// *********************************************************************************************
// Copyright © 2019. Oracle and/or its affiliates. All rights reserved.
// Licensed under the Universal Permissive License v 1.0 as shown at
// http://oss.oracle.com/licenses/upl
// *********************************************************************************************
// Accelerator Package: Augmented CX
// Date: 10/11/18 8:44 AM
// *********************************************************************************************
// File: ApplicationButtonsViewController.swift
// *********************************************************************************************
// 

import UIKit

protocol ApplicationButtonsViewControllerDelegate: class {
    /**
     Method to alert the delegate that the reset button has been pressed.
     
     - Parameter sender: The button sending the event.
    */
    func resetButtonPressed(_ sender: ApplicationButtonsViewController)
    
    /**
     Method to alert the delegate that the help button has been pressed.
     
     - Parameter sender: The button sending the event.
     */
    func helpButtonPressed(_ sender: ApplicationButtonsViewController)
    
    /**
     Method to alert the delegate that the share button has been pressed.
     
     - Parameter sender: The button sending the event.
     */
    func shareButtonPressed(_ sender: ApplicationButtonsViewController)
}

class ApplicationButtonsViewController: UIViewController, ContextViewController {
    
    // MARK: - IBOutlets
    
    @IBOutlet weak var resetButton: UIButton!
    @IBOutlet weak var helpButton: UIButton!
    @IBOutlet weak var shareButton: UIButton!
    
    // MARK: - Properties
    
    /**
     Delegate reference.
    */
    weak var delegate: ApplicationButtonsViewControllerDelegate?
    
    /**
     The width for this view as it will be overlayed on the AR view.
    */
    let viewHeight: CGFloat = 264
    
    /**
     The height for this view as it will be overlayed on the AR view.
     */
    let viewWidth: CGFloat = 60
    
    /**
     Additional padding around this view from the outside frame.
     */
    let viewInset: CGFloat = 10
    
    // MARK: - IBActions
    
    @IBAction func resetButtonHandler(_ sender: UIButton) {
        sender.isEnabled = false
        delegate?.resetButtonPressed(self)
    }
    
    @IBAction func helpButtonHandler(_ sender: UIButton) {
        delegate?.helpButtonPressed(self)
    }
    
    @IBAction func shareButtonHandler(_ sender: UIButton) {
        delegate?.shareButtonPressed(self)
    }
    
    // MARK: - ContextViewController Methods
    
    /**
     Moves this controllers out of the visible area based on the parent view's frame.
     */
    func moveFrameOutOfView() {
        guard let parentView = self.parent?.view else { return }
        
        view.frame.size.width = viewWidth
        view.frame.size.height = viewHeight
        
        let yPosition = parentView.frame.size.height / 2 - view.frame.size.height / 2
        
        view.frame.origin.x = parentView.frame.size.width
        view.frame.origin.y = yPosition
    }
    
    /**
     Resizes the view based on the orientation of the device and the height of the frame.
     */
    func resizeForContent(_ duration: Double = 0.25, completion: (() -> ())? = nil) {
        guard let parentView = self.parent?.view else { return }
        
        UIView.animate(withDuration: duration
            , animations: {
                self.view.frame.origin.x = parentView.frame.size.width - parentView.safeAreaInsets.right - self.view.frame.size.width - self.viewInset
                self.view.frame.origin.y = parentView.frame.size.height / 2 - self.view.frame.size.height / 2
        }, completion: { (res) in
            completion?()
        })
    }
    
    /**
     Animates the removal of the view and then removes it from the superview.
     */
    func removeView(completion: (() -> ())?) {
        guard let parentView = self.parent?.view else { return }
        
        UIView.animate(withDuration: 0.25, animations: {
            self.view.frame.origin.x = parentView.frame.size.width
        }) { (res) in
            DispatchQueue.main.async {
                self.view.removeFromSuperview()
                
                self.removeFromParent()
            }
            
            completion?()
        }
    }
    
    /**
     Resets the frame size and position of the view which can change based on view layout or submenu button changes.
     */
    private func resetSizeAndPosition() {
        guard let parentView = self.parent?.view else { return }
        
        view.frame.size.width = viewWidth
        view.frame.size.height = viewHeight
        
        let xPosition = parentView.frame.size.width - parentView.safeAreaInsets.right - self.view.frame.size.width - self.viewInset
        let yPosition = parentView.frame.size.height / 2 - view.frame.size.height / 2
        
        view.frame.origin.x = xPosition
        view.frame.origin.y = yPosition
    }
}
