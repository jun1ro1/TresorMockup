//
//  CryptorCore.swift
//  RandomData3
//
//  Created by OKU Junichirou on 2019/11/03.
//  Copyright (C) 2019 OKU Junichirou. All rights reserved.
//
//  https://qiita.com/m__ike_/items/e631960f801fc0b7ecfb
//  https://stackoverflow.com/questions/55378409/swift-5-0-withunsafebytes-is-deprecated-use-withunsafebytesr


import Foundation
import CommonCrypto
import SwiftyBeaver

typealias CryptorKeyType = Data

public enum CryptorError: Error {
    case unexpected
    case outOfRange
    case invalidCharacter
    case wrongPassword
    case notOpened
    case alreadyOpened
    case notPrepared
    case SecItemBroken
    case timeOut
    case CCCryptError(error: CCCryptorStatus)
    case SecItemError(error: OSStatus)
}

extension CryptorError: LocalizedError {
    /// Returns a description of the error.
    public var errorDescription: String?  {
        switch self {
        case .unexpected:
            return "Unexpected Error"
        case .outOfRange:
            return "Out of Range"
        case .invalidCharacter:
            return "Invalid Character"
        case .wrongPassword:
            return "Wrong Password"
        case .notOpened:
            return "Cryptor is not Opened"
        case .alreadyOpened:
            return "Cryptor is already Opened"
        case .notPrepared:
            return "Prepare is not called"
        case .SecItemBroken:
            return "SecItem is broken"
        case .timeOut:
            return "Time Out to acquire a lock"
        case .CCCryptError(let error):
            return "CCCrypt Error(\(error))"
        case .SecItemError(let error):
            return "SecItem Error(\(error))"
        }
    }
}

// https://stackoverflow.com/questions/39972512/cannot-invoke-xctassertequal-with-an-argument-list-errortype-xmpperror
extension CryptorError: Equatable {
    /// Returns a Boolean value indicating whether two values are equal.
    ///
    /// - Parameters:
    ///   - lhs: A left hand side expression.
    ///   - rhs: A right hand side expression.
    /// - Returns: `True` if `lhs` equals `rhs`, otherwise `false`.
    public static func == (lhs: CryptorError, rhs: CryptorError) -> Bool {
        switch (lhs, rhs) {
        case (.unexpected,       .unexpected),
             (.outOfRange,       .outOfRange),
             (.invalidCharacter, .invalidCharacter),
             (.wrongPassword,    .wrongPassword),
             (.notOpened,        .notOpened),
             (.alreadyOpened,    .alreadyOpened),
             (.notPrepared,      .notPrepared),
             (.SecItemBroken,    .SecItemBroken),
             (.timeOut, .timeOut):
            return true
        case (.CCCryptError(let error1), .CCCryptError(let error2)):
            return error1 == error2
        case (.SecItemError(let error1), .SecItemError(let error2)):
            return error1 == error2
        default:
            return false
        }
    }
}

fileprivate extension Data {
    func encrypt(with key: CryptorKeyType) throws -> Data {
        var cipher = Data(count: self.count + kCCKeySizeAES256)
        #if DEBUG_ERROR_CCCRYPT
            cipher = Data(count:1)
        #endif
        var dataOutMoved = 0
        let count = cipher.count
        let status: CCCryptorStatus =
            key.withUnsafeBytes { ptrKey in
                self.withUnsafeBytes { ptrPlain in
                    cipher.withUnsafeMutableBytes { ptrCipher in
                        CCCrypt(
                            CCOperation(kCCEncrypt),
                            CCAlgorithm(kCCAlgorithmAES128),
                            CCOptions(kCCOptionPKCS7Padding),
                            ptrKey.baseAddress?.assumingMemoryBound(to: UInt8.self),
                            key.count,
                            nil,
                            ptrPlain.baseAddress?.assumingMemoryBound(to: UInt8.self),
                            self.count,
                            ptrCipher.baseAddress?.assumingMemoryBound(to: UInt8.self),
                            count,
                            &dataOutMoved)
                    }
                }
        }
        #if DEBUG
        SwiftyBeaver.self.debug("CCCrypt(Encrypt) status = \(status)")
        #endif
        if status == kCCSuccess {
            cipher.removeSubrange(dataOutMoved..<cipher.count)
            return cipher
        }
        else {
            SwiftyBeaver.self.error("CCCrypt(Encrypt) status = \(status)")
            throw CryptorError.CCCryptError(error: status)
        }
    }

    func decrypt(with key: CryptorKeyType) throws -> Data {
        var plain = Data(count: self.count + kCCKeySizeAES256)
        var dataOutMoved = 0
        let plainCount = plain.count
        let status: CCCryptorStatus =
            key.withUnsafeBytes { ptrKey in
                self.withUnsafeBytes { ptrCipher in
                    plain.withUnsafeMutableBytes { ptrPlain in
                        CCCrypt(
                            CCOperation(kCCDecrypt),
                            CCAlgorithm(kCCAlgorithmAES128),
                            CCOptions(kCCOptionPKCS7Padding),
                            ptrKey.baseAddress?.assumingMemoryBound(to: UInt8.self),
                            key.count,
                            nil,
                            ptrCipher.baseAddress?.assumingMemoryBound(to: UInt8.self),
                            self.count,
                            ptrPlain.baseAddress?.assumingMemoryBound(to: UInt8.self),
                            plainCount,
                            &dataOutMoved)
                    }
                }
        }
        #if DEBUG
        SwiftyBeaver.self.debug("CCCrypt(Decrypt) status = \(status)")
        #endif

        if status == kCCSuccess {
            plain.removeSubrange(dataOutMoved..<plain.count)
            return plain
        }
        else {
            SwiftyBeaver.self.error("CCCrypt(Encrypt) status = \(status)")
            throw CryptorError.CCCryptError(error: status)
        }
    }

    func hash() -> Data {
        var hashed = Data(count:Int(CC_SHA256_DIGEST_LENGTH))
        _ = self.withUnsafeBytes { ptrData in
            hashed.withUnsafeMutableBytes { ptrHashed in
                CC_SHA256(ptrData.baseAddress?.assumingMemoryBound(to: UInt8.self),
                          CC_LONG(self.count),
                          ptrHashed.baseAddress?.assumingMemoryBound(to: UInt8.self))
            }
        }
        return hashed
    }

    mutating func reset() {
        self.resetBytes(in: self.startIndex..<self.endIndex)
    }
} // extension Data


fileprivate extension String {
    func decrypt(with key: CryptorKeyType) throws -> CryptorKeyType {
        guard let data = CryptorKeyType(base64Encoded: self, options: .ignoreUnknownCharacters) else {
            SwiftyBeaver.self.error("Invalid Character = ", self)
            throw CryptorError.invalidCharacter
        }
        return try data.decrypt(with: key)
    }

    func encrypt(with key: CryptorKeyType) throws -> String {
        guard let data = self.data(using: .utf8, allowLossyConversion: false) else {
            SwiftyBeaver.self.error("Invalid Character = ", self)
            throw CryptorError.invalidCharacter
        }
        return try data.encrypt(with: key).base64EncodedString()
    }

    func decrypt(with key: CryptorKeyType) throws -> String {
        guard var data = Data(base64Encoded: self, options: []) else {
            SwiftyBeaver.self.error("Invalid Character = ", self)
            throw CryptorError.invalidCharacter
        }
        defer { data.reset() }
        return String(data: try data.decrypt(with: key), encoding: .utf8)!
    }
} // extension String


// MARK: -
internal struct CryptorSeed {
    var version: String
    var salt:         CryptorKeyType?
    var rounds:       UInt32
    var key:          CryptorKeyType?
    var dateCreated:  Date?
    var dateModified: Date?

    static let label: String = "CryptorSeed"

    init() {
        self.version      = "0"
        self.salt         = nil
        self.rounds       = 1
        self.key          = nil
        self.dateCreated  = nil
        self.dateModified = nil
    }

    init(version: String, salt: CryptorKeyType) {
        self.init()
        self.version = version
        self.salt    = salt
        if self.version == "1" {
            self.rounds = 100000
        }
    }

    init(version: String, salt: CryptorKeyType, key: CryptorKeyType) {
        self.init(version: version, salt: salt)
        self.key = key
    }

    init?(_ str: String) {
        let ary = str.split(separator: ":")
        guard ary.count >= 3 else {
            return nil
        }
        let version = String(ary[0])
        let salt    = Data(base64Encoded: String(ary[1]))
        let key     = Data(base64Encoded: String(ary[2]))
        self.init(version: version, salt: salt!, key: key!)
    }

    mutating func reset() {
        self.version      = "0"
        self.salt         = nil
        self.rounds       = 1
        self.key          = nil
        self.dateCreated  = nil
        self.dateModified = nil
    }

    var string: String {
        return [
            self.version,
            self.salt?.base64EncodedString() ?? "",
            self.key?.base64EncodedString() ?? "",
            ].joined(separator: ":")
    }

    static func read() throws -> CryptorSeed? {
        guard var data = try SecureStore.shared.read(label: CryptorSeed.label) else {
            return nil
        }
        defer { data.reset() }

        // get a CryptorSeed string value from SecItem
        guard var str = String(data: data, encoding: .utf8) else {
            throw CryptorError.SecItemBroken
        }
        defer{ str = "" }

        guard var seed = CryptorSeed(str) else {
            throw CryptorError.SecItemBroken
        }
        seed.dateCreated  = SecureStore.shared.created
        seed.dateModified = SecureStore.shared.modified
        return seed
    }

    static func write(_ seed: CryptorSeed) throws {
        guard var data = seed.string.data(using: .utf8) else {
            throw CryptorError.unexpected
        }
        defer { data.reset() }
        try SecureStore.shared.write(label: CryptorSeed.label, data)
    }

    static func update(_ seed:CryptorSeed) throws {
        guard var data = seed.string.data(using: .utf8) else {
            throw CryptorError.unexpected
        }
        defer { data.reset() }
        try SecureStore.shared.update(label: CryptorSeed.label, data)
    }

    static func delete() throws {
        try SecureStore.shared.delete(label: CryptorSeed.label)
    }
} // CryptorSeed

// MARK: -
internal class Validator {
    var hashedMark:    CryptorKeyType? = nil
    var encryptedMark: CryptorKeyType? = nil

    static let label: String = "Validator"

    init?(_ str: String) {
        let ary = str.split(separator: ":")
        guard ary.count >= 2 else {
            return nil
        }
        self.hashedMark     = Data(base64Encoded: String(ary[0]))
        self.encryptedMark  = Data(base64Encoded: String(ary[1]))
    }

    init?(key: CryptorKeyType) {
        guard var mark: CryptorKeyType = try? RandomData.shared.get(count: 16) else {
            return nil
        }
        defer { mark.reset() }

        // get a hashed mark
        self.hashedMark = mark.hash()

        #if DEBUG
            print("thread=\(Thread.current)", String(reflecting: type(of: self)),
                  "\(#function) mark   =", mark as NSData)
            print("thread=\(Thread.current)", String(reflecting: type(of: self)),
                  "\(#function) hshMark=", self.hashedMark! as NSData)
        #endif

        self.encryptedMark = try? mark.encrypt(with: key)
        guard self.encryptedMark != nil else {
            return nil
        }

        #if DEBUG
            print("thread=\(Thread.current)", String(reflecting: type(of: self)),
                  "\(#function) encryptedMark=", self.encryptedMark! as NSData)
        #endif
    }

    func reset() {
        self.hashedMark?.reset()
        self.encryptedMark?.reset()
    }

    var string: String {
        return [
            self.hashedMark?.base64EncodedString() ?? "",
            self.encryptedMark?.base64EncodedString() ?? "",
            ].joined(separator: ":")
    }

    func validate(key: CryptorKeyType) -> Bool {
        guard self.hashedMark != nil && self.encryptedMark != nil else {
            return false
        }

        do {
            // get binary Mark
            var decryptedMark: CryptorKeyType = try self.encryptedMark!.decrypt(with: key)
            defer { decryptedMark.reset() }

            var hashedDecryptedMark: CryptorKeyType = decryptedMark.hash()
            defer { hashedDecryptedMark.reset() }

            #if DEBUG
                print("thread=\(Thread.current)", String(reflecting: type(of: self)),
                      "\(#function) hashedMark          =", hashedMark! as NSData)
                print("thread=\(Thread.current)", String(reflecting: type(of: self)),
                      "\(#function) hashedDecryptedMark =", hashedDecryptedMark as NSData)
            #endif

            return hashedMark == hashedDecryptedMark
        } catch {
            return false
        }
    }

    static func read() throws -> Validator? {
        guard var data = try SecureStore.shared.read(label: Validator.label) else {
            throw CryptorError.SecItemBroken
        }
        defer { data.reset() }

        guard var str = String(data: data, encoding: .utf8) else {
            throw CryptorError.SecItemBroken
        }
        defer { str = "" }

        guard let validator = Validator(str) else {
            throw CryptorError.SecItemBroken
        }
        return validator
    }

    static func write(_ validator: Validator) throws {
        guard var data = validator.string.data(using: .utf8) else {
            throw CryptorError.unexpected
        }
        defer { data.reset() }
        try SecureStore.shared.write(label: Validator.label, data)
    }

    static func delete() throws {
        try SecureStore.shared.delete(label: Validator.label)
    }
} // Validator

// MARK: -
private struct Session {
    var cryptor: Cryptor
    var itk:     CryptorKeyType
    // Inter key: the KEK(Key kncryption Key) encrypted with SEK(Session Key)

    init(cryptor: Cryptor, itk: CryptorKeyType) {
        self.cryptor = cryptor
        self.itk  = itk
    }
}


// MARK: -
internal class CryptorCore {
    // constants
    public static let MAX_PASSWORD_LENGTH = 1000

    // instance variables
    private var sessions: [Int: Session] = [:]
    private var mutex: NSLock = NSLock()

    static var shared = CryptorCore()

    var isPrepared: Bool {
        let seed = try? CryptorSeed.read()
        return seed != nil
    }

    private init() {
    }

    // MARK: - methods
    private func getKEK(password: String, seed: CryptorSeed) throws -> CryptorKeyType {
        // check password
        guard case 1...CryptorCore.MAX_PASSWORD_LENGTH = password.count else {
            throw CryptorError.outOfRange
        }

        // convert the password to a Data
        guard var binPASS = password.data(using: .utf8, allowLossyConversion: true) else {
            throw CryptorError.invalidCharacter
        }
        defer { binPASS.reset() }

        // derivate an CEK with the password and the SALT
        guard var salt: CryptorKeyType = seed.salt else {
            throw CryptorError.SecItemBroken
        }
        defer { salt.reset() }

        var kek = CryptorKeyType(count: Int(kCCKeySizeAES256))
        var status: CCCryptorStatus = CCCryptorStatus(kCCSuccess)
        // https://opensource.apple.com/source/CommonCrypto/CommonCrypto-55010/CommonCrypto/CommonKeyDerivation.h
        // https://github.com/apportable/CommonCrypto/blob/master/include/CommonCrypto/CommonKeyDerivation.h
        // https://stackoverflow.com/questions/25691613/swift-how-to-call-cckeyderivationpbkdf-from-swift
        // https://stackoverflow.com/questions/35749197/how-to-use-common-crypto-and-or-calculate-sha256-in-swift-2-3
        guard self.mutex.lock(before: Date(timeIntervalSinceNow: 30)) else {
            throw CryptorError.timeOut
        }
        status =
            salt.withUnsafeBytes { ptrSALT in
                binPASS.withUnsafeBytes { ptrPASS in
                    let count = kek.count
                    return kek.withUnsafeMutableBytes { ptrKEK in
                        CCKeyDerivationPBKDF(CCPBKDFAlgorithm(kCCPBKDF2),
                                             ptrPASS.baseAddress?.assumingMemoryBound(to: Int8.self),
                                             binPASS.count,
                                             ptrSALT.baseAddress?.assumingMemoryBound(to: UInt8.self),
                                             salt.count,
                                             CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                                             seed.rounds,
                                             ptrKEK.baseAddress?.assumingMemoryBound(to: UInt8.self),
                                             count)
                    }
                }
        }
        self.mutex.unlock()
        #if DEBUG
            print("thread=\(Thread.current)", String(reflecting: type(of: self)),
                  "\(#function) CCKeyDerivationPBKDF status=", status)
            print("thread=\(Thread.current)", String(reflecting: type(of: self)),
                  "\(#function) KEK   =", kek as NSData)
        #endif
        guard status == CCCryptorStatus(kCCSuccess) else {
            throw CryptorError.CCCryptError(error: status)
        }
        return kek
    }

    func prepare(password: String) throws {
        if var seed = try CryptorSeed.read() {
            var validator = try Validator.read()
            defer { validator?.reset() }

            // get a CEK encrypted with a KEK
            guard var cekEnc = seed.key else {
                throw CryptorError.SecItemBroken
            }
            defer{ cekEnc.reset() }

            // derivate a KEK with the password and the SALT
            var kek = try self.getKEK(password: password, seed: seed)
            defer{ kek.reset() }

            // get a CEK
            var cek = try cekEnc.decrypt(with: kek)
            defer{ cek.reset() }

            guard validator?.validate(key: cek) == true else {
                throw CryptorError.wrongPassword
            }
        }
        else {
            // convert the password to a Data
            guard var binPASS: CryptorKeyType = password.data(using: .utf8, allowLossyConversion: true) else {
                throw CryptorError.invalidCharacter
            }
            defer { binPASS.reset() }

            // create a salt
            var salt: CryptorKeyType = try RandomData.shared.get(count: 16)
            defer { salt.reset() }

            // create a CryptorSeed
            var seed = CryptorSeed(version: "1", salt: salt)

            // derivate a KEK with the password and the SALT
            var kek = try self.getKEK(password: password, seed: seed)
            defer { kek.reset() }

            // create a CEK
            var cek: CryptorKeyType = try RandomData.shared.get(count: Int(kCCKeySizeAES256))
            defer { cek.reset() }

            // create a Validator
            guard var validator = Validator(key: cek) else {
                throw CryptorError.unexpected
            }
            defer { validator.reset() }

            // encrypt the CEK with the KEK
            // https://stackoverflow.com/questions/25754147/issue-using-cccrypt-commoncrypt-in-swift
            // https://stackoverflow.com/questions/37680361/aes-encryption-in-swift
            var cekEnc: CryptorKeyType = try cek.encrypt(with: kek)
            defer { cekEnc.reset() }
            seed.key = cekEnc

            try CryptorSeed.write(seed)
            try Validator.write(validator)

            #if DEBUG
                print("thread=\(Thread.current)", String(reflecting: type(of: self)),
                      "\(#function) salt  =", salt as NSData)
                print("thread=\(Thread.current)", String(reflecting: type(of: self)),
                      "\(#function) kek   =", kek as NSData)
                print("thread=\(Thread.current)", String(reflecting: type(of: self)),
                      "\(#function) cek   =", cek as NSData)
                print("thread=\(Thread.current)", String(reflecting: type(of: self)),
                      "\(#function) cekEnc=", cekEnc as NSData)
            #endif
        }
    }


    func open(password: String, cryptor: Cryptor) throws -> CryptorKeyType {
        var status: CCCryptorStatus = CCCryptorStatus(kCCSuccess)

        // get a seed
        guard var seed = try CryptorSeed.read() else {
            throw CryptorError.notPrepared
        }
        defer { seed.reset() }

        guard var validator = try Validator.read() else {
            throw CryptorError.notPrepared
        }
        defer { validator.reset() }

        // get a CEK encrypted with a KEK
        guard var cekEnc = seed.key else {
            throw CryptorError.SecItemBroken
        }
        defer{ cekEnc.reset() }

        // derivate a KEK with the password and the SALT
        var kek = try self.getKEK(password: password, seed: seed)
        defer{ kek.reset() }

        // get a CEK
        var cek = try cekEnc.decrypt(with: kek)
        defer{ cek.reset() }

        guard validator.validate(key: cek) == true else {
            throw CryptorError.wrongPassword
        }

        #if DEBUG
            print("thread=\(Thread.current)", String(reflecting: type(of: self)),
                  "\(#function) cek   =", cek as NSData)
        #endif

        // check CEK
        guard validator.validate(key: cek) == true else {
            #if DEBUG
                print("thread=\(Thread.current)", String(reflecting: type(of: self)),
                      "\(#function) validate= false")
            #endif
            throw CryptorError.wrongPassword
        }

        var sek: CryptorKeyType = try RandomData.shared.get(count: kCCKeySizeAES256)
        defer { sek.reset() }

        var itk: CryptorKeyType = try kek.encrypt(with: sek)
        defer { itk.reset() }

        let session = Session(cryptor: cryptor, itk: itk)
        self.mutex.lock()
        self.sessions[ObjectIdentifier(cryptor).hashValue] = session
        self.mutex.unlock()

        return sek
    }


    func close(cryptor: Cryptor) throws {
        self.mutex.lock()
        let result = self.sessions.removeValue(forKey: ObjectIdentifier(cryptor).hashValue)
        self.mutex.unlock()

        guard result != nil else {
            throw CryptorError.notOpened
        }
    }

    func closeAll() throws {
        var errors = 0
        while true {
            self.mutex.lock()
            let before = self.sessions.count
            let session = self.sessions.first?.value
            self.mutex.unlock()

            guard session != nil else {
                break
            }
            try self.close(cryptor: session!.cryptor)

            self.mutex.lock()
            let after = self.sessions.count
            self.mutex.unlock()
            if before >= after {
                errors += 1
            }
            guard errors < 100 else {
                throw CryptorError.unexpected
            }
        }
    }

    func change(password oldpass: String, to newpass: String) throws {
        var status: CCCryptorStatus = CCCryptorStatus(kCCSuccess)

        // get a seed
        guard var seed = try CryptorSeed.read() else {
            throw CryptorError.notPrepared
        }
        defer { seed.reset() }

        guard var validator = try Validator.read() else {
            throw CryptorError.notPrepared
        }
        defer { validator.reset() }

        // get a CEK encrypted with a KEK
        guard var cekEnc = seed.key else {
            throw CryptorError.SecItemBroken
        }
        defer{ cekEnc.reset() }

        // derivate a KEK with the password and the SALT
        var kek = try self.getKEK(password: oldpass, seed: seed)
        defer{ kek.reset() }

        // get a CEK
        var cek = try cekEnc.decrypt(with: kek)
        defer{ cek.reset() }

        guard validator.validate(key: cek) == true else {
            throw CryptorError.wrongPassword
        }

        // check CEK
        guard validator.validate(key: cek) == true else {
            #if DEBUG
                print("thread=\(Thread.current)", String(reflecting: type(of: self)),
                      "\(#function) validate= false")
            #endif
            throw CryptorError.wrongPassword
        }


        // change KEK
        var newkek = try self.getKEK(password: newpass, seed: seed)
        defer { newkek.reset() }

        // crypt a CEK with a new KEK
        var newcekEnc: CryptorKeyType = try cek.encrypt(with: newkek)
        defer { newcekEnc.reset() }

        seed.key = newcekEnc
        try CryptorSeed.update(seed)

        #if DEBUG
            print("thread=\(Thread.current)", String(reflecting: type(of: self)),
                  "\(#function) newkek    =", newkek as NSData)
            print("thread=\(Thread.current)", String(reflecting: type(of: self)),
                  "\(#function) cek       =", cek as NSData)
            print("thread=\(Thread.current)", String(reflecting: type(of: self)),
                  "\(#function) newkekEnc =", newcekEnc as NSData)
        #endif
    }

    func encrypt(cryptor: Cryptor, plain: Data) throws -> Data {
        guard let sek = cryptor.key else {
            throw CryptorError.notOpened
        }
        self.mutex.lock()
        let session = self.sessions[ObjectIdentifier(cryptor).hashValue]
        self.mutex.unlock()

        #if DEBUG
            print("thread=\(Thread.current)", String(reflecting: type(of: self)),
                  "\(#function) session.itk = ", (session?.itk as NSData?) ?? "nil")
        #endif
        guard var itk = session?.itk else {
            throw CryptorError.notOpened
        }
        defer { itk.reset() }

        var kek = try itk.decrypt(with: sek)
        defer { kek.reset() }

        // get a seed
        guard var seed = try CryptorSeed.read() else {
            throw CryptorError.notPrepared
        }
        defer { seed.reset() }

        // get a CEK encrypted with a KEK
        guard var cekEnc = seed.key else {
            throw CryptorError.SecItemBroken
        }
        defer{ cekEnc.reset() }

        var cek: CryptorKeyType = try cekEnc.decrypt(with: kek)
        defer { cek.reset() }

        return try plain.encrypt(with: cek)
    }

    func decrypt(cryptor: Cryptor, cipher: Data) throws -> Data {
        guard let sek = cryptor.key else {
            throw CryptorError.notOpened
        }
        self.mutex.lock()
        let session = self.sessions[ObjectIdentifier(cryptor).hashValue]
        self.mutex.unlock()

        #if DEBUG
            print("thread=\(Thread.current)", String(reflecting: type(of: self)),
                  "\(#function) session.itk = ", (session?.itk as NSData?) ?? "nil")
        #endif
        guard var itk = session?.itk else {
            throw CryptorError.notOpened
        }
        defer { itk.reset() }

        var kek = try itk.decrypt(with: sek)
        defer { kek.reset() }

        // get a seed
        guard var seed = try CryptorSeed.read() else {
            throw CryptorError.notPrepared
        }
        defer { seed.reset() }

        // get a CEK encrypted with a KEK
        guard var cekEnc = seed.key else {
            throw CryptorError.SecItemBroken
        }
        defer{ cekEnc.reset() }

        var cek: CryptorKeyType = try cekEnc.decrypt(with: kek)
        defer { cek.reset() }

        return try cipher.decrypt(with: cek)
    }

    func encrypt(cryptor: Cryptor, plain: String) throws -> String {
        guard let sek = cryptor.key else {
            throw CryptorError.notOpened
        }
        self.mutex.lock()
        let session = self.sessions[ObjectIdentifier(cryptor).hashValue]
        self.mutex.unlock()

        #if DEBUG
            print("thread=\(Thread.current)", String(reflecting: type(of: self)),
                  "\(#function) session.itk = ", (session?.itk as NSData?) ?? "nil")
        #endif
        guard var itk = session?.itk else {
            throw CryptorError.notOpened
        }
        defer { itk.reset() }

        var kek = try itk.decrypt(with: sek)
        defer { kek.reset() }

        // get a seed
        guard var seed = try CryptorSeed.read() else {
            throw CryptorError.notPrepared
        }
        defer { seed.reset() }

        // get a CEK encrypted with a KEK
        guard var cekEnc = seed.key else {
            throw CryptorError.SecItemBroken
        }
        defer{ cekEnc.reset() }

        var cek: CryptorKeyType = try cekEnc.decrypt(with: kek)
        defer { cek.reset() }

        return try plain.encrypt(with: cek)
    }

    func decrypt(cryptor: Cryptor, cipher: String) throws -> String {
        guard let sek = cryptor.key else {
            throw CryptorError.notOpened
        }

        self.mutex.lock()
        let session = self.sessions[ObjectIdentifier(cryptor).hashValue]
        self.mutex.unlock()

        #if DEBUG
            print("thread=\(Thread.current)", String(reflecting: type(of: self)),
                  "\(#function) session.itk = ", (session?.itk as NSData?) ?? "nil")
        #endif
        guard var itk = session?.itk else {
            throw CryptorError.notOpened
        }
        defer { itk.reset() }

        var kek = try itk.decrypt(with: sek)
        defer { kek.reset() }

        // get a seed
        guard var seed = try CryptorSeed.read() else {
            throw CryptorError.notPrepared
        }
        defer { seed.reset() }

        // get a CEK encrypted with a KEK
        guard var cekEnc = seed.key else {
            throw CryptorError.SecItemBroken
        }
        defer{ cekEnc.reset() }

        var cek: CryptorKeyType = try cekEnc.decrypt(with: kek)
        defer { cek.reset() }

        return try cipher.decrypt(with: cek)
    }
}

