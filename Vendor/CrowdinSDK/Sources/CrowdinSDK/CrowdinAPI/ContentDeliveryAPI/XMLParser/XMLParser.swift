//
//  XMLParser.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 01.04.2020.
//

import Foundation

public class SwiftXMLParser: NSObject {
    public let TextKey = "XMLParserTextKey"
    public let AttributesKey = "XMLParserAttributesKey"
    
    ///if true, attributes in xml will be transformed as a standalone dictionary
    ///For example: <sysmsg type="paymsg"></sysmsg> will be transformed to { "sysmsg" : { "_XMLAttributes" : { "type" : "paymsg" } } }
    ///if false, the result will be { "sysmsg": { "type": "paymsg"} }
    ///default is true
    public var attributesAsStandaloneDic = true

    var dicStack = [NSMutableDictionary]()
    var textInProcess = ""
    var xml = ""
}

// MARK: - Static factory method
public extension SwiftXMLParser {
    static func makeDic(data: Data) -> [String: Any]? {
        let parser = SwiftXMLParser()
        return parser.makeDic(data: data)
    }
    
    static func makeDic(string: String) -> [String: Any]? {
        if let data = string.data(using: .utf8) {
            let parser = SwiftXMLParser()
            return parser.makeDic(data: data)
        } else {
            return nil
        }
    }
    
    static func makeXML(dic: [String: Any]) -> String {
        let parser = SwiftXMLParser()
        return parser.makeXML(dic: dic)
    }
}

// MARK: - XML To Dic
public extension SwiftXMLParser {
    func makeDic(data: Data) -> [String: Any]? {
        
        //reset
        dicStack = [NSMutableDictionary]()
        textInProcess = ""
        dicStack.append(NSMutableDictionary())
        
        let parser = XMLParser(data: data)
        parser.delegate = self
        if parser.parse() == true {
            return dicStack.first as? [String: Any]
        } else {
            return nil
        }
    }
}

// MARK: - Dic To XML
public extension SwiftXMLParser {
    
    func makeXML(dic: [String: Any]) -> String {
        //reset
        xml = ""
        for (key,value) in dic {
            dfs(object: value, key: key)
        }
        return xml
    }
    
    private func dfs(object: Any, key: String) {
        if let array = object as? [Any] {
            for item in array {
                xml.append("<\(key)>")
                dfs(object: item, key: key)
                xml.append("</\(key)>")
            }
        } else if let dic = object as? [String: Any] {
            let tagKey = key
            
            //handle attributes first
            if let attributes = dic[AttributesKey] as? [String: String] {
                var attributeString = ""
                for (key,value) in attributes {
                    attributeString.append(" \(key) = \"\(value)\"")
                }
                xml.append("<\(tagKey)\(attributeString)>")
            } else {
                xml.append("<\(key)>")
            }
            
            for (key,value) in dic where key != AttributesKey {
                
                var isSimpleValue = true
                if value is [Any] || value is [String: Any] {
                    isSimpleValue = false
                }
                if isSimpleValue {
                    xml.append("<\(key)>")
                }
                dfs(object: value, key: key)
                if isSimpleValue {
                    xml.append("</\(key)>")
                }
            }
            
            xml.append("</\(key)>")
        } else {
            //simple value
            xml.append("<![CDATA[\(object)]]>")
        }
    }
}

// MARK: - XMLParserDelegate
extension SwiftXMLParser: XMLParserDelegate {
    public func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        
        //get parent
        guard let parentDic = dicStack.last else {
            fatalError("should not be nil")
        }
        
        // generate current
        let childDic = NSMutableDictionary()
        if attributesAsStandaloneDic {
            //transformed attributes as a standalone dictionary
            //it will help us transform it back to xml
            if attributeDict.count > 0 {
                childDic.setObject(attributeDict, forKey: AttributesKey as NSString)
            }
        } else {
            //attributes as key,value pair
            childDic.addEntries(from: attributeDict)
        }
        
        // if element name appears more than once, they need to be grouped as array
        if let existingValue = parentDic[elementName] {
            
            let array: NSMutableArray
            
            if let currentArray = existingValue as? NSMutableArray {
                array = currentArray
            } else {
                //If there is no array, create a new array, add the original value
                array = NSMutableArray()
                array.add(existingValue)
                //Replace the original value with an array
                parentDic[elementName] = array
            }
            //Add a new element to the array
            array.add(childDic)
            
        } else {
            //unique element, inserted into parent
            parentDic[elementName] = childDic
            dicStack[dicStack.endIndex - 1] = parentDic
        }
        
        //add to stack, track it
        dicStack.append(childDic)
    }
    
    public func parser(_ parser: XMLParser, foundCharacters string: String) {
        let append = string.trimmingCharacters(in: .whitespacesAndNewlines)
        textInProcess.append(append)
    }
    
    public func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        
        //Get the dic representing the current element
        guard let value = dicStack.last else {
            fatalError("should not be nil")
        }
        let parent = dicStack[dicStack.endIndex - 2]
        
        if textInProcess.count > 0 {
            if value.count > 0 {
                value[TextKey] = textInProcess
            } else {
                //If the current element has only value, no Attributes, like <list> 1 </ list>
                //Replace the dictionary directly with string
                if let array = parent[elementName] as? NSMutableArray {
                    //parent now looks like： {"list" : [1,{}]}
                    //Replace the empty dictionary with a string
                    array.removeLastObject()
                    array.add(textInProcess)
                } else {
                    //parent now looks like： {"list" : {} }
                    //Replace the empty dictionary with a string
                    parent[elementName] = textInProcess
                }
            }
        } else {
            //If value is empty and the element has no Attributes, delete the node
            if value.count == 0 {
                parent.removeObject(forKey: elementName)
            }
        }
        
        //reset
        textInProcess = ""
        //Finished processing the current element, pop
        dicStack.removeLast()
    }
    
    public func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        print(parseError)
    }
}
