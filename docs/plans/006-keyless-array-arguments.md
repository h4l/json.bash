# Keyless array arguments

Before the [005-revised-syntax.md](./005-revised-syntax.md) we parsed `=foo` as
a value `foo` without any escape processing. 005's syntax behaves differently as
= can prefix keys as well as values, e.g `a=b` is equivalent to `=a=b`. This was
partly for consistency of syntax, and partly because syntax errors could lead to
the regex-based parser backtracking and matching the whole arg as a value.

The consistent syntax between key and value positions means it would be quite
straightforward to re-introduce the ability to use `=foo` for `json.array` /
`jb-array`. We'd just need to parse the arguments without keys, so only `...`
and `:` could precede the value.
