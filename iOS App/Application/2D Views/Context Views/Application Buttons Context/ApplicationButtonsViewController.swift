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
    
    // MARK: - Properties
    
    /**
     Delegate reference.
    */
    weak var delegate: ApplicationButtonsViewControllerDelegate?
    
    /**
     The width for this view as it will be overlayed on the AR view.
    */
    let viewHeight: CGFloat = 198
    
    /**
     The height for this view as it will be overlayed on the AR view.
     */
    let viewWidth: CGFloat = 60
    
    /**
     Additional padding around this view from the outside frame.
     */
    let viewInset: CGFloat = 10
    
    // MARK: - UIViewController Methods
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        do {
            let resetButton: UIButton = try UIButton.roundRectButton(icon: FontAwesomeSolid.redo, label: "Reset", backgroundColor: #colorLiteral(red: 0.8196256757, green: 0.2078545988, blue: 0.05893449485, alpha: 1))
            let helpButton: UIButton = try UIButton.roundRectButton(icon: FontAwesomeSolid.question, label: "Help", backgroundColor: #colorLiteral(red: 0.4587318897, green: 0.6117965579, blue: 0.4234741926, alpha: 1))
            let shareButton: UIButton = try UIButton.roundRectButton(icon: FontAwesomeSolid.share, label: "Share", backgroundColor: #colorLiteral(red: 0.3372283578, green: 0.3137445748, blue: 0.2940791547, alpha: 1))
            
            resetButton.addTarget(self, action: #selector(self.resetButtonHandler(_:)), for: .touchUpInside)
            resetButton.restorationIdentifier = "ResetButton"
            resetButton.layer.masksToBounds = false
            resetButton.layer.shadowColor = UIColor.black.cgColor
            resetButton.layer.shadowOpacity = 0.3
            resetButton.layer.shadowOffset = CGSize(width: 3, height: 3)
            resetButton.layer.shadowRadius = 1
            resetButton.translatesAutoresizingMaskIntoConstraints = false
            
            self.view.addSubview(resetButton)
            
            NSLayoutConstraint.activate([
                resetButton.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
                resetButton.widthAnchor.constraint(equalToConstant: 60),
                resetButton.heightAnchor.constraint(equalToConstant: 60)
            ])
            
            helpButton.addTarget(self, action: #selector(self.helpButtonHandler(_:)), for: .touchUpInside)
            helpButton.restorationIdentifier = "HelpButton"
            helpButton.layer.masksToBounds = false
            helpButton.layer.shadowColor = UIColor.black.cgColor
            helpButton.layer.shadowOpacity = 0.3
            helpButton.layer.shadowOffset = CGSize(width: 3, height: 3)
            helpButton.layer.shadowRadius = 1
            helpButton.frame = CGRect(x: 0, y: 68, width: 60, height: 60)
            helpButton.translatesAutoresizingMaskIntoConstraints = false
            
            self.view.addSubview(helpButton)
            
            NSLayoutConstraint.activate([
                helpButton.topAnchor.constraint(equalTo: resetButton.bottomAnchor, constant: 8),
                helpButton.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
                helpButton.widthAnchor.constraint(equalToConstant: 60),
                helpButton.heightAnchor.constraint(equalToConstant: 60)
            ])
            
            shareButton.addTarget(self, action: #selector(self.shareButtonHandler(_:)), for: .touchUpInside)
            shareButton.restorationIdentifier = "ShareButton"
            shareButton.layer.masksToBounds = false
            shareButton.layer.shadowColor = UIColor.black.cgColor
            shareButton.layer.shadowOpacity = 0.3
            shareButton.layer.shadowOffset = CGSize(width: 3, height: 3)
            shareButton.layer.shadowRadius = 1
            shareButton.frame = CGRect(x: 0, y: 204, width: 60, height: 60)
            shareButton.translatesAutoresizingMaskIntoConstraints = false
            
            self.view.addSubview(shareButton)
            
            NSLayoutConstraint.activate([
                shareButton.topAnchor.constraint(equalTo: shareButton.topAnchor, constant: 8),
                shareButton.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
                shareButton.widthAnchor.constraint(equalToConstant: 60),
                shareButton.heightAnchor.constraint(equalToConstant: 60)
            ])
        } catch {
            error.log()
        }
    }
    
    // MARK: - IBActions
    
    @IBAction func resetButtonHandler(_ sender: UIButton) {
        sender.isEnabled = false
        sender.logClick()
        delegate?.resetButtonPressed(self)
    }
    
    @IBAction func helpButtonHandler(_ sender: UIButton) {
        sender.logClick()
        delegate?.helpButtonPressed(self)
    }
    
    @IBAction func shareButtonHandler(_ sender: UIButton) {
        sender.logClick()
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
