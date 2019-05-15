// 
// *********************************************************************************************
// Copyright © 2019. Oracle and/or its affiliates. All rights reserved.
// Licensed under the Universal Permissive License v 1.0 as shown at
// http://oss.oracle.com/licenses/upl
// *********************************************************************************************
// Accelerator Package: Augmented CX
// Date: 12/14/18 11:57 AM
// *********************************************************************************************
// File: SKScene+Video.swift
// *********************************************************************************************
// 

import SpriteKit
import AVKit

/**
 Class used to maintain a reference to the AVPlayer object so that we can control more than play/pause from the video scene.
 */
class VideoScene: SKScene {
    
    /**
     Reference to a video player for this scene.
     */
    weak var videoPlayer: AVPlayer?
    
    /**
     Reference to a video player node for this scene.
     */
    weak var videoNode: SKVideoNode?
}
