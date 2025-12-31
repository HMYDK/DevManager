import Foundation

func compareVersionDescending(_ lhs: String, _ rhs: String) -> Bool {
    let l = versionKey(lhs)
    let r = versionKey(rhs)
    let maxCount = max(l.count, r.count)
    
    for i in 0..<maxCount {
        let li = i < l.count ? l[i] : 0
        let ri = i < r.count ? r[i] : 0
        if li != ri { return li > ri }
    }
    
    return lhs > rhs
}

private func versionKey(_ version: String) -> [Int] {
    var result: [Int] = []
    var current = ""
    
    for ch in version {
        if ch.isNumber {
            current.append(ch)
        } else {
            if !current.isEmpty {
                result.append(Int(current) ?? 0)
                current.removeAll(keepingCapacity: true)
            }
        }
    }
    
    if !current.isEmpty {
        result.append(Int(current) ?? 0)
    }
    
    return result
}

