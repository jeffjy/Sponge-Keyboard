//
//  AddOnInterface.swift
//  sponge
//
//  Created by Jeff on 9/29/25.
//  Copyright © 2025 Jeff. All rights reserved.
//

import Foundation
protocol Extension{
    init()
    
    func OnWordAdded(lastWord: String) -> String
    
    func OnSentenceCompleted(sentence: String) -> String

    func OnTextChanged(currentText: String) -> String
    
    var implementsAsync : Bool {get}
    
//    func OnWordAddedAsync(lastWord: String, completionFunction: CompletionFunction) -> Void
//    func OnWordAddedAsyncCompletion(result: String) -> String
//
    func ShouldTriggerAsync(sentence: String) -> Bool
    
    func OnSentenceCompletedAsync(sentence: String, placeholderId: Int, completionFunction: CompletionFunction) -> Void
    
//    var OnTextChangedAsyncCompletion : CompletionFunction {get}
//    func OnTextChangedAsync(currentText: String, completionFunction: CompletionFunction) -> Void
}

protocol CompletionFunction{
    
    func OnComplete(result: String, placeholderId: Int) -> Void
}

