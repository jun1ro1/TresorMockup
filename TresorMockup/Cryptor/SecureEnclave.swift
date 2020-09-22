
//
//  SecureStore.swift
//  TresorMockup
//
//  Created by OKU Junichirou on 2020/08/23.
//  Copyright (C) 2020 OKU Junichirou. All rights reserved.
//

#warning("not implemented")

import Foundation
import SwiftyBeaver

// MARK: -

// https://medium.com/@alx.gridnev/ios-keychain-using-secure-enclave-stored-keys-8f7c81227f4
// https://medium.com/flawless-app-stories/ios-security-tutorial-part-2-c481036170ca

internal class SecureEnclave {
    private var mutex: NSLock = NSLock()
    private var query: [String: Any]
    private var dateCreated:  Date?
    private var dateModified: Date?

    private init() {
        self.query = [:]
        self.dateCreated  = nil
        self.dateModified = nil
    }

    static var shared = SecureEnclave()

    private func prepare(label: String) {
        var error: Unmanaged<CFError>? = nil
        let accessControl =
            SecAccessControlCreateWithFlags(
                kCFAllocatorDefault,
                kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                [.privateKeyUsage, .biometryAny],
                &error)
        if error != nil {
            SwiftyBeaver.error(
                "SecAccessControlCreateWithFlags error = \(String(describing: error))")
        }
                
        self.query = [
            kSecClass              as String: kSecClassKey,
            kSecAttrApplicationTag as String: "com.me.jun1ro1" as CFString,
            kSecAttrKeyType        as String: kSecAttrKeyTypeEC,
            kSecAttrAccessControl  as String: accessControl as Any,
        ]
        #if DEBUG
            self.query[kSecAttrService as String] = "PasswortTresorTEST"
        #else
            self.query[kSecAttrService as String] = "PasswortTresor"
        #endif
    }

    func read(label: String) throws -> Data? {
        guard self.mutex.lock(before: Date(timeIntervalSinceNow: 30)) else {
            throw CryptorError.timeOut
        }
        defer { self.mutex.unlock() }

        self.prepare(label: label)
        self.query[ kSecReturnData        as String] = kCFBooleanTrue
        self.query[ kSecMatchLimit        as String] = kSecMatchLimitOne
        self.query[ kSecReturnAttributes  as String] = kCFBooleanTrue
        self.query[ kSecReturnData        as String] = kCFBooleanTrue
        self.query[kSecUseOperationPrompt as String] =
            "Please, pass authorisation to enter this area" as CFString

        var result: AnyObject?
        let status = withUnsafeMutablePointer(to: &result) {
            SecItemCopyMatching(self.query as CFDictionary, UnsafeMutablePointer($0))
        }
        #if DEBUG
        SwiftyBeaver.debug("SecItemCopyMatching = \(status)")
        #endif

        guard status != errSecItemNotFound else {
            SwiftyBeaver.debug("SecItemCopyMatching = \(status)")
            return nil
        }
        guard status == noErr else {
            SwiftyBeaver.error("SecItemCopyMatching = \(status)")
            throw CryptorError.SecItemError(error: status)
        }
        guard let items = result as? Dictionary<String, AnyObject> else {
            SwiftyBeaver.error("SecItemCopyMatching = \(String(describing: result))")
            throw CryptorError.SecItemBroken
        }
        guard let data = items[kSecValueData as String] as? Data else {
            SwiftyBeaver.error("SecItemCopyMatching = \(String(describing: items))")
            throw CryptorError.SecItemBroken
        }
        #if DEBUG
        SwiftyBeaver.debug("kSecValueData = \(data)")
        #endif

        self.dateCreated  = items[kSecAttrCreationDate     as String] as? Date
        self.dateModified = items[kSecAttrModificationDate as String] as? Date

        return data
    }

    func write(label: String, _ data: Data) throws {
        guard self.mutex.lock(before: Date(timeIntervalSinceNow: 30)) else {
            throw CryptorError.timeOut
        }
        self.prepare(label: label)
        self.query[kSecValueData  as String] = data
        let status = SecItemAdd(self.query as CFDictionary, nil)
        self.mutex.unlock()
        #if DEBUG
        SwiftyBeaver.debug("SecItemAdd = \(status)")
        #endif

        guard status == noErr else {
            SwiftyBeaver.error("SecItemAdd = \(status)")
            throw CryptorError.SecItemError(error: status)
        }
    }

    func update(label: String, _ data: Data) throws {
        guard self.mutex.lock(before: Date(timeIntervalSinceNow: 30)) else {
            throw CryptorError.timeOut
        }
        self.prepare(label: label)
        let attr: [String: AnyObject] = [kSecValueData as String: data as AnyObject]
        let status = SecItemUpdate(self.query as CFDictionary, attr as CFDictionary)
        self.mutex.unlock()

        #if DEBUG
            print("thread=\(Thread.current)", String(reflecting: type(of: self)),
                  "\(#function) SecItemUpdate = \(status)")
        #endif
        guard status == noErr else {
            throw CryptorError.SecItemError(error: status)
        }
    }

    func delete(label: String) throws {
        guard self.mutex.lock(before: Date(timeIntervalSinceNow: 30)) else {
            throw CryptorError.timeOut
        }
        self.prepare(label: label)
        let status = SecItemDelete(self.query as NSDictionary)
        self.mutex.unlock()

        #if DEBUG
            print("thread=\(Thread.current)", String(reflecting: type(of: self)),
                  "\(#function) SecItemDelete = \(status)")
        #endif
        guard status == noErr || status == errSecItemNotFound else {
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
