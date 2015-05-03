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

    let debugflag:Bool = true
    
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

        let p = CloudKitDictionarySyncer(dictname: "multitesting", debug: self.debugflag)
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
                        array = loadeddict["arraykey"] as! [AnyObject] as! [String]
                        array.append("trea") // Should be mutable
                        number = loadeddict["intkey"] as! Int
                        number++
                        str = loadeddict["stringkey"] as! String
                        loadeddict["newkey"] = "Newvalue"
                        self.debug("TEST CDS: Saved, loaded and changed dict = \(loadeddict)")
                    case .Conflict(let localdict, let clouddict, let latest):
                        conflict = true
                    }
                    
                    XCTAssertFalse(conflict, "Saving and loading should not produce conflict")
                    XCTAssert(array == ["etta","tvåa","trea"], "Saving and loading and changing mutable array in dict should work")
                    XCTAssert(str == "stringvalue", "Saving and loading should return stringvalue in dict")
                    XCTAssert(number == 4712, "Saving and loading should return mutable int from dict")
                    expectation.fulfill()
                }
                )
            }
        )
        waitForExpectationsWithTimeout(10.0, handler:nil)

    }

    func testSaveAndLoadWhenPlistMissing() {
        let exp = expectationWithDescription("testSaveAndLoadWhenPlistMissing expectation")
        let p = CloudKitDictionarySyncer(dictname: "testcasewhenplistmissing", debug: self.debugflag)
        var indict:NSMutableDictionary = NSMutableDictionary()
        indict["stringkey"] = "stringvalue"
        p.saveDictionary(indict, onComplete: {
            status in
                self.debug("Save status = \(status)")
                self.removePlistFile("testcasewhenplistmissing.plist")
                p.loadDictionary(
                onComplete: {
                    loadResult in
                    var conflict = false
                    switch loadResult {
                    case .Dict(let loadeddict):
                        if p.iCloudEnabled {
                            XCTAssert(loadeddict["CDSOrigin"] as! String == "iCloud", "When iCloud and plist is missing, CDSOrigin should be iCloud")
                        } else {
                            XCTAssertTrue(loadeddict.count == 0, "When plist is missing and icloud disabled, a an empty Dict should be returned")
                            self.debug("TEST CDS: Saved, removed plist, icloud disabled loaded empty dict = \(loadeddict)")
                        }
                    case .Conflict(let localdict, let clouddict, let latest):
                        if p.iCloudEnabled {
                            XCTAssertTrue(latest == .CloudKit, "When plist is missing and icloud enabled, latest should be .CloudKit")
                            XCTAssert(clouddict["stringkey"] as! String == "stringvalue", "When iCloud enabled, reading from deleted plist should return dict from CloudKit")
                            self.debug("TEST CDS: Saved, removed plist and loaded from CloudKit dict = \(clouddict)")
                        } else {
                            XCTFail("When plist is missing and icloud disabled, there should never be a conflict")
                        }
                    }
                    exp.fulfill()
                })
            }
        )
        waitForExpectationsWithTimeout(10.0, handler:nil)
    }

    func testSaveTurnOffiCloudAndLoadFromPlist() {

        let exp = expectationWithDescription("testSaveTurnOffiCloudAndLoadFromPlist expectation")

        let p = CloudKitDictionarySyncer(dictname: "testcasereadfromplistonly", debug: self.debugflag)
        let indict:NSMutableDictionary = ["stringkey":"stringvalue"]
        p.saveDictionary(indict, onComplete: {
            status in
                self.debug("Save status = \(status)")
                p.iCloudEnabled = false
                p.loadDictionary(
                onComplete: {

                    loadResult in
                    var conflict = false
                    switch loadResult {
                    case .Dict(let loadeddict):
                        if p.iCloudEnabled {
                            XCTFail("iCloud should not be enabled in this test")
                        } else {
                            self.debug("TEST CDS: Saved, disconnected icloud, reading dict from plist \(loadeddict)")
                            XCTAssert(loadeddict["stringkey"] as! String == "stringvalue", "When saved and disconnected iCloud, load should return dict from plist")
                            XCTAssert(loadeddict["CDSOrigin"] as! String == "plistfile", "When saved and disconnected iCloud, CDSOrigin should be plistfile")
                        }
                    case .Conflict(let localdict, let clouddict, let latest):
                        XCTFail("There should be no conflicts in this test")
                    }
                    exp.fulfill()
                }
                )
            }
        )
        waitForExpectationsWithTimeout(10.0, handler:nil)

    }

    func testSaveToBothThenUpdatePlistToForceConflict() {

        let exp = expectationWithDescription("expectation")

        let p = CloudKitDictionarySyncer(dictname: "testcaseconflict", debug: self.debugflag)
        var indict:NSMutableDictionary = NSMutableDictionary()
        indict["stringkey"] = "stringvalue"
        p.saveDictionary(indict, onComplete: {
            status in
            let timestamp = UInt32(NSDate().timeIntervalSince1970)
            self.debug("Save status = \(status)")
            self.debug("TS = \(timestamp)")
            self.touchPlistFile("testcaseconflict.plist", timestamp:timestamp)
            p.loadDictionary(
            onComplete: {
                
                loadResult in
                var conflict = false
                switch loadResult {
                case .Dict(let loadeddict):
                    if p.iCloudEnabled {
                        XCTFail("When icloud enabled, and plist is changed, a single Dict should not be returned")
                    } else {
                        XCTAssert(loadeddict["CDSOrigin"] as! String == "plistfile", "When icloud enabled, and plist is changed, CDSOrigin should be plistfile")
                        self.debug("TEST CDS: Saved, touched plist, icloud disabled plist dict = \(loadeddict)")
                    }
                case .Conflict(let localdict, let clouddict, let latest):
                    if p.iCloudEnabled {
                        XCTAssertTrue(latest == .Plist, "When plist is touched and icloud enabled, latest should be .Plist")
                        XCTAssert(localdict["stringkey"] as! String == "stringvalue", "When plist is touched and icloud enabled, stringvalue should exist")
                        self.debug("TEST CDS: Saved, touched plist and loaded from Plist = \(localdict)")
                    } else {
                        XCTFail("When plist is touched and icloud disabled, there should never be a conflict")
                    }
                }
                exp.fulfill()
                }
            )
        }
        )
        waitForExpectationsWithTimeout(10.0, handler:nil)

    }

    
    private func removePlistFile(filename:String) {
        let paths = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true) as NSArray
        let documentsDirectory = paths[0] as! String
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

    private func touchPlistFile(filename:String, timestamp:UInt32) {
        let paths = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true) as NSArray
        let documentsDirectory = paths[0] as! String
        let plistpath = documentsDirectory.stringByAppendingPathComponent(filename)

        if let mutableDict = self.readDictionaryFromPlistFile(plistpath) {
            // Add save timestamp
            mutableDict["CDSTimestamp"] = NSNumber(unsignedInt: timestamp)
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
        println(msg)
    }

}
