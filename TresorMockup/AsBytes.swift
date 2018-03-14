//
//  AdBytes.swift
//  RandomData
//
//  Created by OKU Junichirou on 2017/10/07.
//  Copyright (C) 2017 OKU Junichirou. All rights reserved.
//

// Big endian
import Foundation

extension Data {
    static let Zero = Data(count:1)
    
    var isZero: Bool { return self.first(where: {$0 != 0}) == nil }
    
    mutating func zerosuppressed() -> Data {
        if let idx = self.index(where: {$0 != 0}) {
            self.removeFirst(Int(idx))
        }
        else {
            self = Data(count:1)
        }
        return self
    }
    
    func divide(by divisor: UInt8) -> (Data, UInt8) {
        guard divisor != 0 else {
            return ( Data(), UInt8(0) )
        }
        var dividend = self.reduce(
            into: (Data(capacity:self.count), 0),
            { (result, value) in
                var (quotinent, remainder) = result
                let x: Int = remainder * 0x100 + Int(value)
                quotinent.append( UInt8(x / Int(divisor)) )
                remainder = x % Int(divisor)
                result = (quotinent, remainder)
            }
        )
        return (dividend.0.zerosuppressed(), UInt8(dividend.1))
    }

    func als(radix: UInt8) -> Data {
        var dividend = self
        var data = Data(capacity:self.count)
        while !dividend.isZero {
            let (quotinent, remainder) = dividend.divide(by: radix)
            data.append(remainder)
            dividend = quotinent
        }
        return data.isZero ? Data(count:1) : Data(data.reversed())
    }
}
