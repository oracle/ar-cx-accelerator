//
// *********************************************************************************************
// Copyright © 2019. Oracle and/or its affiliates. All rights reserved.
// Licensed under the Universal Permissive License v 1.0 as shown at
// http://oss.oracle.com/licenses/upl
// *********************************************************************************************
// Accelerator Package: Augmented CX
// Date: 3/7/19 12:47 PM
// *********************************************************************************************
// File: NotesDetailsNavigationViewController.swift
// *********************************************************************************************
// 

import UIKit

class NotesDetailsNavigationViewController: UINavigationController, UINavigationControllerDelegate {
    
    // MARK: - UINavigationController Methods
    
    override func viewDidLoad() {
        self.delegate = self
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch segue.identifier {
        case "CreateNoteSegue":
            guard let svc = sender as? NotesSplitViewController else { return }
            guard let nodeName = svc.nodeName else { return }
            guard let controller = segue.destination as? CreateNoteViewController else { return }
            
            controller.delegate = sender as? CreateNoteViewControllerDelegate ?? nil
            controller.nodeName = nodeName
            
            break
        default:
            return
        }
    }
    
    // MARK: - UINavigationControllerDelegate Methods
    
    func navigationController(_ navigationController: UINavigationController, animationControllerFor operation: UINavigationController.Operation, from fromVC: UIViewController, to toVC: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        if let vc = toVC as? NoteViewController {
            vc.hideNote()
            
            self.navigationController?.popToRootViewController(animated: true)
        }
        
        return nil
    }
}
