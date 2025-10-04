<h1>Pattern Caps Keyboard</h1>

  i got inspired by mkbhd’s tweet reply ![tweet photo](/mkbhd_tweet.png)

<p>
  so i made an iOS keyboard extension that auto-writes random pattern caps lock 
</p>

<h2> demo <h2>
[https://github.com/user-attachments/assets/68391727-99f2-40a8-a424-f56641d2e7fb
](https://github-production-user-asset-6210df.s3.amazonaws.com/81426655/497415310-68391727-99f2-40a8-a424-f56641d2e7fb.mp4?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=AKIAVCODYLSA53PQK4ZA%2F20251004%2Fus-east-1%2Fs3%2Faws4_request&X-Amz-Date=20251004T073627Z&X-Amz-Expires=300&X-Amz-Signature=d001b248f351d3f931deab6f349034fe2dc0d5f9f6ee1480291c20fabb7db807&X-Amz-SignedHeaders=host)
  
<h2>how i did it</h2>
<p>
the project is split into two parts: a host iOS app and a custom keyboard extension. 
the host app is just the landing screen plus a settings page where you can enable keyboard plug-ins. 
the keyboard extension is the actual typing surface that shows keys, randomizes caps, suggests corrections/next words, and hooks into those plug-ins. 
both the app and the keyboard share preferences through an app group so the keyboard knows which plug-ins you enabled.
</p>

<p>
under the hood, the keyboard builds its UI programmatically, manages caps state, handles key taps/long presses, and draws a suggestion bar that mixes spellcheck/autocomplete with plug-in suggestions. 
text state is tracked by a helper so extensions can modify or react to what you type, while dictionaries and bigram data files power autocomplete, corrections, and next-word predictions.
</p>

<h2>autocomplete with a trie</h2>

<p>
the autocomplete system itself is built on a trie. 
think of it like a branching tree where each character you type moves you down another branch. 
when you finish a prefix, the system quickly gathers all possible words that live under that branch. 
results are then filtered so they actually start with the prefix you typed, and sorted so shorter words come first (then alphabetically if tied). 
helpers make it easy to cap results, and while the query object has options like case-sensitivity and exact matching, right now only the max results limit is actually used.
</p>

<h2>the TrieNode thing</h2>

<p>
each <code>TrieNode</code> is an immutable building block of that tree. 
it has two things: a set of items (words or objects) that end at this point, and a dictionary of children keyed by the next character. 
when you insert a word, the algorithm walks character by character, creating or reusing nodes along the path, and at the final character it adds the word into that node’s set, returning a brand-new updated tree without mutating the old one. 
when you search, it walks down the trie for the prefix, then pulls together all items stored under that node by recursively collecting everything in its children. 
this makes prefix searches very fast (linear in the length of the prefix), and because nodes hold sets of items, the same object can be reachable by multiple keywords without duplication.
</p>

<p>maybe someday i'll add more details on how the keyboard UI was implemented...that was the hardest part of the project besides having a good autocomplete. diving head down into other projects...</p>

<pre><code>// inserting "cat" into trie
root
 └─ 'c'
     └─ 'a'
         └─ 't'  (stores "cat")
</code></pre>

<h2>summary</h2>

<p>
the host app manages setup, the keyboard does the typing and suggesting, and the extension system plus trie-based autocomplete (built from these immutable <code>TrieNode</code>s) make it easy to add fun extras—like my random pattern caps lock mode.
</p>

</div>
</body>
</html>
