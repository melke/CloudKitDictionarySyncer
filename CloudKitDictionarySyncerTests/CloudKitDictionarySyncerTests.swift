//
//  pomodoroTests.swift
//  pomodoroTests
//
//  Created by Mats Melke on 01/02/15.
//  Copyright (c) 2015 Baresi. All rights reserved.
//

import UIKit
import XCTest

class CloudKitDictionarySyncerTests: XCTestCase {

    let debugflag:Bool = false
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testSaveAndLoad() {

        let expectation = expectationWithDescription("testSave expectation")

        let p = CloudKitDictionarySyncer(dictname: "multitest8", debug: self.debugflag)
        var indict:NSMutableDictionary = NSMutableDictionary()
        indict["stringkey"] = "stringvalue"
        indict["boolkey"] = true
        indict["intkey"] = 4711
        var inarr = [String]()
        inarr.append("etta")
        inarr.append("tvåa")
        indict["arraykey"] = inarr
        p.saveDictionary(indict, onComplete: {
            status in
                self.debug("Save status = \(status)")
                p.loadDictionary(
                onComplete: {
                    loadResult in
                    var str = ""
                    var number = 0
                    var array = [String]()
                    var conflict = false
                    switch loadResult {
                    case .Dict(let loadeddict):
                        array = loadeddict["arraykey"] as [AnyObject] as [String]
                        array.append("trea") // Should be mutable
                        number = loadeddict["intkey"] as Int
                        number++
                        str = loadeddict["stringkey"] as String
                        loadeddict["newkey"] = "Newvalue"
                        self.debug("TEST CDS: Saved, loaded and changed dict = \(loadeddict)")
                    case .Conflict(let localdict, let clouddict, let latest):
                        conflict = true
                    }
                    
                    XCTAssert(str == "stringvalue", "Saving and loading should return stringvalue in dict")
                    expectation.fulfill()
                }
                )
            }
        )
        waitForExpectationsWithTimeout(10.0, handler:nil)

    }

    func testSaveAndLoadWhenPlistMissing() {

        let exp2 = expectationWithDescription("testSaveAndLoadWhenPlistMissing expectation")

        let p = CloudKitDictionarySyncer(dictname: "testwhenplistmissing", debug: self.debugflag)
        var indict:NSMutableDictionary = NSMutableDictionary()
        indict["stringkey"] = "stringvalue"
        p.saveDictionary(indict, onComplete: {
            status in
                self.debug("Save status = \(status)")
                self.removePlistFile("testwhenplistmissing.plist")
                p.loadDictionary(
                onComplete: {
                    outdict in
                    if p.iCloudEnabled {
                        self.debug("TEST CDS: Saved, removed plist and loaded from CloudKit dict = \(outdict!)")
                        XCTAssert(outdict!["stringkey"] as String == "stringvalue", "When has iCloud, reading from deleted plist should return dict from CloudKit")
                    } else {
                        self.debug("TEST CDS: Saved, removed plist, no iCloud so dict should be nil ")
                        XCTAssertNil(outdict, "When no iCloud, reading from deleted plist should return nil dict")
                    }
                    exp2.fulfill()
                }
                )
            }
        )
        waitForExpectationsWithTimeout(10.0, handler:nil)

    }

    func testSaveTurnOffiCloudAndLoadFromPlist() {

        let exp = expectationWithDescription("testSaveTurnOffiCloudAndLoadFromPlist expectation")

        let p = CloudKitDictionarySyncer(dictname: "testreadfromplistonly", debug: self.debugflag)
        let indict:NSMutableDictionary = ["stringkey":"stringvalue"]
        p.saveDictionary(indict, onComplete: {
            status in
                self.debug("Save status = \(status)")
                p.iCloudEnabled = false
                p.loadDictionary(
                onComplete: {
                    outdict in
                    if p.iCloudEnabled {
                        XCTFail("iCloud should not be enabled in this test")
                    } else {
                        self.debug("TEST CDS: Saved, disconnected icloud, reading dict from plist \(outdict!)")
                        XCTAssert(outdict!["stringkey"] as String == "stringvalue", "When saved and disconnected iCloud, load should return dict from plist")
                    }
                    exp.fulfill()
                }
                )
            }
        )
        waitForExpectationsWithTimeout(10.0, handler:nil)

    }

    func testSaveToBothUpdatePlistLoadLatestFromPlist() {

        let exp2 = expectationWithDescription("expectation")

        let p = CloudKitDictionarySyncer(dictname: "testlatestsync", debug: self.debugflag)
        var indict:NSMutableDictionary = NSMutableDictionary()
        indict["stringkey"] = "stringvalue"
        p.saveDictionary(indict, onComplete: {
            status in
            let timestamp = NSDate().timeIntervalSince1970
            self.debug("Save status = \(status)")
            self.debug("TS = \(timestamp)")
            self.touchPlistFile("testlatestsync.plist", timestamp:timestamp)
            p.loadDictionary(
            onComplete: {
                outdict in
                self.debug("TEST CDS: Saved to both, update plist only, should return latest from plist = \(outdict!)")
                XCTAssert(outdict!["CDSTimestamp"] as NSTimeInterval == timestamp, "When Saved to both, update plist only, should return latest from plist")
                XCTAssert(outdict!["CDSOrigin"] as String == "plistfile", "When Saved to both, update plist only, should return latest from plist")
                exp2.fulfill()
            }
            )
        }
        )
        waitForExpectationsWithTimeout(10.0, handler:nil)

    }

    private func removePlistFile(filename:String) {
        let paths = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true) as NSArray
        let documentsDirectory = paths[0] as String
        let plistpath = documentsDirectory.stringByAppendingPathComponent(filename)

        let fileManager = NSFileManager.defaultManager()

        //check if file exists
        if(fileManager.fileExistsAtPath(plistpath)) {
            var error:NSError?
            fileManager.removeItemAtPath(plistpath,error:&error)
            if error != nil {
                self.debug("TEST CDS: Could not remove \(filename)")
            } else {
                self.debug("TEST CDS: Removed \(filename)")
            }
        }
    }

    private func touchPlistFile(filename:String, timestamp:NSTimeInterval) {
        let paths = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true) as NSArray
        let documentsDirectory = paths[0] as String
        let plistpath = documentsDirectory.stringByAppendingPathComponent(filename)

        if let mutableDict = self.readDictionaryFromPlistFile(plistpath) {
            // Add save timestamp
            mutableDict["CDSTimestamp"] = timestamp
            mutableDict["CDSOrigin"] = "plistfile"

            // Save to plist
            mutableDict.writeToFile(plistpath, atomically: false)
            self.debug("TEST CDS: Saved to plist file")
        }
    }

    private func readDictionaryFromPlistFile(filepath:String) -> NSMutableDictionary? {
        let fileManager = NSFileManager.defaultManager()

        //check if file exists
        if(!fileManager.fileExistsAtPath(filepath)) {
            self.debug("TEST CDS: Warning: plist file not found \(filepath)")
            return nil
        }

        if let dict = NSMutableDictionary(contentsOfFile: filepath) {
            self.debug("TEST CDS: Loaded from \(filepath)")
            return dict
        } else {
            self.debug("TEST CDS: WARNING: Couldn't create dictionary from plistfile")
            return nil
        }

    }

    private func debug(msg:String) {
        if !self.debugflag {
            return
        }
        self.debug(msg)
    }

}
