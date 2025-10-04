//
//  sponge
//
//  Created by Jeff on 9/29/25.
//  Copyright © 2025 Jeff. All rights reserved.
//

import Foundation

public protocol Searchable: Hashable {
    var keywords: [String] { get }
}

public struct TrieNode<T: Searchable> {
    let items: Set<T>
    let children: [Character: TrieNode<T>]
    
    init(items: Set<T> = [], children: [Character: TrieNode<T>] = [:]) {
        self.items = items
        self.children = children
    }
    
    // Pure function to insert an item with full token array
    func inserting(_ item: T, for tokens: [Character], at index: Int = 0) -> TrieNode<T> {
        guard index < tokens.count  else {
            return TrieNode(items: items.union([item]), children: children)
        }
        
        let currentToken = tokens[index]
        let existingChild = children[currentToken] ?? TrieNode<T>()
        let updatedChild = existingChild.inserting(item, for: tokens, at: index + 1)
        
        var newChildren = children
        newChildren[currentToken] = updatedChild
        
        return TrieNode(items: items, children: newChildren)
    }
    
    // Pure function to search for items by prefix
    func searching(tokens: [Character], at index: Int = 0) -> Set<T> {
        guard index < tokens.count else {
            return allItems
        }
        
        let currentToken = tokens[index]
        return children[currentToken]?.searching(tokens: tokens, at: index + 1) ?? []
    }
    
    // Computed property to get all items in this subtree
    var allItems: Set<T> {
        children.values.reduce(items) { result, child in
            result.union(child.allItems)
        }
    }
}

open class AutoComplete<T: Searchable> {
    private let root: TrieNode<T>
    
    public init(items: [T] = []) {
        func tokenize(_ string: String) -> [Character] {
            return Array(string.lowercased())
        }
        
        // Build trie by inserting full keywords (not flatMap which creates individual chars)
        let initialRoot = items.reduce(TrieNode<T>()) { trie, item in
            item.keywords
                .map(tokenize) // Map each keyword to its character array
                .reduce(trie) { currentTrie, tokens in
                    currentTrie.inserting(item, for: tokens)
                }
        }
        self.root = initialRoot
    }
    
    public func inserting(_ item: T) -> AutoComplete<T> {
        let newRoot = item.keywords
            .map(tokenize) // Map instead of flatMap to preserve full keywords
            .reduce(root) { currentRoot, tokens in
                currentRoot.inserting(item, for: tokens)
            }
        
        return AutoComplete(root: newRoot)
    }
    
    public func inserting(_ items: [T]) -> AutoComplete<T> {
        items.reduce(self) { autocomplete, item in
            autocomplete.inserting(item)
        }
    }
    
    // Prefix-only, case-insensitive search
    public func search(_ query: String) -> [T] {
        let words = query.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        
        guard let lastWord = words.last else { return [] }
        
        // Search by prefix in the trie
        let trieResults = root.searching(tokens: tokenize(lastWord))
        
        // Filter to only include items where at least one keyword starts with the typed prefix
        let prefixFiltered = trieResults.filter { item in
            let lowercasedWord = lastWord.lowercased()
            return item.keywords.contains { keyword in
                keyword.lowercased().hasPrefix(lowercasedWord)
            }
        }
        
        // Sort by relevance (shorter keywords first, then alphabetically)
        return prefixFiltered.sorted { lhs, rhs in
            let lhsMinLength = lhs.keywords.map { $0.count }.min() ?? Int.max
            let rhsMinLength = rhs.keywords.map { $0.count }.min() ?? Int.max
            
            if lhsMinLength != rhsMinLength {
                return lhsMinLength < rhsMinLength
            }
            
            // If same length, sort alphabetically by first keyword
            let lhsFirst = lhs.keywords.sorted().first ?? ""
            let rhsFirst = rhs.keywords.sorted().first ?? ""
            return lhsFirst < rhsFirst
        }
    }
        
    private func tokenize(_ string: String) -> [Character] {
        Array(string.lowercased().trimmingCharacters(in: .whitespacesAndNewlines))
    }
    
    private init(root: TrieNode<T>) {
        self.root = root
    }
}

extension AutoComplete {
    // Functional-style batch operations
    public func inserting<S: Sequence>(contentsOf sequence: S) -> AutoComplete<T> 
    where S.Element == T {
        sequence.reduce(self) { autocomplete, item in
            autocomplete.inserting(item)
        }
    }
    
    // Filter items based on predicate
    public func filtered(_ predicate: @escaping (T) -> Bool) -> AutoComplete<T> {
        let filteredItems = root.allItems.filter(predicate)
        return AutoComplete(items: Array(filteredItems))
    }
    
    // Map to a new type while preserving structure
    public func compactMapped<U: Searchable>(_ transform: @escaping (T) -> U?) -> AutoComplete<U> {
        let transformedItems = root.allItems.compactMap(transform)
        return AutoComplete<U>(items: Array(transformedItems))
    }
    
    // Get suggestions with limit
    public func suggestions(for query: String, limit: Int = 10) -> [T] {
        Array(search(query).prefix(limit))
    }
    
    // Check if autocomplete contains item
    public func contains(_ item: T) -> Bool {
        root.allItems.contains(item)
    }
    
    // Get all items
    public var allItems: [T] {
        Array(root.allItems)
    }
    
    // Count of unique items
    public var count: Int {
        root.allItems.count
    }
    
    // Check if empty
    public var isEmpty: Bool {
        root.allItems.isEmpty
    }
}

public struct AutoCompleteQuery {
    let terms: [String]
    let options: QueryOptions
    
    public init(_ query: String, options: QueryOptions = .default) {
        self.terms = query.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        self.options = options
    }
    
    public struct QueryOptions {
        let caseSensitive: Bool
        let exactMatch: Bool
        let maxResults: Int?
        
        public static let `default` = QueryOptions(
            caseSensitive: false,
            exactMatch: false,
            maxResults: nil
        )
        
        public init(caseSensitive: Bool = false, 
                   exactMatch: Bool = false, 
                   maxResults: Int? = nil) {
            self.caseSensitive = caseSensitive
            self.exactMatch = exactMatch
            self.maxResults = maxResults
        }
    }
}

extension AutoComplete {
    public func search(using query: AutoCompleteQuery) -> [T] {
        let results = search(query.terms.joined(separator: " "))
        
        if let maxResults = query.options.maxResults {
            return Array(results.prefix(maxResults))
        }
        
        return results
    }
}
