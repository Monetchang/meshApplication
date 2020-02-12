//
//  RangeObject+String.swift
//  nRFSingleTon
//
//  Created by wuzhengbin on 2019/12/23.
//  Copyright © 2019 wuzhengbin. All rights reserved.
//

import Foundation
import nRFMeshProvision

extension RangeObject {
    
    func asString() -> String {
        return "\(lowerBound.asString()) - \(upperBound.asString())"
    }
    
}

extension Array where Element == RangeObject {
    
    func asString() -> String {
        if count == 1 {
            return self[0].asString()
        }
        return "\(count) ranges"
    }
    
}

extension ClosedRange where Bound == UInt16 {
    
    func asString() -> String {
        return "\(lowerBound.asString()) - \(upperBound.asString())"
    }
    
}
