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

An argument can use `...` instead of a key to indicate that the value's entries
are inserted directly into the host object/array at the argument's position.

```Console
$ jb-array :number=42 ...:number[:]=1:2:3:4 :number=5
[42,1,2,3,4,5]

$ jb a=1 ...:json='{"b":"1","c":"2"}' d=3
{"a":"1","b":"2","c":"3","d":"4"}

$ jb l4h:json@=<(jb id=u789 name=Lah) ...:object{}@=<(
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

$ # The syntax changes have added constraints on the prefixes inline keys can
$ # use. The new // syntax makes it simple to specify a key using attributes
$ jb /key=~??foo/=bar
{"~??foo":"bar"}

$ # We also allow an optional == to disambiguate flags from the start of the key
$ jb ==~??foo=bar
{"~??foo":"bar"}
```

### Missing and empty input flags

[Imperfect inputs](./004-imperfect-inputs.md) uses `~` `?` characters as flags
to set missing/empty input attributes.

We support these by unifying the existing `@` ref marker the new `~?` markers to
form a series of flags that can modify the attribute or value.

```Console
$ # flags on the right-hand side apply to the value
$ noname= jb @noname?
{}

$ noname= jb @noname??
{"noname":null}

$ # flags on the left-hand side apply to the key
$ noprop= jb ?@noprop=abc
{}

$ jb ~?@noprop:string?=abc
{}

$ noprop= jb ??@noprop=abc
{"":"abc"}

$ noprop= noname= jb ?@noprop?@=noname
{}

$ noprop= noname= jb ??@noprop??@=noname
{"":null}

$ noprop= noname= jb ?@noprop/empty_key=string=🤷/@=noname
{"🤷":"🤷"}
```

## Revised grammar

<!--
TODO: make security note about how `={user_input}` is vulnerable to the user
adding a = at the start, e.g. =foo@/stolen/file
Need to use `:=` prefix to prevent this. This was the case before this grammar
change as well.
 -->

```shell
argument         = [ splat ] ( flag-adjacent-key-argument | flag-isolated-key-argument )
flag-isolated-key-argument = key meta [ value ]
flag-adjacent-key-argument = no-flag-key [ value ]

value        = ( value-prefix inline-value | flags )
inline-value = /.*/

key                = [ flags ] [ start-of-key inline-key ]
# Don't allow double escape sequences at the start of a bare key (not prefixed
# with = or @) as they're ambiguous. e.g consider whether '==foo' is "=foo":""
# or "":"foo". With this rule it's "":"foo". '===foo' is needed for "=foo":""
inline-key         = *key-char
key-char           = /^[^:=@]/ | key-escape
key-escape         = ( "::" | "==" | "@@" )

no-flag-key        = [ flags ] [ start-of-key no-flag-inline-key
                                 | not-splat-flag-or-start-char ]
no-flag-inline-key = inline-key ( non-flag-key-char | EOF )
non-flag-key-char  = not-flag-or-start-char | key-escape

# A single char that can't be confused with =@: to start a key/value or meta; or
# +~? flags of the following value.
not-flag-or-start-char       = /^[^+~?=@:]/
not-splat-flag-or-start-char = /^[^+~?=@:.]/  # also exclude . from splat

meta = ":" CUT ( [ type ] [ collection-marker ] [ attribute-values ]
                 | collection-marker [ attribute-values ]
                 | attribute-values ) CUT

collection-attrs = ( collection-marker [ attribute-values ] | attribute-values )

type             = ( "string" | "number" | "bool" | "true" | "false" | "null"
                     | "raw" | "auto" )

value-prefix     = [ flags ] start-of-value
flags            = any-flag any-flag*
any-flag         = +( required-flag | error-empty-flag | allow-empty-flag )
splat            = "..."
required-flag    = "+"
error-empty-flag = "~"
allow-empty-flag  = "?"
start-of-ref     = "@"
start-of-str     = "="
start-of-key     = ( start-of-value | not-splat-flag-or-start-char )
start-of-value   = ( start-of-ref | start-of-str )

collection-marker = array-marker | object-marker
array-marker      = "[" [ split-char ] [ array-entry-format ] "]"
object-marker     = "{" [ split-char ] [ object-entry-format ] "}"
array-entry-format      = ":" ( "json" | "raw" )
object-entry-format      = ":" ( "json" | "attr" )
split-char        = /./

attribute-values  = "/" [ attr *( "," attr ) ] "/"
attr              = attr-name [ "=" attr-value ]
attr-name         = +( /^[^\/,=]/ | attr-name-escape )   # / , = must be escaped
attr-value        = *( /^[^\/,]/  | attr-value-escape )  # / ,   must be escaped

attr-name-escape  = ( "==" | "//" )
attr-value-escape = ( ",," | "//" )

EOF = # end of input
CUT = # match without consuming input, but causes match failure when
      # backtracking after matching
```
