//
//  Handlers.swift
//  Swifter
//  Copyright (c) 2014 Damian Kołakowski. All rights reserved.
//

import Foundation

public class HttpHandlers {
    
    private static let rangeExpression = try! NSRegularExpression(pattern: "bytes=(\\d*)-(\\d*)", options: .CaseInsensitive)
    
    private static let cache = NSCache()
    
    public class func directory(dir: String) -> ( HttpRequest -> HttpResponse ) {
        return { request in
            
            guard let localPath = request.params.first else {
                return HttpResponse.NotFound
            }
            
            let filesPath = dir + "/" + localPath.1
            
            let cachedBody = cache.objectForKey(filesPath) as? NSData
            
            guard let fileBody = cachedBody ?? NSData(contentsOfFile: filesPath) else {
                return HttpResponse.NotFound
            }
            
            if cachedBody == nil {
                cache.setObject(fileBody, forKey: filesPath)
            }
            
            if let rangeHeader = request.headers["range"] {
                
                guard let match = rangeExpression.matchesInString(rangeHeader, options: .Anchored, range: NSRange(location: 0, length: rangeHeader.characters.count)).first where match.numberOfRanges == 3 else {
                    return HttpResponse.BadRequest
                }
                
                let startStr = (rangeHeader as NSString).substringWithRange(match.rangeAtIndex(1))
                let endStr = (rangeHeader as NSString).substringWithRange(match.rangeAtIndex(2))
                
                guard let start = Int(startStr), end = Int(endStr) else {
                    var array = [UInt8](count: fileBody.length, repeatedValue: 0)
                    fileBody.getBytes(&array, length: fileBody.length)
                    return HttpResponse.RAW(200, "OK", nil, array)
                }
                
                let length = end - start
                let range = NSRange(location: start, length: length + 1)
                
                guard range.location + range.length <= fileBody.length else {
                    return HttpResponse.RAW(416, "Requested range not satisfiable", nil, nil)
                }
                
                let subData = fileBody.subdataWithRange(range)
                
                let headers = [
                    "Content-Range" : "bytes \(startStr)-\(endStr)/\(fileBody.length)"
                ]
                
                var array = [UInt8](count: subData.length, repeatedValue: 0)
                subData.getBytes(&array, length: subData.length)
                return HttpResponse.RAW(206, "Partial Content", headers, array)
                
            }
            else {
                var array = [UInt8](count: fileBody.length, repeatedValue: 0)
                fileBody.getBytes(&array, length: fileBody.length)
                return HttpResponse.RAW(200, "OK", nil, array)
            }
            
        }
    }
    
    public class func directoryBrowser(dir: String) -> ( HttpRequest -> HttpResponse ) {
        return { r in
            if let (_, value) = r.params.first {
                let filePath = dir + "/" + value
                let fileManager = NSFileManager.defaultManager()
                var isDir: ObjCBool = false;
                if ( fileManager.fileExistsAtPath(filePath, isDirectory: &isDir) ) {
                    if ( isDir ) {
                        do {
                            let files = try fileManager.contentsOfDirectoryAtPath(filePath)
                            var response = "<h3>\(filePath)</h3></br><table>"
                            response += files.map({ "<tr><td><a href=\"\(r.url)/\($0)\">\($0)</a></td></tr>"}).joinWithSeparator("")
                            response += "</table>"
                            return HttpResponse.OK(.Html(response))
                        } catch  {
                            return HttpResponse.NotFound
                        }
                    } else {
                        if let fileBody = NSData(contentsOfFile: filePath) {
                            var array = [UInt8](count: fileBody.length, repeatedValue: 0)
                            fileBody.getBytes(&array, length: fileBody.length)
                            return HttpResponse.RAW(200, "OK", nil, array)
                        }
                    }
                }
            }
            return HttpResponse.NotFound
        }
    }
}
