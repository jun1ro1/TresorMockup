//
//  SecureStore.swift
//  TresorMockup
//
//  Created by OKU Junichirou on 2020/08/23.
//  Copyright © 2020 OKU Junichirou. All rights reserved.
//

import Foundation
import SwiftyBeaver

// MARK: -
internal class SecureStore {
    private var mutex: NSLock = NSLock()
    private var query: [String: Any]
    private var dateCreated:  Date?
    private var dateModified: Date?

    private init() {
        self.query = [:]
        self.dateCreated  = nil
        self.dateModified = nil
    }

    static var shared = SecureStore()

    private func prepare(label: String) {
        self.query = [
            kSecClass              as String: kSecClassGenericPassword,
            kSecAttrSynchronizable as String: kCFBooleanTrue!,
            kSecAttrAccount        as String: label,
        ]
        let prefix = Bundle.main.bundleIdentifier ?? ""
        #if DEBUG
            self.query[kSecAttrService as String] = prefix + "." + "PasswortTresorTEST"
        #else
            self.query[kSecAttrService as String] = prefix + "." + "PasswortTresor"
        #endif
    }

    func read(label: String) throws -> Data? {
        guard self.mutex.lock(before: Date(timeIntervalSinceNow: 30)) else {
            SwiftyBeaver.error("label = \(label) mutex lock time out")
            throw CryptorError.timeOut
        }
        defer { self.mutex.unlock() }

        self.prepare(label: label)
        self.query[ kSecReturnData       as String] = kCFBooleanTrue
        self.query[ kSecMatchLimit       as String] = kSecMatchLimitOne
        self.query[ kSecReturnAttributes as String] = kCFBooleanTrue
        self.query[ kSecReturnData       as String] = kCFBooleanTrue

        var result: AnyObject?
        let status = withUnsafeMutablePointer(to: &result) {
            SecItemCopyMatching(self.query as CFDictionary, UnsafeMutablePointer($0))
        }
        #if DEBUG
        SwiftyBeaver.debug("label = \(label) SecItemCopyMatching = \(status)")
        #endif

        guard status != errSecItemNotFound else {
            SwiftyBeaver.error("label = \(label) SecItemCopyMatching = \(status)")
            return nil
        }
        guard status == noErr else {
            SwiftyBeaver.error("label = \(label) SecItemCopyMatching = \(status)")
            throw CryptorError.SecItemError(error: status)
        }
        guard let items = result as? Dictionary<String, AnyObject> else {
             SwiftyBeaver.error(
                "label = \(label) SecItemCopyMatching = \(status) items = ",
                context:result)
            throw CryptorError.SecItemBroken
        }
        guard let data = items[kSecValueData as String] as? Data else {
            SwiftyBeaver.error(
                "label = \(label) SecItemCopyMatching = \(status) data = ",
                context: items)
            throw CryptorError.SecItemBroken
        }

        #if DEBUG
        SwiftyBeaver.debug("label = \(label) kSecValueData = \(data as NSData)")
        #endif

        self.dateCreated  = items[kSecAttrCreationDate     as String] as? Date
        self.dateModified = items[kSecAttrModificationDate as String] as? Date

        return data
    }

    func write(label: String, _ data: Data) throws {
        guard self.mutex.lock(before: Date(timeIntervalSinceNow: 30)) else {
            SwiftyBeaver.error("label = \(label) mutex lock time out")
            throw CryptorError.timeOut
        }
        self.prepare(label: label)
        self.query[kSecValueData  as String] = data
        let status = SecItemAdd(self.query as CFDictionary, nil)
        self.mutex.unlock()

        #if DEBUG
        SwiftyBeaver.debug("label = \(label) SecItemAdd = \(status)")
        #endif

        guard status == noErr else {
            SwiftyBeaver.error("label = \(label) SecItemAdd = \(status)")
            throw CryptorError.SecItemError(error: status)
        }
    }

    func update(label: String, _ data: Data) throws {
        guard self.mutex.lock(before: Date(timeIntervalSinceNow: 30)) else {
            SwiftyBeaver.error("label = \(label) mutex lock time out")
            throw CryptorError.timeOut
        }
        self.prepare(label: label)
        let attr: [String: AnyObject] = [kSecValueData as String: data as AnyObject]
        let status = SecItemUpdate(self.query as CFDictionary, attr as CFDictionary)
        self.mutex.unlock()

        #if DEBUG
        SwiftyBeaver.debug("label = \(label) SecItemUpdate = \(status)")
        #endif

        guard status == noErr else {
            SwiftyBeaver.error("label = \(label) SecItemUpdate = \(status)")
            throw CryptorError.SecItemError(error: status)
        }
    }

    func delete(label: String) throws {
        guard self.mutex.lock(before: Date(timeIntervalSinceNow: 30)) else {
            SwiftyBeaver.error("label = \(label) mutex lock time out")
            throw CryptorError.timeOut
        }
        self.prepare(label: label)
        let status = SecItemDelete(self.query as NSDictionary)
        self.mutex.unlock()

        #if DEBUG
        SwiftyBeaver.debug("label = \(label) SecItemDelete = \(status)")
        #endif

        guard status == noErr || status == errSecItemNotFound else {
            SwiftyBeaver.error("label = \(label) SecItemDelete = \(status)")
            throw CryptorError.SecItemError(error: status)
        }
    }

    var created : Date? {
        self.mutex.lock()
        defer { self.mutex.unlock() }
        return self.dateCreated
    }

    var modified : Date? {
        self.mutex.lock()
        defer { self.mutex.unlock() }
        return self.dateModified
    }
}
