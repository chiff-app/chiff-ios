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
    
    func testNextPasswordDoesntThrow() {
        let site = TestHelper.sampleSite
        do {
            account = try Account(username: username, sites: [site], passwordIndex: 0, password: nil, context: context)
            XCTAssertNoThrow(try account.nextPassword())
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
            account = try Account(username: username, sites: [site], passwordIndex: 0, password: nil, context: context)
            XCTAssertNoThrow(try account.update(username: username + "2", password: "testPassword", siteName: "Google", url: "www.google.com", askToLogin: true, askToChange: false, enabled: true, context: context))
            XCTAssertEqual(account.username, username + "2")
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
            account.delete { (result) in
                if case let .failure(error) = result {
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
    }
    
    func testAccountList() {
        XCTAssertNoThrow(try Account.accountList(context: context))
        XCTAssertTrue(try Account.accountList(context: context).isEmpty)
    }
    
    // MARK: - Integration Tests
    
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
