//
//  PasswordStore.swift
//  TresorMockup
//
//  Created by OKU Junichirou on 2020/09/27.
//  Copyright (C) 2020 OKU Junichirou. All rights reserved.
//

import Foundation

internal class PasswordStore {
    var password: String? = nil

    static let label: String = "Password"

    init(_ str: String) {
        self.password = str
    }

    func reset() {
        self.password = ""
    }

    var string: String {
        return self.password ?? ""
    }

    static func read() throws -> PasswordStore? {
        guard var data =
                try SecureStore.shared.read(label: PasswordStore.label, iCloud: false) else {
            throw CryptorError.SecItemBroken
        }
        defer { data.removeAll() }

        guard var str = String(data: data, encoding: .utf8) else {
            throw CryptorError.SecItemBroken
        }
        defer { str = "" }

        return PasswordStore(str)
    }

    static func write(_ passwordStore: PasswordStore) throws {
        guard var data = passwordStore.string.data(using: .utf8) else {
            throw CryptorError.unexpected
        }
        defer { data.removeAll() }
        try SecureStore.shared.write(label: PasswordStore.label, data, iCloud: false)
    }

    static func delete() throws {
        try SecureStore.shared.delete(label: PasswordStore.label)
    }
} // Validator
