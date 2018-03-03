//
//  Extensions.swift
//  TresorMockup
//
//  Created by OKU Junichirou on 2018/03/03.
//  Copyright (C) 2018 OKU Junichirou. All rights reserved.
//


import Foundation
extension String {
    public var localized: String {
        return NSLocalizedString(self, comment: self)
    }
}


