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

### Object values

```Console
$ # We can use {} in addition to [] to define variable-length object values.

# Not sure of the semantics for :type yet - the type could refer to the value
# type of the objects, or to the type of each element obtained from splitting
# the input by the split char.
$ jb sizes:number{}=$'{"a":1,"b":2}\n{"c":3,"d":4}'
{"sizes":{"a":1,"b":2,"c":3,"d":4}}
```

### Non-collection attributes

```Console
$ # We can use /x=y/ to define attributes. This is **instead** of using [x=y],
$ # which frees up the split char shorthand to not require escaping

$ power= jb @power/empty=string=mid/?
{"power":"mid"}

# , does not need escaping
$ jb counts:number[,]=1,2,3
{"counts":[1,2,3]}

$ counts= jb @counts:number[,]/empty=[55]/
{"counts":[55]}
```

### Missing and empty input flags

[Imperfect inputs](./imperfect-inputs.md) uses `!` `~` `?` characters as flags
to set missing/empty input attributes.

```Console
# flags without types/attrs apply to the value
$ noname= jb @noname:?
{}

$ noname= jb @noname:??
{"noname":null}

# To apply only to the key, flags need a type or // to disambiguate
$ nopro jb @noprop:?//=abc
{}

$ nopro jb @noprop:?string=abc
{}

$ noprop= jb @noprop:??//=abc
{"":"abc"}

$ noprop= noname= jb @noprop:?//?@=noname
{}

$ noprop= noname= jb @noprop:?//?@=noname
{"":null}

$ noprop= noname= jb @noprop:?/empty=string=🤷/?@=noname
{"🤷":"🤷"}
```

## Revised grammar

```shell
argument         =  argument-no-attrs | full-argument
typed-argument   = [ splat | key ] [ type [ metadata ] ] [ value ]
untyped-argument = ( splat | no-flag-key ) [ metadata ] [ value ]
splat            = "..."

value        = ref-value | inline-value
inline-value = /^=.*/
ref-value    = "@" inline-value

key          = ref-key | inline-key
inline-key   = *key-char
ref-key      = [ splat ] "@" key-char *key-char
key-char     = /^[^:=@[{\/]/ | key-escape
key-escape   = ( "::" | "==" | "@@" | "[[" | "{{" | "//" )

no-flag-key        = no-flag-ref-key | no-flag-inline-key
no-flag-inline-key = *key-char non-flag-char
no-flag-ref-key    = [ splat ] "@" no-flag-inline-key
key-char           = /^[^:=@[]/ | key-escape
key-escape         = ( "::" | "==" | "@@" | "[[" )
non-flag-key-char  = /^[^:=@[{\/!~?]/

key = key-no-flags
key = key-internal-flags
key-internal-flags = /.*[^!~?]/


metadata         = ( value-flags
                   | [ key-flags ] collection-attrs [ value-flags ] )
collection-attrs = ( collection-marker [ attribute-values ] | attribute-values )

type             = ":" [ type-name ]
type-name        = ( "string" | "number" | "bool" | "true" | "false" | "null"
                     | "raw" | "auto" )

key-flags        = type-flags
value-flags      = type-flags
type-flags       = ( required-flag [ error-empty-flag ] [ sub-empty-flag | omit-empty-flag ]
                     | error-empty-flag [ sub-empty-flag | omit-empty-flag ]
                     | sub-empty-flag
                     | omit-empty-flag )
required-flag    = "!"
error-empty-flag = "~"
omit-empty-flag  = "?"
sub-empty-flag   = "??"

collection-marker = array-marker | object-marker
array-marker      = "[" [ split-char ] "]"
object-marker     = "{" [ split-char ] "}"
split-char        = /./

attribute-values  = "/" [ attr *( "," attr ) ] "/"
attr              = attr-name [ "=" attr-value ]
attr-name         = *( /^[^\/,=]/ | attr-name-escape )   # / , = must be escaped
attr-value        = *( /^[^\/,]/  | attr-value-escape )  # / ,   must be escaped

attr-name-escape  = ( "==" | ",," | "//" )
attr-value-escape = ( ",," | "//" )


```

<!--

#argument-no-attrs = ( splat | no-flag-key ) value-flags [ value ]
no-flag-key       = no-flag-ref-key | no-flag-inline-key

no-flag-inline-key   = *key-char non-flag-char
no-flag-ref-key      = "@" no-flag-inline-key
key-char     = /^[^:=@[]/ | key-escape
key-escape   = ( "::" | "==" | "@@" | "[[" )
non-flag-char = /[^!~?]/

key = key-no-flags
key = key-internal-flags
key-internal-flags = /.*[^!~?]/
 -->
