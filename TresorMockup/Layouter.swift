//
//  Layouter.swift
//  TresorMockup
//
//  Created by OKU Junichirou on 2018/03/11.
//  Copyright (C) 2018 OKU Junichirou. All rights reserved.
//

import Foundation
fileprivate let Radix = 100

struct Layouter<T: RawRepresentable & Hashable>
where T.RawValue == Int {
    fileprivate var mapping: [T: Int] = [:]

    init(_ tuples: [T: (section: Int, row: Int)]) {
        tuples.forEach {
            self.mapping[$0.key] = $0.value.section * Radix + $0.value.row
        }
    }

    func indexPath(forKey key: T) -> IndexPath? {
        guard let val = self.mapping[key] else {
            return nil
        }
        return IndexPath(row: val % Radix, section: val / Radix)
    }

    func key(forIndexPath indexPath: IndexPath) -> T? {
        guard 0 <= indexPath.section else {
            return nil
        }
        guard 0 <= indexPath.row && indexPath.row < Radix else {
            return nil
        }
        guard let idx = self.mapping.first(
            where: { $0.value == indexPath.section * Radix + indexPath.row } )
            else {
                return nil
        }
        return idx.key
    }

    var numberOfSections: Int {
        return ( self.mapping.values.map { $0 / Radix } ).max()! + 1
    }

    func numberOfRows(inSection section: Int) -> Int {
        // get the values whose section value equals 'section'
        let vals: [Int] = self.mapping.values.flatMap {
            let lower: Int = section * Radix
            let upper: Int = lower + Radix - 1
            return ( lower <= $0 && $0 <= upper ) ? $0 : nil
        }
        // count the different values
        return Set(vals).count
    }
}
