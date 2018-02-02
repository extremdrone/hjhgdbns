//
//  LogPrint.swift
//  exampleWindow
//
//  Created by Remi Robert on 17/01/2017.
//  Copyright © 2017 Remi Robert. All rights reserved.
//

import Foundation

//MARK: - ***** Usage of DebugManLog *****

/// file: logs file
/// function: logs function
/// line: logs line
/// message: logs content
/// color: logs color, default is white
public func DebugManLog<T>(_ file: String = #file,
                           _ function: String = #function,
                           _ line: Int = #line,
                           _ message: T,
                           _ color: UIColor? = nil)
{
    Logger.shared.handleLog(file: file, function: function, line: line, message: message, color: color)
//    Swift.print(message)
}

//MARK: -
public class Logger {
    
    static let shared = Logger()
    
    fileprivate func parseFileInfo(file: String?, function: String?, line: Int?) -> String? {
        guard let file = file, let function = function, let line = line, let fileName = file.components(separatedBy: "/").last else {return nil}
        
        return "\(fileName)[\(line)]\(function):\n"
    }

    fileprivate func handleLog(file: String?, function: String?, line: Int?, message: Any..., color: UIColor?) {
        let fileInfo = parseFileInfo(file: file, function: function, line: line)
        let stringContent = message.reduce("") { result, next -> String in
            return "\(result)\(result.count > 0 ? " " : "")\(next)"
        }
        
        
        //liman
        DispatchQueue.global().async {
            //子线程
            let newLog = Log(content: stringContent, color: color, fileInfo: fileInfo)
            let format = LoggerFormat.format(newLog)
            Swift.print(format.str)
            StoreManager.shared.addLog(newLog)
            
            DispatchQueue.main.async {
                //主线程
                NotificationCenter.default.post(name: NSNotification.Name("refreshLogs_DebugMan"), object: nil, userInfo: nil)
            }
        }
    }
}
