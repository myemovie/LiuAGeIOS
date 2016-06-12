//
//  JFNewsDALManager.swift
//  LiuAGeIOS
//
//  Created by zhoujianfeng on 16/6/12.
//  Copyright © 2016年 六阿哥. All rights reserved.
//

import UIKit
import SwiftyJSON

/// DAL: data access layer 数据访问层
class JFNewsDALManager: NSObject {
    
    static let shareManager = JFNewsDALManager()
    
    /**
     清除缓存
     
     - parameter classid: 要清除的分类id
     */
    func cleanCache(classid: Int) {
        var sql = ""
        if classid == 0 {
            sql = "DELETE FROM \(NEWS_LIST_HOME_TOP); DELETE FROM \(NEWS_LIST_HOME_LIST);"
        } else {
            sql = "DELETE FROM \(NEWS_LIST_OTHER_TOP) WHERE classid=\"\(classid)\"; DELETE FROM \(NEWS_LIST_OTHER_LIST) WHERE classid=\"\(classid)\";"
        }
        
        JFSQLiteManager.shareManager.dbQueue.inDatabase { (db) in
            
            if db.executeStatements(sql) {
                print("清空表成功 classid = \(classid)")
            } else {
                print("清空表失败 classid = \(classid)")
            }
        }
    }
    
    /**
     加载资讯数据
     
     - parameter classid:   资讯分类id
     - parameter pageIndex: 加载分页
     - parameter type:      1为资讯列表 2为资讯幻灯片
     - parameter finished:  数据回调
     */
    func loadNewsList(classid: Int, pageIndex: Int, type: Int, finished: (result: JSON?, error: NSError?) -> ()) {
        
        // 先从本地加载数据
        loadNewsListFromLocation(classid, pageIndex: pageIndex, type: type) { (success, result, error) in
            
            // 本地有数据直接返回
            if success == true {
                finished(result: result, error: nil)
                print("加载了本地数据 \(result)")
                return
            }
            
            // 本地没有数据才从网络中加载
            JFNetworkTool.shareNetworkTool.loadNewsListFromNetwork(classid, pageIndex: pageIndex, type: type) { (success, result, error) in
                
                if success == false || error != nil || result == nil {
                    finished(result: nil, error: error)
                    return
                }
                
                // 缓存数据到本地
                self.saveNewsListData(classid, data: result!, type: type)
                finished(result: result, error: nil)
                print("加载了远程数据 \(result)")
            }
        }
        
    }
    
    /**
     从本地加载资讯数据
     
     - parameter classid:   资讯分类id
     - parameter pageIndex: 加载分页
     - parameter finished:  数据回调
     */
    private func loadNewsListFromLocation(classid: Int, pageIndex: Int, type: Int, finished: NetworkFinished) {
        
        var sql = ""
        if type == 1 {
            // 计算分页
            let pre_count = (pageIndex - 1) * 20
            let oneCount = 20
            
            if classid == 0 {
                sql = "SELECT * FROM \(NEWS_LIST_HOME_LIST) ORDER BY id ASC LIMIT \(pre_count), \(oneCount)"
            } else {
                sql = "SELECT * FROM \(NEWS_LIST_OTHER_LIST) WHERE classid=\"\(classid)\" ORDER BY id ASC LIMIT \(pre_count), \(oneCount)"
            }
        } else {
            if classid == 0 {
                sql = "SELECT * FROM \(NEWS_LIST_HOME_TOP) ORDER BY id ASC LIMIT 0, 3"
            } else {
                sql = "SELECT * FROM \(NEWS_LIST_OTHER_TOP) WHERE classid=\"\(classid)\" ORDER BY id ASC LIMIT 0, 3"
            }
        }
        
        JFSQLiteManager.shareManager.dbQueue.inDatabase { (db) in
            
            var array = [JSON]()
            
            let result = try! db.executeQuery(sql, values: nil)
            while result.next() {
                let newsJson = result.stringForColumn("news")
                let json = JSON.parse(newsJson)
                array.append(json)
            }
            
            if array.count > 0 {
                finished(success: true, result: JSON(array), error: nil)
            } else {
                finished(success: false, result: nil, error: nil)
            }
            
        }
        
    }
    
    /**
     缓存新闻列表数据到本地
     
     - parameter data: json数据
     */
    private func saveNewsListData(saveClassid: Int, data: JSON, type: Int) {
        
        var sql = ""
        if type == 1 {
            if saveClassid == 0 {
                sql = "INSERT INTO \(NEWS_LIST_HOME_LIST) (classid, news) VALUES (?, ?)"
            } else {
                sql = "INSERT INTO \(NEWS_LIST_OTHER_LIST) (classid, news) VALUES (?, ?)"
            }
        } else {
            if saveClassid == 0 {
                sql = "INSERT INTO \(NEWS_LIST_HOME_TOP) (classid, news) VALUES (?, ?)"
            } else {
                sql = "INSERT INTO \(NEWS_LIST_OTHER_TOP) (classid, news) VALUES (?, ?)"
            }
        }
        
        JFSQLiteManager.shareManager.dbQueue.inTransaction { (db, rollback) in
            
            guard let array = data.arrayObject as! [[String : AnyObject]]? else {
                return
            }
            
            // 每一个字典是一条资讯
            for dict in array {
                
                // 资讯分类id
                let classid = dict["classid"] as! String
                
                // 单条资讯json数据
                let newsData = try! NSJSONSerialization.dataWithJSONObject(dict, options: NSJSONWritingOptions(rawValue: 0))
                let newsJson = String(data: newsData, encoding: NSUTF8StringEncoding)!
                
                if db.executeUpdate(sql, withArgumentsInArray: [classid, newsJson]) {
                    print("缓存数据成功 - \(classid)")
                } else {
                    print("缓存数据失败 - \(classid)")
                    rollback.memory = true
                    break
                }
            }
            
        }
        
    }
}
