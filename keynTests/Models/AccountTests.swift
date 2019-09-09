/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */

import XCTest
import OneTimePassword

@testable import keyn

class AccountTests: XCTestCase {
    
    let username = "test@keyn.com"
    var account: Account!
    let context = FakeLAContext()
    
    override func setUp() {
        super.setUp()
        TestHelper.createSeed()
    }
    
    override func tearDown() {
        super.tearDown()
        TestHelper.deleteLocalData()
    }
    
    // MARK: - Unit tests
    
    func testInitDoesntThrow() {
        let site = TestHelper.sampleSite
        XCTAssertNoThrow(try Account(username: username, sites: [site], passwordIndex: 0, password: nil, context: context))
    }
    
    func testNextPassword() {
        let site = TestHelper.sampleSite
        do {
            account = try Account(username: username, sites: [site], passwordIndex: 0, password: nil, context: context)
            XCTAssertEqual(try account.nextPassword(), "[jh6eAX)og7A#nJ1:YDSrD6#61cf${\"A")
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testOneTimePasswordToken() {
        let site = TestHelper.sampleSite
        do {
            account = try Account(username: username, sites: [site], passwordIndex: 0, password: nil, context: context)
            TestHelper.saveHOTPToken(id: account.id)
            let token = try account.oneTimePasswordToken()
            XCTAssertNotNil(token)
            XCTAssertEqual(token!.currentPassword!, "780815")                   // First HOTP password
            XCTAssertEqual(token!.updatedToken().currentPassword!, "405714")    // Second HOTP password
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
    func testSetOtpDoesntThrow() {
        guard let token = Token(url: TestHelper.hotpURL) else {
            return XCTFail("Error creating token")
        }
        let site = TestHelper.sampleSite
        do {
            account = try Account(username: username, sites: [site], passwordIndex: 0, password: nil, context: context)
            XCTAssertNoThrow(try account.setOtp(token: token))
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
    func testDeleteOtp() {
        let site = TestHelper.sampleSite
        do {
            account = try Account(username: username, sites: [site], passwordIndex: 0, password: nil, context: context)
            TestHelper.saveHOTPToken(id: account.id)
            XCTAssertNoThrow(try account.deleteOtp())
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
    func testAddSite() {
        let site = TestHelper.sampleSite
        do {
            account = try Account(username: username, sites: [site], passwordIndex: 0, password: nil, context: context)
            XCTAssertNoThrow(try account.addSite(site: site))
            XCTAssertEqual(account.sites.count, 2)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
    func testRemoveSite() {
        let site = TestHelper.sampleSite
        do {
            account = try Account(username: username, sites: [site], passwordIndex: 0, password: nil, context: context)
            XCTAssertNoThrow(try account.removeSite(forIndex: 0))
            XCTAssertEqual(account.sites.count, 0)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
    func testUpdateSite() {
        let site = TestHelper.sampleSite
        do {
            account = try Account(username: username, sites: [site], passwordIndex: 0, password: nil, context: context)
            XCTAssertNoThrow(try account.updateSite(url: "google.com", forIndex: 0))
            XCTAssertEqual(account.sites.count, 1)
            XCTAssertEqual(account.sites[0].url, "google.com")
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
    func testUpdate() {
        let site = TestHelper.sampleSite
        do {
            let username = "test2@keyn.com"
            let siteName = "Google"
            let password = "testPassword"
            let url = "www.google.com"
            account = try Account(username: username, sites: [site], passwordIndex: 0, password: nil, context: context)
            XCTAssertNoThrow(try account.update(username: username, password: password, siteName: siteName, url: url, askToLogin: true, askToChange: false, enabled: true, context: context))
            XCTAssertEqual(account.username, username)
            XCTAssertEqual(try account.password(), password)
            XCTAssertEqual(account.site.name, siteName)
            XCTAssertEqual(account.site.url, url)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
    func testUpdatePasswordAfterConfirmation() {
        let site = TestHelper.sampleSite
        do {
            account = try Account(username: username, sites: [site], passwordIndex: 0, password: nil, context: context)
            XCTAssertNoThrow(try account.updatePasswordAfterConfirmation(context: context))
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
    func testDelete() {
        TestHelper.createBackupKeys()
        let site = TestHelper.sampleSite
        do {
            account = try Account(username: username, sites: [site], passwordIndex: 0, password: nil, context: context)
            let accountId = account.id
            account.delete { (result) in
                do {
                    let _ = try result.get()
                    XCTAssertNil(try Account.get(accountID: accountId, context: self.context))
                } catch {
                    XCTFail(error.localizedDescription)
                }
            }

        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
    func testPassword() {
        let site = TestHelper.sampleSite
        do {
            account = try Account(username: username, sites: [site], passwordIndex: 0, password: nil, context: context)
            account.password(reason: "Testing", context: context, type: .ifNeeded) { (result) in
                switch result {
                case .failure(let error): XCTFail(error.localizedDescription)
                case .success(let password): XCTAssertEqual(password, "vGx$85gzsLZ/eK23ngx[afwG^0?#y%]C")
                }
            }
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
    func testAll() {
        XCTAssertNoThrow(try Account.all(context: context))
        XCTAssertTrue(try Account.all(context: context).isEmpty)
    }
    
    func testGetAccount() {
        XCTAssertNil(try Account.get(accountID: "noid", context: context))
    }
    
    func testSave() {
        TestHelper.createBackupKeys()
        let id = "32e4f0a21f65dc78cc065af6a3fb6e91e1c0fb8882f09aa3a266e1ecff7b0dd5"
        guard let accountData = "eyJwYXNzd29yZEluZGV4IjowLCJhc2tUb0NoYW5nZSI6ZmFsc2UsImlkIjoiMzJlNGYwYTIxZjY1ZGM3OGNjMDY1YWY2YTNmYjZlOTFlMWMwZmI4ODgyZjA5YWEzYTI2NmUxZWNmZjdiMGRkNSIsImVuYWJsZWQiOmZhbHNlLCJsYXN0UGFzc3dvcmRVcGRhdGVUcnlJbmRleCI6MCwidXNlcm5hbWUiOiJ0ZXN0QGtleW4uY29tIiwic2l0ZXMiOlt7ImlkIjoiYTM3OWE2ZjZlZWFmYjlhNTVlMzc4YzExODAzNGUyNzUxZTY4MmZhYjlmMmQzMGFiMTNkMjEyNTU4NmNlMTk0NyIsIm5hbWUiOiJFeGFtcGxlIiwidXJsIjoiZXhhbXBsZS5jb20iLCJwcGQiOnsiY2hhcmFjdGVyU2V0cyI6W3siYmFzZSI6W10sImNoYXJhY3RlcnMiOiJhYmNkZWZnaGlqa2xtbm9wcXJzdHV2d3h5eiIsIm5hbWUiOiJMb3dlckxldHRlcnMifSx7ImJhc2UiOltdLCJjaGFyYWN0ZXJzIjoiQUJDREVGR0hJSktMTU5PUFFSU1RVVldYWVoiLCJuYW1lIjoiVXBwZXJMZXR0ZXJzIn0seyJiYXNlIjpbXSwiY2hhcmFjdGVycyI6IjAxMjM0NTY3ODkiLCJuYW1lIjoiTnVtYmVycyJ9LHsiYmFzZSI6W10sImNoYXJhY3RlcnMiOiIpKComXiUkI0Ahe31bXTo7XCInP1wvLC48PmB-fCIsIm5hbWUiOiJTcGVjaWFscyJ9XSwicHJvcGVydGllcyI6eyJtYXhMZW5ndGgiOjMyLCJleHBpcmVzIjowLCJtaW5MZW5ndGgiOjh9LCJ0aW1lc3RhbXAiOjU4OTY5Mjg3NC45MDUyNTE5OCwidXJsIjoiaHR0cHM6XC9cL2V4YW1wbGUuY29tIiwibmFtZSI6IkV4YW1wbGUiLCJ2ZXJzaW9uIjoiMS4wIn19XSwidmVyc2lvbiI6MX0".fromBase64 else {
            return XCTFail("Error converting to data")
        }
        XCTAssertNoThrow(try Account.save(accountData: accountData, id: id, context: context))
        XCTAssertNotNil(try Account.get(accountID: id, context: context))
    }
    
    func testAccountList() {
        XCTAssertNoThrow(try Account.accountList(context: context))
        XCTAssertTrue(try Account.accountList(context: context).isEmpty)
    }

    func testDeleteAll() {
        let site = TestHelper.sampleSite
        XCTAssertNoThrow(try Account(username: username, sites: [site], passwordIndex: 0, password: nil, context: context))
        XCTAssertNoThrow(try Account(username: username + "2", sites: [site], passwordIndex: 0, password: nil, context: context))
        Account.deleteAll()
        XCTAssertEqual(try Account.all(context: context).count, 0)
    }
    
    // MARK: - Integration Tests

    func testUpdatePasswordAndConfirm() {
        let site = TestHelper.sampleSite
        do {
            account = try Account(username: username, sites: [site], passwordIndex: 0, password: nil, context: context)
            let newPassword = try account.nextPassword()
            XCTAssertNotEqual(newPassword, try account.password())
            XCTAssertNoThrow(try account.updatePasswordAfterConfirmation(context: context))
            XCTAssertEqual(newPassword, try account.password())
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
    func testSetOtpAndDeleteOtp() {
        guard let token = Token(url: TestHelper.hotpURL) else {
            return XCTFail("Error creating token")
        }
        let site = TestHelper.sampleSite
        do {
            account = try Account(username: username, sites: [site], passwordIndex: 0, password: nil, context: context)
            XCTAssertNoThrow(try account.setOtp(token: token))
            XCTAssertNoThrow(try account.deleteOtp())
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
    func testAddSiteAndRemoveSite() {
        let site = TestHelper.sampleSite
        do {
            account = try Account(username: username, sites: [site], passwordIndex: 0, password: nil, context: context)
            XCTAssertNoThrow(try account.addSite(site: site))
            XCTAssertEqual(account.sites.count, 2)
            XCTAssertNoThrow(try account.removeSite(forIndex: 0))
            XCTAssertEqual(account.sites.count, 1)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
}
