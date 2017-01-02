#!/usr/bin/env xcrun swift

// 该脚本用来检测iOS项目中是否有存在未被使用图片

import Foundation


// 判断是否为文件夹
func isDirectory(atPath: String) -> Bool {
    var isDirectory: ObjCBool = ObjCBool(false)
    FileManager.default.fileExists(atPath: atPath, isDirectory: &isDirectory)
    
    return isDirectory.boolValue
}

func getPicture(path: String) -> String? {
    let elementStr: String = path
    let arr:[String] = elementStr.components(separatedBy: "/")
    
    if let lastStr = arr.last {
        return lastStr
    }
    
    return nil
}


// 遍历所有文件
func enumAllFiles(filePath: String, fileManager: FileManager, handle: (_ element: String) -> Void) {
    let enumerator: FileManager.DirectoryEnumerator = fileManager.enumerator(atPath: filePath)!
    
    while let element = enumerator.nextObject() as? String {
        let absoluteFilePath = filePath + "/" + element
        
        guard fileManager.isReadableFile(atPath: absoluteFilePath) else {
            continue
        }
        handle(absoluteFilePath);
    }
}

// 将注释代码替换成""
func replaceComment(content: String, template:String) -> String {
    var pattern = "//.*"
    var regular = try! NSRegularExpression(pattern: pattern, options:.caseInsensitive)
    let mutableStr = NSMutableString.init(string: content)
    regular.replaceMatches(in: mutableStr, options: .reportCompletion, range: NSMakeRange(0, content.characters.count), withTemplate: "")
    
    pattern = "/\\*[\\s\\S]*\\*/"
    regular = try! NSRegularExpression(pattern: pattern, options:.caseInsensitive)
    regular.replaceMatches(in: mutableStr, options: .reportCompletion, range: NSMakeRange(0, mutableStr.length), withTemplate: "")
    
    return mutableStr.description;
}

func match(pattern: String, content: String) -> Bool {
    let regular = try! NSRegularExpression(pattern: pattern, options:.caseInsensitive)
    let results = regular.matches(in: content, options: .reportProgress , range: NSMakeRange(0, content.characters.count))
    
    if results.count > 0 {
        return true
    }
    return false
}

func isUsedJpg(jpgName: String, fileContent: String) -> Bool {
    let pattern = "\"" + jpgName + "\""
    return fileContent.contains(pattern)
}


func isUsedPng(pngName: String, fileContent: String) -> Bool {
    let pattern = "\"" + pngName + ""
    return fileContent.contains(pattern)
}

func fileterNum(pictureName: String) -> String {
    let pattern = "[A-Za-z_]+(?=\\d{0,2})"
    let regular = try! NSRegularExpression(pattern: pattern, options:.caseInsensitive)
    let results = regular.matches(in: pictureName, options: .reportProgress , range: NSMakeRange(0, pictureName.characters.count))
    if results.count == 1 {
        let result = results.first!
        return (pictureName as NSString).substring(with: result.range)
    }
    
    return pictureName
}

// Swift3.0用CommandLine获取用户输入命令
// argc是参数个数
guard CommandLine.argc == 2 else {
    print("Argument cout error: it need a file path for argument!")
    exit(0)
}


// arguments是参数
let argv = CommandLine.arguments
let filePath = argv[1]

let fileManager = FileManager.default

var isDirectory: ObjCBool = ObjCBool(false)
guard fileManager.fileExists(atPath: filePath, isDirectory: &isDirectory) else {
    print("The '\(filePath)' file path is not exit!")
    exit(0)
}

guard isDirectory.boolValue == true else {
    print("The '\(filePath)' is not a directory!")
    exit(0)
}

guard fileManager.isReadableFile(atPath: filePath) else {
    print("The '\(filePath)' file path is not readable!")
    exit(0)
}

var jpgList: Array<String> = Array<String>()
var pngList: Array<String> = Array<String>()

var files: Set<String> = Set<String>()
// 遍历所有文件，添加jpg和png到jpgList，pngList
enumAllFiles(filePath: filePath, fileManager: fileManager) { (absoluteFilePath) in
    // Pods文件夹里面的图片先忽略
    if absoluteFilePath.contains("/Pods/") {
        return
    }
    
    if absoluteFilePath.contains("/watchkitapp/") {
        return
    }
    
    if absoluteFilePath.contains("/watchkitapp Extension/") {
        return
    }
    
    if absoluteFilePath.contains("/FlyingShark/") {
        return
    }
    
    if absoluteFilePath.contains("/Autobuild/") {
        return
    }

    // Images.xcassets的图片先忽略
    if absoluteFilePath.contains("/Images.xcassets/") || absoluteFilePath.contains("/Assets.xcassets/") {
        if isDirectory(atPath: absoluteFilePath) {
            if let dirName = getPicture(path: absoluteFilePath) {
                
                var split = "."
                if !dirName.contains(split) {
                    return
                }
                
                let tmpArr = dirName.components(separatedBy: split)
                if  tmpArr.count > 0  {
                    var tmpPngName = tmpArr.first!
                    tmpPngName = fileterNum(pictureName: tmpPngName)
                    if !pngList.contains(tmpPngName) {
                        pngList.append(tmpPngName)
                    }
                }
                
            }
        } else {
            return
        }
    }

    if absoluteFilePath.hasSuffix(".jpg") {
        
        if let jpgStr = getPicture(path: absoluteFilePath) {
            jpgList.append(jpgStr)
        }
    }
    
    if absoluteFilePath.hasSuffix(".png") {
        if let pngStr = getPicture(path: absoluteFilePath) {
            
            var split = ""
            if pngStr.contains("@") {
                split = "@"
            } else {
                split = "."
            }
            
            let tmpArr = pngStr.components(separatedBy: split)
            if  tmpArr.count > 0  {
                var tmpPngName = tmpArr.first!
                tmpPngName = fileterNum(pictureName: tmpPngName)
                if !pngList.contains(tmpPngName) {
                    pngList.append(tmpPngName)
                }
            }
        }
    }
    
    if absoluteFilePath.hasSuffix(".m") || absoluteFilePath.hasSuffix(".storyboard") || absoluteFilePath.hasSuffix(".xib") {
        files.insert(absoluteFilePath)
    }
}

// 检测jpg文件是否被使用
var usedJpgList : Set<String> = Set<String>()
var usedPngList: Set<String> = Set<String>()

for absoluteFilePath in files {
    
    if fileManager.isReadableFile(atPath: absoluteFilePath) {
        let url = URL(fileURLWithPath: absoluteFilePath)
        var fileContent = try! String(contentsOf: url, encoding: .utf8)
        if absoluteFilePath.hasSuffix(".m") {
            fileContent = replaceComment(content: fileContent, template: "")
        }
        
        for jpg in jpgList {
            if isUsedJpg(jpgName: jpg, fileContent: fileContent) {
                usedJpgList.insert(jpg)
            }
        }
        
        for jpg in usedJpgList {
            if let i = jpgList.index(of: jpg) {
                jpgList.remove(at: i)
            }
        }
        
        for png in pngList {
            if isUsedPng(pngName: png, fileContent: fileContent) {
                usedPngList.insert(png)
            }
        }
        
        for png in usedPngList {
            if let i = pngList.index(of: png) {
                pngList.remove(at: i)
            }
        }
    }
}

// 打印未使用到的jpg
for jpg in jpgList {
    print(jpg)
}

// 打印未使用到的png
for png in pngList {
    print(png)
}
