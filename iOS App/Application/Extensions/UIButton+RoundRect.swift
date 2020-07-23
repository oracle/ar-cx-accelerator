//
// *********************************************************************************************
// Copyright © 2019. Oracle and/or its affiliates. All rights reserved.
// Licensed under the Universal Permissive License v 1.0 as shown at
// http://oss.oracle.com/licenses/upl
// *********************************************************************************************
// Accelerator Package: Augmented CX
// Date: 10/9/19 8:15 PM
// *********************************************************************************************
// File: UIButton+RoundRect.swift
// *********************************************************************************************
// 

import UIKit

extension UIButton {
    
    /// Errors produced by round rect button generation.
    enum RoundRectButtonError: Error {
        case iconConvertionError,
        fontError,
        fontAwesomeError,
        oracleSansError
    }
    
    /// Reusable method for generatign a template round rect button.
    /// - Parameter frame: The rect describing the initial frame of the button.
    private static func getRoundRectButton(frame: CGRect) -> UIButton {
        let button = UIButton(frame: frame)
        button.contentHorizontalAlignment = .center
        button.layer.cornerRadius = 5
        button.layer.masksToBounds = true
        
        return button
    }
    
    /// Generates a round rect button using Font Awesome Solid icons.
    /// - Parameter icon: The icon to use in the button.
    /// - Parameter label: The text label for the button.
    /// - Parameter backgroundColor: The background color of the button.
    /// - Parameter textColor: The color of the icon and the text. Uses white by default.
    /// - Parameter frame: The frame describing the dimentions of the button. Uses a 60x60 frame by default.
    /// - Returns: A UI button with the parameters supplied.
    /// - Throws: RoundRectButtonError based on the conditions of the error.
    static func roundRectButton(icon: FontAwesomeSolid, label: String, backgroundColor: UIColor, textColor: UIColor = UIColor.white, iconSize: CGFloat = 28, fontSize: CGFloat = 10, frame: CGRect = CGRect(x: 0, y: 0, width: 60, height: 60)) throws -> UIButton {
        guard let iconChar = icon.rawValue.toUnicodeCharacter else { throw RoundRectButtonError.iconConvertionError }
        let iconStr = String(iconChar)
        
        guard let iconFont = UIFont(name: FontAwesomeFreeFamilies.solid.rawValue, size: iconSize) else { throw RoundRectButtonError.fontAwesomeError }
        
        do {
            let button = try UIButton.buildRoundRectButton(iconFont: iconFont, iconStr: iconStr, label: label, backgroundColor: backgroundColor, textColor: textColor, fontSize: fontSize, frame: frame)
            return button
        } catch {
            throw error
        }
    }
    
    /// Generates a round rect button using Font Awesome Regular icons.
    /// - Parameter icon: The icon to use in the button.
    /// - Parameter label: The text label for the button.
    /// - Parameter backgroundColor: The background color of the button.
    /// - Parameter textColor: The color of the icon and the text. Uses white by default.
    /// - Parameter frame: The frame describing the dimentions of the button. Uses a 60x60 frame by default.
    /// - Returns: A UI button with the parameters supplied.
    /// - Throws: RoundRectButtonError based on the conditions of the error.
    static func roundRectButton(icon: FontAwesomeRegular, label: String, backgroundColor: UIColor, textColor: UIColor = UIColor.white, iconSize: CGFloat = 28, fontSize: CGFloat = 10, frame: CGRect = CGRect(x: 0, y: 0, width: 60, height: 60)) throws -> UIButton {
        guard let iconChar = icon.rawValue.toUnicodeCharacter else { throw RoundRectButtonError.iconConvertionError }
        let iconStr = String(iconChar)
        
        guard let iconFont = UIFont(name: FontAwesomeFreeFamilies.regular.rawValue, size: iconSize) else { throw RoundRectButtonError.fontAwesomeError }
        
        do {
            let button = try UIButton.buildRoundRectButton(iconFont: iconFont, iconStr: iconStr, label: label, backgroundColor: backgroundColor, textColor: textColor, fontSize: fontSize, frame: frame)
            return button
        } catch {
            throw error
        }
    }
    
    /// Generates a round rect button using Font Awesome Brands icons.
    /// - Parameter icon: The icon to use in the button.
    /// - Parameter label: The text label for the button.
    /// - Parameter backgroundColor: The background color of the button.
    /// - Parameter textColor: The color of the icon and the text. Uses white by default.
    /// - Parameter frame: The frame describing the dimentions of the button. Uses a 60x60 frame by default.
    /// - Returns: A UI button with the parameters supplied.
    /// - Throws: RoundRectButtonError based on the conditions of the error.
    static func roundRectButton(icon: FontAwesomeBrands, label: String, backgroundColor: UIColor, textColor: UIColor = UIColor.white, iconSize: CGFloat = 28, fontSize: CGFloat = 10, frame: CGRect = CGRect(x: 0, y: 0, width: 60, height: 60)) throws -> UIButton {
        guard let iconChar = icon.rawValue.toUnicodeCharacter else { throw RoundRectButtonError.iconConvertionError }
        let iconStr = String(iconChar)
        
        guard let iconFont = UIFont(name: FontAwesomeFreeFamilies.brands.rawValue, size: iconSize) else { throw RoundRectButtonError.fontAwesomeError }
        
        do {
            let button = try UIButton.buildRoundRectButton(iconFont: iconFont, iconStr: iconStr, label: label, backgroundColor: backgroundColor, textColor: textColor, fontSize: fontSize, frame: frame)
            return button
        } catch {
            throw error
        }
    }
    
    /// Generates the common properties of all round rect buttons based on FontAwesome icons.
    /// - Parameter iconFont: The font to use for the icon.
    /// - Parameter iconStr: The string value of the icon.
    /// - Parameter label: The label to display under the icon.
    /// - Parameter backgroundColor: The background color of the button.
    /// - Parameter textColor: The text color of the button.
    /// - Parameter frame: The frame dimentions for the button.
    /// - Returns: A UI button with the parameters supplied.
    /// - Throws: RoundRectButtonError based on the conditions of the error.
    private static func buildRoundRectButton(iconFont: UIFont, iconStr: String, label: String, backgroundColor: UIColor, textColor: UIColor, fontSize: CGFloat, frame: CGRect) throws -> UIButton {
        let button = UIButton.getRoundRectButton(frame: frame)
        button.backgroundColor = backgroundColor
        
        let attributedText = NSMutableAttributedString(string: String(format: "%@\n\n%@", iconStr, label))
        
        // Set the text color
        attributedText.addAttribute(.foregroundColor, value: textColor, range: NSRange(location: 0, length: attributedText.length))
        
        let tinyFont = UIFont.systemFont(ofSize: 4)
        let oracleFont = UIFont.systemFont(ofSize: fontSize)
        
        // Use FontAwesome for first character
        attributedText.addAttribute(.font, value: iconFont, range: NSRange(location: 0, length: 1))
        
        // Use tiny font for return carriages
        attributedText.addAttribute(.font, value: tinyFont, range: NSRange(location: 1, length: 2))
        
        // Use OracleSans for anything else
        attributedText.addAttribute(.font, value: oracleFont, range: NSRange(location: 3, length: attributedText.length - 3))
        
        button.setAttributedTitle(attributedText, for: .normal)
        
        // Ensure that the text wraps in the button
        button.titleLabel?.lineBreakMode = .byWordWrapping
        button.titleLabel?.textAlignment = .center
        button.titleLabel?.numberOfLines = 4
        button.titleLabel?.minimumScaleFactor = 0.01
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        
        return button
    }
}
