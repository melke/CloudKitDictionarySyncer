//
// Created by Mats Melke on 03/02/15.
// Copyright (c) 2015 Baresi. All rights reserved.
//

import Foundation
import CloudKit

enum DictionaryOrigin {
    case CloudKit
    case Plist
}

enum LoadResult {
    case Dict(NSMutableDictionary)
    case Conflict(localdict : NSMutableDictionary?, clouddict : NSMutableDictionary?, latest: DictionaryOrigin)
}

class CloudKitDictionarySyncer {

    let dictname:String
    let plistpath:String
    let container : CKContainer
    var debugflag:Bool
    var privateDB : CKDatabase?
    var iCloudEnabled:Bool = false
    var loaded:Bool = false

    init(dictname:String, debug:Bool = false) {
        self.dictname = dictname
        self.debugflag = debug
        let paths = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true) as NSArray
        let documentsDirectory = paths[0] as String
        self.plistpath = documentsDirectory.stringByAppendingPathComponent("\(dictname).plist")
        self.container = CKContainer.defaultContainer()
    }

// MARK: - Public methods

    func loadDictionary(#onComplete: (LoadResult) -> ()) {

        load {

            if !self.iCloudEnabled {
                if let mutableDict = self.readDictionaryFromPlistFile() {
                    onComplete(LoadResult.Dict(mutableDict))
                } else {
                    onComplete(LoadResult.Dict(NSMutableDictionary()))
                }
                
            } else {
                // try to get dict from icloud
                self.fetchDictionaryFromiCloud(onComplete: {
                    _,dictFromiCloud in

                    var icloudTimestamp:NSTimeInterval = 0.0
                    if dictFromiCloud != nil {
                        if let ts = dictFromiCloud!["CDSTimestamp"] as? NSTimeInterval {
                            icloudTimestamp = ts
                        }
                    }

                    var plistTimestamp:NSTimeInterval = 0.0
                    var dictFromFile:NSMutableDictionary? = self.readDictionaryFromPlistFile()
                    if dictFromFile != nil {
                        if let ts = dictFromFile!["CDSTimestamp"] as? NSTimeInterval {
                            plistTimestamp = ts
                        }
                    }
                    self.debug("icloudTimestamp = \(icloudTimestamp), plistTimestamp = \(plistTimestamp)")
                    if icloudTimestamp == plistTimestamp {
                        if (icloudTimestamp > 0.0) {
                            // Dicts are identical, return dictFromiCloud
                            onComplete(LoadResult.Dict(dictFromiCloud!))
                        } else {
                            // Both dicts are empty, return empty dict
                            onComplete(LoadResult.Dict(NSMutableDictionary()))
                        }
                    } else {
                        // The dictionaries are different, return conflict type
                        onComplete(LoadResult.Conflict(localdict: dictFromFile, clouddict: dictFromiCloud, latest: icloudTimestamp > plistTimestamp ? .CloudKit : .Plist))
                    }
                })
            }
        }
    }

    func saveDictionary(dictionary:NSDictionary,  onComplete: (String) -> ()) {

        load {
            var mutableDict:NSMutableDictionary = dictionary.mutableCopy() as NSMutableDictionary

            // Add save timestamp
            let timestamp = NSDate().timeIntervalSince1970
            mutableDict["CDSTimestamp"] = timestamp
            mutableDict["CDSOrigin"] = "plistfile"

            // Save to plist
            mutableDict.writeToFile(self.plistpath, atomically: false)
            self.debug("CDS: Saved to plist file")

            // Save to iCloud, if available
            if self.iCloudEnabled {
                mutableDict["CDSOrigin"] = "iCloud"
                self.saveDictionaryToiCloud(mutableDict, onComplete: onComplete)
            } else {
                onComplete("CDS: saveDictionary complete, only saved to plist file")
            }
        }

    }

// MARK: - Private util methods

    private func debug(msg:String) {
        if !self.debugflag {
            return
        }
        println(msg)
    }

    private func load(#onComplete: () -> ()) {
        if self.loaded {
            onComplete()
            return
        }
        self.debug("CDS: Plist path = \(self.plistpath)\n")
        self.container.accountStatusWithCompletionHandler({
            accountStatus, error in
            if accountStatus == CKAccountStatus.Available {
                self.privateDB = self.container.privateCloudDatabase
                self.iCloudEnabled = true
            }
            self.loaded = true
            self.debug("CDS: iCloudEnabled = \(self.iCloudEnabled)")
            onComplete()
        })

    }

// MARK: - Private Plist methods

    private func readDictionaryFromPlistFile() -> NSMutableDictionary? {
        let fileManager = NSFileManager.defaultManager()

        //check if file exists
        if(!fileManager.fileExistsAtPath(self.plistpath)) {
            self.debug("CDS: Warning: plist file not found \(self.dictname).plist")
            return nil
        }

        if let dict = NSMutableDictionary(contentsOfFile: self.plistpath) {
            self.debug("CDS: Loaded from \(self.dictname).plist")
            return dict
        } else {
            self.debug("CDS: WARNING: Couldn't create dictionary from plistfile")
            return nil
        }

    }

// MARK: - Private CloudKit methods

    private func saveDictionaryToiCloud(dict: NSDictionary, onComplete: (String) -> ()) {
        fetchDictionaryFromiCloud(onComplete: {
            fetchedRecord,_ in
            var record:CKRecord
            if fetchedRecord != nil {
                record = fetchedRecord!
            } else {
                record = CKRecord(recordType: "Plists", recordID: CKRecordID(recordName: self.dictname))
            }
            var plisterror:NSError?
            if let data:NSData = NSPropertyListSerialization.dataWithPropertyList(dict, format:NSPropertyListFormat.XMLFormat_v1_0, options:0, error:&plisterror) {
               if let datastring: String = NSString(data:data, encoding:NSUTF8StringEncoding) {
                   record.setValue(self.dictname, forKey: "dictname")
                   record.setValue(datastring, forKey: "plistxml")
               } else {
                   onComplete("CDS: Error saving in cloudkit. Could not create string from nsdata")
               }
            } else {
                onComplete("CDS: Error saving in cloudkit. Could not serialize dict into nsdata")
            }
            if plisterror != nil {
                onComplete("CDS: Error saving in cloudkit. Searialize error: \(plisterror!)")
            }

            self.privateDB!.saveRecord(record, completionHandler: { (record, error) -> () in
                if error != nil {
                    onComplete("CDS: Error saving in cloudkit \(error!)")
                } else {
                    onComplete("CDS: Saved in cloudkit")
                }
            })
        })
    }

    private func fetchDictionaryFromiCloud(#onComplete: (CKRecord?, NSMutableDictionary?) -> ()) {
        let recordId = CKRecordID(recordName: self.dictname)
        self.privateDB!.fetchRecordWithID(recordId, completionHandler: {
            (record:CKRecord!, error:NSError!) -> () in
            if error != nil {
                self.debug("CDS: Status fetching cloudkit record \(error)")
                switch error.code {
                case CKErrorCode.UnknownItem.rawValue:
                    self.debug("CDS: Record did not exist, CK throws error for this, but is normal for new records, ignore and move on")
                     onComplete(nil, nil)
                default:
                    self.debug("CDS: Other error, CloudKit is not working, which happens occasionally. Turn off iCloud during the entire session")
                    self.iCloudEnabled = false
                    onComplete(nil, nil)
                    
                }
               
            } else {
                if let obj:AnyObject = record.objectForKey("plistxml") {
                    var dict:NSMutableDictionary?
                    if let str = obj as? String {
                       if let data:NSData = str.dataUsingEncoding(NSUTF8StringEncoding) {
                           var plisterror:NSError?
                           dict = NSPropertyListSerialization.propertyListWithData(data,
                                   options:Int(NSPropertyListMutabilityOptions.MutableContainersAndLeaves.rawValue),
                                   format: nil, error: &plisterror) as? NSMutableDictionary
                           if plisterror != nil {
                               self.debug("CDS: Error serializing cloudkit xml into dict. Error: \(plisterror)")
                           }
                       }
                    }
                    if dict != nil {
                        self.debug("CDS: Success creating dict from icloud xml")
                        onComplete(record, dict)
                    } else {
                        self.debug("CDS: could not create dict from icloud xml")
                        onComplete(nil,nil)
                    }

                } else {
                    self.debug("CDS: plistxml not found in icloud record")
                    onComplete(nil,nil)
                }
            }
        })
    }
}