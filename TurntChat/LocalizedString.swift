//
//  LocalizedString.swift
//  TurntChat
//
//  Created by Michał Ciesielski on 29.12.2015.
//  Copyright © 2015 Manifest Media ltd. All rights reserved.
//

import Foundation

//This extension enables to localize strings by adding ".localized" after the actual string (key) in the code.
extension String {
    var localized: String {
        return NSLocalizedString(self, tableName: nil, bundle: Bundle.main, value: "", comment: "")
    }
}
