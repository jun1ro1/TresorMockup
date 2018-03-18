//
//  AppKey.swift
//  TresorMockup
//
//  Created by OKU Junichirou on 2018/03/18.
//  Copyright (C) 2018 OKU Junichirou. All rights reserved.
//

import Foundation

enum AppKeyType: Int  {
    case title = 0
    case url
    case userid
    case password
    case selectAt
    case generator
    case memo
    case typeEnd

    var description: String {
        var s: String = "**UNKNOWN**AppKeyType"
        switch self {
        case .title:      s = "Title"
        case .url:        s = "URL"
        case .userid:     s = "User ID"
        case .password:   s = "Password"
        case .selectAt:   s = "Select at"
        case .generator:  s = "Generator"
        case .memo:       s = "Memo"
        case .typeEnd:    s = "TypeEnd"
        }
        return s
    }

    // MARK: class functions
    /// - parameter:
    /// - retunrs: the number of AppKeyType elements
    static var count: Int { return AppKeyType.typeEnd.rawValue }
    static var iterator: AnyIterator<AppKeyType> {
        var value: Int = -1
        return AnyIterator {
            value = value + 1
            guard value < AppKeyType.typeEnd.rawValue else {
                return nil
            }
            return AppKeyType(rawValue: value)!
        }
    }
}
