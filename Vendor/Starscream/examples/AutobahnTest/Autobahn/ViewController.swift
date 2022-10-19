//
//  ViewController.swift
//  Autobahn
//
//  Created by Dalton Cherry on 7/24/15.
//  Copyright (c) 2015 vluxe. All rights reserved.
//

import UIKit
import Starscream

class ViewController: UIViewController {
    
    let host = "localhost:9001"
    var socketArray = [WebSocket]()
    var caseCount = 300 //starting cases
    override func viewDidLoad() {
        super.viewDidLoad()
        getCaseCount()
        //getTestInfo(1)
        //runTest(304)
    }
    
    func removeSocket(_ s: WebSocket?) {
        guard let s = s else {return}
        socketArray = socketArray.filter{$0 !== s}
    }
    
    func getCaseCount() {
        let req = URLRequest(url: URL(string: "ws://\(host)/getCaseCount")!)
        let s = WebSocket(request: req)
        socketArray.append(s)
        s.onEvent = { [weak self] event in
            switch event {
            case .text(let string):
                if let c = Int(string) {
                    print("number of cases is: \(c)")
                    self?.caseCount = c
                }
            case .disconnected(_, _):
                self?.runTest(1)
                self?.removeSocket(s)
            default:
                break
            }
        }
        s.connect()
    }
    
    func getTestInfo(_ caseNum: Int) {
        let s = createSocket("getCaseInfo",caseNum)
        socketArray.append(s)
//        s.onText = { (text: String) in
//            let data = text.dataUsingEncoding(NSUTF8StringEncoding)
//            do {
//                let resp: AnyObject? = try NSJSONSerialization.JSONObjectWithData(data!,
//                    options: NSJSONReadingOptions())
//                if let dict = resp as? Dictionary<String,String> {
//                    let num = dict["id"]
//                    let summary = dict["description"]
//                    if let n = num, let sum = summary {
//                        print("running case:\(caseNum) id:\(n) summary: \(sum)")
//                    }
//                }
//            } catch {
//                print("error parsing the json")
//            }

//        }
        var once = false
        s.onEvent = { [weak self] event in
            switch event {
            case .disconnected(_, _), .error(_):
                if !once {
                    once = true
                    self?.runTest(caseNum)
                }
                self?.removeSocket(s)
            default:
                break
            }
        }
        s.connect()
    }
    
    func runTest(_ caseNum: Int) {
        let s = createSocket("runCase",caseNum)
        self.socketArray.append(s)
        
        var once = false
        s.onEvent = { [weak self, weak s] event in
            switch event {
            case .disconnected(_, _), .error(_):
                if !once {
                    once = true
                    print("case:\(caseNum) finished")
                    //self?.verifyTest(caseNum) //disabled since it slows down the tests
                    let nextCase = caseNum+1
                    if nextCase <= (self?.caseCount)! {
                        self?.runTest(nextCase)
                        //self?.getTestInfo(nextCase) //disabled since it slows down the tests
                    } else {
                        self?.finishReports()
                    }
                    self?.removeSocket(s)
                }
                self?.removeSocket(s)
            case .text(let string):
               s?.write(string: string)
            case .binary(let data):
               s?.write(data: data)
//            case .error(let error):
//                print("got an error: \(error)")
            default:
                break
            }
        }
        s.connect()
    }
    
//    func verifyTest(_ caseNum: Int) {
//        let s = createSocket("getCaseStatus",caseNum)
//        self.socketArray.append(s)
//        s.onText = { (text: String) in
//            let data = text.data(using: String.Encoding.utf8)
//            do {
//                let resp: Any? = try JSONSerialization.jsonObject(with: data!,
//                    options: JSONSerialization.ReadingOptions())
//                if let dict = resp as? Dictionary<String,String> {
//                    if let status = dict["behavior"] {
//                        if status == "OK" {
//                            print("SUCCESS: \(caseNum)")
//                            return
//                        }
//                    }
//                    print("FAILURE: \(caseNum)")
//                }
//            } catch {
//               print("error parsing the json")
//            }
//        }
//        var once = false
//        s.onDisconnect = { [weak self, weak s]  (error: Error?) in
//            if !once {
//                once = true
//                let nextCase = caseNum+1
//                print("next test is: \(nextCase)")
//                if nextCase <= (self?.caseCount)! {
//                    self?.getTestInfo(nextCase)
//                } else {
//                    self?.finishReports()
//                }
//            }
//            self?.removeSocket(s)
//        }
//        s.connect()
//    }
    
    func finishReports() {
        let s = createSocket("updateReports",0)
        self.socketArray.append(s)
        s.onEvent = { [weak self, weak s] event in
            switch event {
            case .disconnected(_, _):
                print("finished all the tests!")
                self?.removeSocket(s)
            default:
                break
            }
        }
        s.connect()
    }
    
    func createSocket(_ cmd: String, _ caseNum: Int) -> WebSocket {
        let req = URLRequest(url: URL(string: "ws://\(host)\(buildPath(cmd,caseNum))")!)
        //return WebSocket(request: req, compressionHandler: WSCompression())
        return WebSocket(request: req)
    }
    
    func buildPath(_ cmd: String, _ caseNum: Int) -> String {
        return "/\(cmd)?case=\(caseNum)&agent=Starscream"
    }
}

