//
// *********************************************************************************************
// Copyright © 2019. Oracle and/or its affiliates. All rights reserved.
// Licensed under the Universal Permissive License v 1.0 as shown at
// http://oss.oracle.com/licenses/upl
// *********************************************************************************************
// Accelerator Package: Augmented CX
// Date: 8:21 AM 9/28/18
// *********************************************************************************************
// File: ProceduresViewController.swift
// *********************************************************************************************
//

import Foundation
import UIKit
import ARKit
import os

protocol ProceduresViewControllerDelegate: class {
    /**
     Method to indicate to the delegate that the procedure view has requested to be closed.
     
     - Parameter sender: The ProceduresViewController calling the method.
    */
    func closeRequested(_ sender: ProceduresViewController)
    
    /**
     Method to indicate to the delegate that the procedure has started.
     
     - Parameter sender: The ProceduresViewController calling the method.
     - Parameter completion: Callback method called after delegate implementation is finished.
     */
    func procedureStart(_ sender: ProceduresViewController, completion: (() -> ())?)
    
    /**
     Method to indicate to the delegate that the procedure has ended.
     
     - Parameter sender: The ProceduresViewController calling the method.
     - Parameter completion: Callback method called after delegate implementation is finished.
     */
    func procedureStop(_ sender: ProceduresViewController, completion: (() -> ())?)
    
    /**
     Method to indicate to the delegate that the procedure will move to the next step.
     
     - Parameter sender: The ProceduresViewController calling the method.
     - Parameter currentIndex: The current index of the procedure.
     - Parameter completion: Callback method called after delegate implementation is finished.
     */
    func procedureNextStepWillOccur(_ sender: ProceduresViewController, currentIndex: Int, completion: (() -> ())?)
    
    /**
     Method to indicate to the delegate that the procedure did move to the next step.
     
     - Parameter sender: The ProceduresViewController calling the method.
     - Parameter newIndex: The current index of the procedure.
     - Parameter completion: Callback method called after delegate implementation is finished.
     */
    func procedureNextStepDidOccur(_ sender: ProceduresViewController, newIndex: Int, completion: (() -> ())?)
    
    /**
     Method to indicate to the delegate that an animation should play with the current procedure step.
     
     - Parameter sender: The ProceduresViewController calling the method.
     - Parameter animations: An array of animations that the delegate should play.
     - Parameter completion: Callback method called after delegate implementation is finished.
     */
    func playAnimations(_ sender: ProceduresViewController, animations: [ARAnimation], completion: (() -> ())?)
}

extension ProceduresViewControllerDelegate {
    func procedureNextStepWillOccur(_ sender: ProceduresViewController, completion: (() -> ())?) {
        // Empty implementation of this method to make it optional in the protocol
    }
    
    func procedureNextStepDidOccur(_ sender: ProceduresViewController, completion: (() -> ())?) {
        // Empty implementation of this method to make it optional in the protocol
    }
}

class ProceduresViewController: UIViewController, ContextViewController, UIGestureRecognizerDelegate {
    
    //MARK: - IBOutlets
    
    @IBOutlet weak var stepTitleLabel: UILabel!
    @IBOutlet weak var stepContentTextArea: UITextView!
    @IBOutlet weak var nextButton: UIButton!
    @IBOutlet weak var closeButton: UIButton!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet var panRecognizer: UIPanGestureRecognizer!
    
    //MARK: - Properties
    
    /**
     Delegate method for this class.
    */
    weak var delegate: ProceduresViewControllerDelegate?
    
    /**
     The default height that will be applied to the view during initial sizing calculations.
    */
    private var defaultHeight: CGFloat = 120
    
    /**
     The default height that will be applied to the view during initial sizing calculations.
     */
    private(set) var procedure: ARProcedure?
    
    /**
     The currently displayed index in the step-through process.
     */
    private var currentIndex = 0
    
    /**
     Accessor to get the current step that this procedure is on.
     */
    lazy var currentStep: ARProcedure.ProcedureStep? = {
        return self.procedure?.steps?[self.currentIndex]
    }()
    
    //MARK: - UIViewController Methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super .viewWillAppear(animated)
        
        self.moveFrameOutOfView()
        
        // If there is no procedure or steps in the procedure at this point, then why are we showing the view?  Close if that is the case.
        guard let steps = procedure?.steps, steps.count > 0 else {
            self.delegate?.closeRequested(self)
            return
        }
        
        self.updateUIForCurrentStep(completion: nil)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.resizeForContent()
        
        self.delegate?.procedureStart(self, completion: nil)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    // MARK: - UIGestureRecognizerDelegate Methods
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        // Gestures should only be enabled when the close button is active too
        return self.closeButton.isEnabled
    }
    
    @IBAction func panning(_ sender: UIPanGestureRecognizer) {
        guard let delegate = UIApplication.shared.delegate as? AppDelegate, let rootView = delegate.window?.rootViewController?.view else { return }
        
        #if DEBUG
        os_log("Velocity: %@", sender.velocity(in: rootView).debugDescription)
        #endif
        
        let x = self.view.frame.origin.x
        let newY: CGFloat = self.view.frame.origin.y + (sender.velocity(in: rootView).y * CGFloat(0.01))
        let newPoint = CGPoint(x: x, y: newY)
        
        if newY > rootView.frame.size.height - (rootView.safeAreaInsets.bottom + self.view.frame.size.height) {
            self.view.frame.origin = newPoint
        }
        
        if sender.state == .ended {
            if sender.velocity(in: rootView).y > 500 {
                self.removeView(completion: nil)
            } else {
                self.resizeForContent()
            }
        }
    }
    
    //MARK: - IBActions

    @IBAction func nextButtonHandler(_ sender: UIButton) {
        sender.isEnabled = false
        
        let currentIndex = self.currentIndex
        let newIndex = self.currentIndex + 1
        
        let nextStepProcess: ((() -> ())?) -> () = { completion in
            let proceedToNextStep: ((UIAlertAction?) -> ()) = { action in
                
                guard newIndex < self.procedure!.steps!.count else {
                    DispatchQueue.main.async {
                        self.removeView(completion: nil)
                    }
                    
                    return
                }
                
                self.currentIndex = newIndex
                
                self.updateUIForCurrentStep() {
                    completion?()
                }
            }
            
            let displayConfirmation: (String, ((UIAlertAction) -> ())?) -> () = { (message, actionHandler) in
                DispatchQueue.main.async {
                    let alert = UIAlertController(title: "Confirm Action", message: message, preferredStyle: .alert)
                    let success = UIAlertAction(title: "Yes", style: .default, handler: actionHandler)
                    let cancel = UIAlertAction(title: "No", style: .default, handler: { action in
                        DispatchQueue.main.async {
                            self.nextButton.isEnabled = true
                        }
                    })
                    alert.addAction(success)
                    alert.addAction(cancel)
                    
                    if let image = self.imageView.image {
                        alert.addImageAction(image)
                    }
                    
                    self.parent?.present(alert, animated: true, completion: nil)
                }
            }
            
            guard let currentStep = self.procedure?.steps?[self.currentIndex] else { return }
            
            if let confirmationMessage = currentStep.confirmationMessage {
                displayConfirmation(confirmationMessage, proceedToNextStep)
            } else {
                proceedToNextStep(nil)
            }
        }
        
        if self.delegate != nil {
            self.delegate?.procedureNextStepWillOccur(self, currentIndex: currentIndex, completion: {
                // remove any origin from the current step since we are now going to alter those values anyway.
                if var step = self.procedure?.steps?[currentIndex] {
                    step.nodeOriginalPositions = nil
                }
                
                nextStepProcess() {
                    self.delegate?.procedureNextStepDidOccur(self, newIndex: newIndex, completion: nil)
                }
            })
        } else {
            nextStepProcess(nil)
        }
    }
    
    @IBAction func closeButton(_ sender: UIButton) {
        sender.isEnabled = false
        
        self.removeView(completion: nil)
    }
    
    //MARK: - View Manipulation Methods
    
    /**
     Moves the frame to the bottom of the screen to the pixel just below the last displayed pixel row.
     */
    internal func moveFrameOutOfView(){
        guard let parentView = self.parent?.view else { return }
        
        let frame = view.frame
        let xPosition = parentView.frame.size.width / 2 - frame.size.width / 2
        view.frame.size.height = defaultHeight
        view.frame.origin.x = xPosition
        view.frame.origin.y = frame.size.height + parentView.frame.size.height
    }
    
    /**
     Resizes the display area based on the width of the screen.
     
     - Parameter duration: The time in seconds that the animation should play.
     - Parameter completion: Callback method called after the animation has completed.
     */
    func resizeForContent(_ duration: Double = 0.25, completion: (() -> ())? = nil) {
        guard let parentView = self.parent?.view else { return }
        
        let viewWidth = self.view.frame.size.width < parentView.frame.size.width * 0.6 ? self.view.frame.size.width : parentView.frame.size.width * 0.6
        
        self.view.frame.size = CGSize(width: viewWidth, height: self.defaultHeight)
        
        UIView.animate(withDuration: duration
            , animations: {
                //Calculate new yposition from frame size change
                let xPosition =  parentView.frame.size.width / 2 - self.view.frame.size.width / 2
                
                self.view.frame.origin.x = xPosition
                self.view.frame.origin.y = parentView.frame.size.height - self.view.frame.size.height - parentView.safeAreaInsets.bottom
        }, completion: { (res) in
            completion?()
        })
    }
    
    /**
     Animates the view off screen and then removes from view.
     
     - Parameter completion: Callback method called after the animation has completed.
     */
    func removeView(completion: (() -> ())?) {
        UIView.animate(withDuration: 0.25, animations: {
            let parentHeight = self.parent?.view.frame.size.height ?? 0
            self.view.frame.origin.y = self.view.frame.size.height + parentHeight
        }) { (res) in
            self.delegate?.procedureStop(self, completion: {
                self.delegate?.closeRequested(self)
                
                DispatchQueue.main.async {
                    self.view.removeFromSuperview()
                    self.removeFromParent()
                }
                
                completion?()
            })
        }
    }
    
    /**
     Updates the UI elements of the procedure view based on the content for the current procedure step.
     
     - Parameter completion: Callback method called after the animation has completed.
     */
    private func updateUIForCurrentStep(completion: (() -> ())?) {
        DispatchQueue.main.async {
            guard let steps = self.procedure?.steps, self.stepTitleLabel != nil, self.stepContentTextArea != nil else {
                completion?()
                return
            }
            
            let step = steps[self.currentIndex]
            
            self.stepTitleLabel.text = step.title
            self.stepContentTextArea.text = step.text
            self.stepContentTextArea.setContentOffset(.zero, animated: true)
            self.imageView.image = step.image?.getImage()
            
            if steps[self.currentIndex].animations != nil {
                self.nextButton.isEnabled = false
                self.closeButton.isEnabled = false
                
                self.delegate?.playAnimations(self, animations: steps[self.currentIndex].animations!) {
                    completion?()
                    
                    DispatchQueue.main.async {
                        self.nextButton.isEnabled = true
                        self.closeButton.isEnabled = true
                    }
                }
            }
        }
    }
    
    //MARK: - Procedure Management Methods
    
    /**
     Prepares the controller and view to start a procedure.
     
     - Parameter procedure: The procedure to set.
    */
    func setProcedure(_ procedure: ARProcedure) {
        self.procedure = procedure
        self.currentIndex = 0
        
        self.updateUIForCurrentStep(completion: nil)
    }
    
    /**
     Sets the original positions dictionary for the current step.
     
     - Parameter dict: Dictionary that defines the position of 3D nodes for the current procedure step.
    */
    func setNodePositionsForCurrentStep(_ dict:[String : SCNVector3]) {
        self.procedure?.steps?[self.currentIndex].nodeOriginalPositions = dict
    }
}
