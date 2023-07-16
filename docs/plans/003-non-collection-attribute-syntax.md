# Collection-neutral attribute syntax

Currently, using attributes implies `[...]` which makes a value-array unless
`[array=false]` is used. We could allow a neutral attribute syntax using `/.../`
that preserves the default type:

```Console
# Using the empty attributes from docs/plans/004-imperfect-inputs.md
$ enabled=1 active= jb @enabled:true/empty=false/ @active:true/empty=false/
{"enabled":true,"active":false}
```

Given that non-array/object values wouldn't be splitting the input, the
split-char shorthand syntax probably doesn't make sense.
