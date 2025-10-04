//
//  sponge
//
//  Created by Jeff on 9/29/25.
//  Copyright © 2025 Jeff. All rights reserved.
//

import Foundation
struct NextWord : Codable{
    
    let w: String
    let p: [Prediction]
}

public struct Prediction : Codable{
    public let w: String
    let c: Int
}

