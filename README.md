<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>README - iOS Pattern Caps Keyboard</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
:root {
  --bg:#ffffff;--fg:#111827;--muted:#6b7280;--link:#2563eb;--border:#e5e7eb;--codebg:#f3f4f6
}
@media (prefers-color-scheme: dark){
  :root {
    --bg:#0f172a;--fg:#e5e7eb;--muted:#94a3b8;--link:#60a5fa;--border:#1f2937;--codebg:#1e293b
  }
}
body {margin:0;padding:0;font:16px/1.6 system-ui,-apple-system,Segoe UI,Roboto,Ubuntu,Cantarell,Noto Sans,Arial;background:var(--bg);color:var(--fg)}
.container {max-width:900px;margin:0 auto;padding:40px 20px}
h1,h2 {margin-top:1.5em}
p {margin:1em 0}
a {color:var(--link);text-decoration:none}
a:hover {text-decoration:underline}
pre,code {background:var(--codebg);padding:2px 6px;border-radius:6px}
pre {display:block;overflow:auto;padding:12px}
img, video {max-width:100%;margin:20px 0;border-radius:8px;border:1px solid var(--border)}
</style>
</head>
<body>
<div class="container">

<h1>Pattern Caps Keyboard</h1>

<p>
  i got inspired by mkbhd’s tweet reply <a href="#">linked here</a>:
</p>

<p>
  so i made an iOS keyboard extension that auto-writes random pattern caps lock 
</p>

<video controls src="demo.mov" poster="mkbhd_tweet.png"></video>

<h2>how i did it</h2>

<p>
the project is split into two parts: a host iOS app and a custom keyboard extension. 
the host app is just the landing screen plus a settings page where you can enable keyboard plug-ins. 
the keyboard extension is the actual typing surface that shows keys, randomizes caps, suggests corrections/next words, and hooks into those plug-ins. 
both the app and the keyboard share preferences through an app group so the keyboard knows which plug-ins you enabled.
</p>

<img src="landing-screen.png" alt="Host App Landing Screen">
<img src="keyboard.png" alt="Custom Keyboard Extension">

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

<img src="trie-diagram.png" alt="Trie Structure Diagram">

<h2>dive into TrieNode</h2>

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
