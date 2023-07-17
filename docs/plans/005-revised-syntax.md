# Revised argument syntax

Revise the argument syntax to support several planned features and improve UX.

The new features are:

- [Splat arguments](./002-splat-arguments.md) — Dynamic property definition by
  flattening value-objects and value-arrays as entries in their parent
  object/array.
- [Imperfect inputs](./004-imperfect-inputs.md)
  - extensive use of attributes for single values, not just value-arrays
  - shorthand to define handling behaviour of missing and empty inputs
- [Object values](./001-object-values.md) — Support for value-objects as well as
  value-arrays.
- [Non-collection attribute syntax](./003-non-collection-attribute-syntax.md) —
  Support definition of attributes without also implying an argument is a
  value-array

## Current argument grammar

```shell
argument     = [ key ] [ type ] [ attributes ] [ value ]
value        = ref-value | inline-value
key          = ref-key | inline-key

type         = ":" ( "string" | "number" | "bool" | "true" | "false"
                      | "null" | "raw" | "auto" )

inline-key   = *key-char
ref-key      = "@" key-char *key-char
key-char     = /^[^:=@[]/ | key-escape
key-escape   = ( "::" | "==" | "@@" | "[[" )

inline-value = /^=.*/
ref-value    = "@" inline-value

attributes   = "[" [ attr *( "," attr ) ] "]"
attr         = attr-name [ "=" attr-value ]
attr-name    = *( /^[^],=]/ | attr-name-escape )   # ] , \ = must be escaped
attr-value   = *( /^[^],]/  | attr-value-escape )  # ] , must be escaped

attr-name-escape  = ( "==" | ",," | "]]" )
attr-value-escape = ( ",," | "]]" )
```

## New syntax examples

### Splat arguments

An argument can use `+` instead of a key to indicate that the value's entries
are inserted directly into the host object/array at the argument's position.

```Console
$ jb-array :number=42 +:number[:]=1:2:3:4 :number=5
[42,1,2,3,4,5]

$ jb a=1 +:json='{"b":"1","c":"2"}' d=3
{"a":"1","b":"2","c":"3","d":"4"}

$ jb l4h:json@=<(jb id=u789 name=Lah) +:object{}@=<(
>   username=h4l jb @username:json@=<(jb id=u123 name=Hal)
>   username=foo jb @username:json@=<(jb id=u456 name=Foo)
> )
{"l4h":{"id":"u789","name":"Lah"},"h4l":{"id":"u123","name":"Hal"},"foo":{"id":"u456","name":"Foo"}}

```

## Revised grammar

```shell
argument     = [ splat | key ] [ type ] [ attributes ] [ value ]
value        = ref-value | inline-value
key          = ref-key | inline-key

type         = ":" ( "string" | "number" | "bool" | "true" | "false"
                      | "null" | "raw" | "auto" )

splat        = "+"
inline-key   = *key-char
ref-key      = "@" key-char *key-char
key-char     = /^[^:=@[]/ | key-escape
key-escape   = ( "::" | "==" | "@@" | "[[" )

inline-value = /^=.*/
ref-value    = "@" inline-value

attributes   = "[" [ attr *( "," attr ) ] "]"
attr         = attr-name [ "=" attr-value ]
attr-name    = *( /^[^],=]/ | attr-name-escape )   # ] , \ = must be escaped
attr-value   = *( /^[^],]/  | attr-value-escape )  # ] , must be escaped

attr-name-escape  = ( "==" | ",," | "]]" )
attr-value-escape = ( ",," | "]]" )
```
