# Object values

We have two ways to create arrays: the `json.array` / `jb-array` command, suited
to tuple-like, heterogeneous arrays. And the `[]` type modifier, for value
arrays — homogeneous, variable length.

For objects, we only have the fixed length option, via `json` / `jb`. We need an
idiomatic way to create variable-length homogeneous objects.

## Proposal 1. — Allow `{}` in addition to `[]` for argument attributes

Using `{}` in an argument would make the argument an object-value, resulting in
it creating a single JSON object, containing properties from the split value,
like the way we create array values.

The clearest value-type would be multiple JSON objects, which we can merge into
one. For example:

```Console
$ jb users:json{}@<(
>   username=h4l jb @username:json@<(jb id=u123 name=Hal)
>   username=foo jb @username:json@<(jb id=u456 name=Foo)
> )
{"users":{"h4l":{"id":"u123","name":"Hal"},"foo":{"id":"u456","name":"Foo"}}}
```

Rather than explicit calls, the content of the users psub could be a shell loop,
or an xargs / find pipeline to dynamically create entries.

This implies an `:object` type would be useful. It would be like `:json` but
only accept JSON rooted at an object. Similarly, `:array` could be defined.

## Syntax

See [dos/plans/005-revised-syntax.md](./005-revised-syntax.md) for the argument
grammar that supports this feature.

## Implementation plan

As well as support for the `{}` syntax, this plan also covers the `...` splat
operator, as the features they provide overlap enough for it to make sense to
design their implementation together.

### Additions

The low-level API would gain new functions that construct objects:

`json.encode_object_entries()`

The encoding logic of encode_object without the start/end markers. Can be used
to implement `json.encode_object` and a stream-encoding function. Useful for
both object properties, and splatting into the parent object.

Note that the exising `json.encode_*` functions can be thought of as encoding
array entries — they can all emit multiple elements, optionally joined by a
comma.

`$type` corresponds to the type of the entry value. `$validate_entries` (`true`
by default) determines if pre-encoded JSON objects are validated with
`json.validate` prior to encoding.

<!-- TODO: need a way to signal to the caller if 0 entries were emitted, because
     the caller is responsible for inserting commas between adjacent blocks of
     entries. We should probably return a fixed error status if no entries are
     emitted.

     Note: When implementing we can append commas to all array entries, then
     remove commas from the final entry and from any entries which consist only
     of commas, in order to omit empty lines.
      -->

Two types of inputs:

- entries, single array:
  - Indexed array of pre-encoded JSON objects
  - Associative array of key-value pairs
- keys and values:
  - Two Bash indexed arrays of keys and values
  - Positional arguments of alternating key, value pairs

`json.encode_object_entries_from_${format}`

`$format` defines how user-provided values are mapped to inputs for
`json.encode_object_entries` to consume. As with arrays, inputs are split into
chunks, by default by line.

There are two formats:

- `json` — JSON objects — entries are the entries of the object (after type)
- `attrs` — key=value attributes — using the same format as the attributes in
  our argument syntax.

These functions receive an array of chunks named by `$in` and call
`json.encode_object_entries` with the entries resulting from decoding the
chunks. `$out` controls the output location and `$type` the type of the entry
values, as normal.

<!-- TODO: do we need this? -->

`json.encode_object()`

A simple wrapper around `json.encode_object_entries` that wraps the entries in
`{` `}` and ignores the error status if 0 entries are emitted.

`json.stream_encode_object_entries()`

Same output behaviour as `json.encode_object_entries`, but with input streamed
from a file. File chunks are decoded according to `$format`. Can be implemented
as multiple `json.encode_object_entries_from_${format}` calls.

Inputs:

- File of pre-encoded JSON object chunks
- File of key=value attribute chunks

### Changes

`json.stream_encode_array`

This currently emits the `[` `]` and the entries. We can replace this with
`json.stream_encode_array_entries` (mirroring
`json.stream_encode_object_entries`) and emit the surrounding brackets only when
needed — they're not required when using ... to splat array entries.

`json.encode_from_file`

This assumes responsibility for emitting the surrounding `[` `]` or `{` `}`
brackets. Instead of taking an `array=true/false` argument, it takes
`collection=(array|object)[_entries]`, where the `_entries` variant does not
wrap the output in brackets.

<!-- TODO: We could also omit this bracket wrapping, and perform it in the
    `json` function, as it already does it for non-streamed arrays values. -->

`json`

`{}` arguments are used in two ways: as regular object properties, and as the
subject of the `...` splat operator.

#### Formats

Object arguments are interpreted with a _format_, which defines how values are
mapped to object entries. The default format can be changed using `{:format}`
syntax, or `{S:format}` where `S` is the char to split inputs into chunks on
(default: `\n`). Formats are `:json` and `:attr`.

#### `{}` without splat

The `{}` modifier allows objects to be created from entries. Sources of entries
are Bash associative arrays, or chunks which are decoded into object entries
according to the argument's _format_.

- `@/file` references split into chunks (like `[]` array arguments) and
  stream-encoded into entries according to the argument's format.
- `@var` references are handled according to variable type:
  - Associative arrays' key, value entries are used as-is as
  - Indexed arrays are treated like chunks from a file
- `=` inline values string values are treated like the contents of file refs

The `:type` of a `{}` argument defines the type of the object's entries, so
`:number{}` is a property containing a JSON object with number values.

#### `...` and `{}`

The `...` operator, when used in a `json` call with `json_return=object`
automatically implies the `{}` modifier. An argument using `...` `{}` creates
object entries, which are inserted directly into the object created by the
`json` call, (instead of creating a child object, as with a non-splat `{}`
argument).

When a splat argument uses array variable references in both the key and value
position, they must be equal lengths and are used as keys and values for the
object's entries.

Otherwise, arguments are interpreted in the same way as non-splat object
arguments.

#### Examples

`{}` without splat:

```Console
$ # Bash interface — entries from pre-encoded objects. Files and variables use
$ # `{:json}` format by default
$ entries=('{"a":1,"b":2}' '{}' '{"c":3}')
$ json @entries:number{}  # using a type validates the object values
{"entries":{"a":1,"b":2,"c":3}}

$ # Bash interface — entries from an associative array
$ declare -A points=()
$ for name in start middle end; do
>   out="points[$name]" json x:number@RANDOM y:number@RANDOM
> done
> json @points:json{}
{"points":{"start":{"x":21933,"y":1055},"middle":{"x":9747,"y":5306},"end":{"x":6788,"y":11885}}}

$ # Command line interface — inline arguments use `{:attr}` format by default
$ jb points:{}@<(jb start:number{}=x=1,y=2 middle:number{}=x=3,y=4 end:number{}=x=5,y=6)
{"points":{"start":{"x":1,"y":2},"middle":{"x":3,"y":4},"end":{"x":5,"y":6}}}

$ jb points:{}@<(
>   for name in start middle end; do
>     export name
>     jb @name:json@<(jb x:number@RANDOM y:number@RANDOM)
>   done
> )
{"points":{"start":{"x":21933,"y":1055},"middle":{"x":9747,"y":5306},"end":{"x":6788,"y":11885}}}
```

`...` with `{}`:

```Console
$ # Bash interface — entries from pre-encoded objects
$ entries=('{"a":1,"b":2}' '{}' '{"c":3}')
$ # using a type validates the entry values
$ jb ...@entries:number{}
{"a":1,"b":2,"c":3}

$ # ... defaults to :json{} for json_return=object
$ jb ...@entries:{}
{"a":1,"b":2,"c":3}

$ # ... defaults to :json{} for json_return=object
$ jb ...@entries
{"a":1,"b":2,"c":3}

$ # Command line interface — inline arguments
$ jb ...:number{}=a=1,b=2,c=3,d=4
{"a":1,"b":2,"c":3,"d":4}

$ # Bash interface — entries from an associative array
$ declare -A points=()
$ for name in start middle end; do
>   out="points[$name]" json x:number@RANDOM y:number@RANDOM
> done
> json ...@points:json{}
{"start":{"x":21933,"y":1055},"middle":{"x":9747,"y":5306},"end":{"x":6788,"y":11885}}

# Bash interface — separate key, value arrays
$ keys=(a b c) values=(1 2 3)
$ jb ...@keys:number{}@values
{"a":1,"b":2,"c":3}
```

Aside: `...` with `[]`:

```
$ jb-array ...:number[,]=1,2,3 ...:number[,]=4,5,6
[1,2,3,4,5,6]

# ... defaults to :<default>[] i.e. :string[]
$ jb-array ...:=$'1\n2\n3' ...[,]=4,5,6
["1","2","3","4","5","6"]
```

## Rejected options

```Console
$ # Maybe: create objects from key and value arrays with {} when both are named
$ agents=(joe bob) agents_values=('{"id":"x.93"}' '{"id":"x.12"}')
$ jb @agents:json{}@agents_values
{"agents":{"joe":{"id":"x.93"},"bob":{"id":"x.12"}}}

$ # Allow _KEYS and _VALUES keys to be used when the ref isn't set. Could also
$ # work with the _FILE suffix, but this might be too much magic.
$ unset agents
$ agents_KEYS=(joe bob) agents_VALUES=('{"id":"x.93"}' '{"id":"x.12"}')
$ jb @agents:{}
{"agents":{"joe":{"id":"x.93"},"bob":{"id":"x.12"}}}

$ # We'd need a way to define the key when using a file input, e.g.
$ jb @<(cat ...):{}/key=foo/@<(cat ...)
{"foo":{...}}
```
