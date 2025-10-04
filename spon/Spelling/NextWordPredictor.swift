//
//  sponge
//
//  Created by Jeff on 9/29/25.
//  Copyright © 2025 Jeff. All rights reserved.
//

import Foundation
class NextWordPredictor{
    
    var knownWords = [String: NextWord](minimumCapacity: 1)
    
    func insertWord(word: NextWord){
        self.knownWords[word.w] = word;
    }
}

