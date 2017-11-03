//
//  UIColorExtension.swift
//  ruckus
//
//  Created by Gareth on 24/02/2017.
//  Copyright © 2017 Gareth. All rights reserved.
//

import Foundation
import UIKit


extension UIColor {
    // Ability to use hex init method
    convenience init(r: Int, g: Int, b: Int) {
        assert(r >= 0 && r <= 255, "Invalid red component")
        assert(g >= 0 && g <= 255, "Invalid green component")
        assert(b >= 0 && b <= 255, "Invalid blue component")
    
        self.init(red: CGFloat(r) / 255.0, green: CGFloat(g) / 255.0, blue: CGFloat(b) / 255.0, alpha: 1.0)
    }

    convenience init(netHex:Int) {
        self.init(r:(netHex >> 16) & 0xff, g:(netHex >> 8) & 0xff, b:netHex & 0xff)
    }
    
    // System colors
    static var textWhite: UIColor {
        return UIColor(netHex: 0xD8D8D8)
    }
    static var backgroundGrey: UIColor {
        return UIColor(netHex: 0x333333)
    }
    static var lightWhite: UIColor {
        return UIColor(netHex: 0xaaaaaa)
    }
    
    // shades of black darkest(one) -> lightest(two ...)
    static var blackSeven: UIColor {
        return UIColor(netHex: 0x444444)
    }
    static var blackSix: UIColor {
        return UIColor(netHex: 0x3C3C3D)
    }
    static var blackFive: UIColor {
        return UIColor(netHex: 0x232323)
    }
    static var blackFour: UIColor {
        return UIColor(netHex: 0x1C1C1D)
    }
    static var blackThree: UIColor {
        return UIColor(netHex: 0x171717)
    }
    static var blackTwo: UIColor {
        return UIColor(netHex: 0x161616)
    }
    static var blackOne: UIColor {
        return UIColor(netHex: 0x0C0C0C)
    }
    
    //// Blues
    static var lightestBlue: UIColor {
        return UIColor(netHex: 0x5ABBC0)
    }
    static var lightBlue: UIColor {
        return UIColor(netHex: 0x33A3A8)
    }
    static var standardBlue: UIColor {
        return UIColor(netHex: 0x169399)
    }
    static var darkBlue: UIColor {
        return UIColor(netHex: 0x037C82)
    }
    static var darkestBlue: UIColor {
        return UIColor(netHex: 0x016266)
    }
    static var nearBlackBlue: UIColor {
        return UIColor(netHex: 0x033A3D)
    }
    
    // Reds
    static var lightestRed: UIColor {
        return UIColor(netHex: 0xF4718B)
    }
    static var lightRed: UIColor {
        return UIColor(netHex: 0xF04869)
    }
    static var standardRed: UIColor {
        return UIColor(netHex: 0xEC2147)
    }
    static var darkRed: UIColor {
        return UIColor(netHex: 0xC9032A)
    }
    static var darkestRed: UIColor {
        return UIColor(netHex: 0x9E001F)
    }
    static var nearBlackRed: UIColor {
        return UIColor(netHex: 0x5D1622)
    }
    
    // Oranges
    static var lightestOrange: UIColor {
        return UIColor(netHex: 0xFFB776)
    }
    static var lightOrange: UIColor {
        return UIColor(netHex: 0xFF9F4D)
    }
    static var standardOrange: UIColor {
        return UIColor(netHex: 0xFD8823)
    }
    static var darkOrange: UIColor {
        return UIColor(netHex: 0xD86503)
    }
    static var darkestOrange: UIColor {
        return UIColor(netHex: 0xA94E00)
    }
    
    // Greens
    static var lightestGreen: UIColor {
        return UIColor(netHex: 0x95EA6C)
    }
    static var lightGreen: UIColor {
        return UIColor(netHex: 0x77E144)
    }
    static var standardGreen: UIColor {
        return UIColor(netHex: 0x5CDB1F)
    }
    static var darkGreen: UIColor {
        return UIColor(netHex: 0x3EBA03)
    }
    static var darkestGreen: UIColor {
        return UIColor(netHex: 0x2F9200)
    }
    
}
