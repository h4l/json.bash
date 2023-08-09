# Argument Syntax

`json.bash`'s arguments define entries in a JSON object or array. Arguments use
the syntax described here to define the key and value of their entries, and
metadata on their JSON type (number, bool, etc) and how to handle missing/empty
files, etc.

Arguments have 3 main parts — the [`key`](#key), [`metadata`](#metadata) and
[`value`](#value), which are all optional.

![argument diagram](syntax-diagrams/argument.svg)

The optional `...` splat prefix makes the argument describe multiple entries
that are merged into the host object or array.

## `key`

Keys can be prefixed with [Flags](#flags) to control their behaviour when
missing/empty.

Keys starting with `@` are references to variables or files. (File references
start with `/` or `./`, otherwise they're variables). Otherwise, the key's value
is a literal string. Values that use flag characters need to start with an `=`.

![argument diagram](syntax-diagrams/key.svg)

### `key-value`

The value of a key can be any character, except `:` which starts a
[`metadata`](#metadata) section, and `@` or `=` which start a [`value`](#value).
To include these characters in keys, they must be escaped by doubling them.

![argument diagram](syntax-diagrams/key-value.svg)

### `no-metadata-key`

Keys that are not followed by [`metadata`](#metadata) can't end with the flag
characters, as they could be confused with the flags for the argument's
[`value`](#value).

![argument diagram](syntax-diagrams/no-metadata-key.svg)

## `flags`

Flags can appear before keys and values to control what happens when an entry's
key or value is missing or empty.

- `+` restores strictness, causing an error if the item is missing or empty (the
  `json_defaults` option can make the default non-strict).
- `~` causes an un-set variable or missing file to be treated as if it was
  empty.
- `?` causes empty items to use a default value, according to the item's JSON
  type and the item's source (var, file, str).
- `??` causes entries containing the empty item to be omitted from the host
  object / array.

![argument diagram](syntax-diagrams/flags.svg)

(The parser ignores redundant flag repetitions, and doesn't require a particular
order.)

## `metadata`

Arguments have metadata to control how their values are represented in their
entry of the produced JSON object or array. There are three parts to the
metadata, all optional. The [`type`](#type), [`collection`](#collection) and
[`attributes`](#attributes).

![argument diagram](syntax-diagrams/metadata.svg)

### `type`

An argument's type defines the the JSON type of the entry's value. The default
type is `string`, so unless the default is changed using `$json_default`, a type
must be specified to create numbers, bools, etc.

The `string` type encodes the input as a JSON string, so any value is valid. The
`null`, `true` and `false` types don't require a redundant value. The `auto`
type produces numbers, bool and null values when inputs match those types, and
produces strings otherwise. The `json` type validates that the input is valid
JSON and emits it unchanged. `raw` acts like `json`, except that it performs no
validation!

![argument diagram](syntax-diagrams/type.svg)

### `collection`

An argument marked with a collection creates an entry with a variable-length
array or object as its value, rather than a single value.

The collection section can include a split character and format. The split
character controls which character is used to split the input file, variable, or
string into chunks. Each chunk of the input is converted to array or object
entries according to the _format_.

![argument diagram](syntax-diagrams/collection.svg)

#### `array-collection`

The default format is `raw`.

- The `raw` format encodes each chunk according to the argument's
  [`type`](#type).
- The `json` format validates that chunks are JSON arrays containing the
  argument's [`type`](#type). The entries of each chunk's array are concatenated
  to form a single JSON array.

![argument diagram](syntax-diagrams/array-collection.svg)

#### `object-collection`

The default format is `attrs`.

- The `attrs` format reads each chunk of input using the same `name=value`
  format as is used for [`attributes`](#attributes) (except that `/` is not
  reserved — `//` is not unescaped). All `name=value` pairs are merged to form
  entries in a single JSON object.
- The `json` format validates that chunks are JSON objects with values that
  correspond to the argument's [`type`](#type). The entries of each chunk's
  object are concatenated to form a single JSON object.

![argument diagram](syntax-diagrams/object-collection.svg)

### `attributes`

Attributes are a series of name-value pairs inside a pair of slashes, such as
`/a=b,c=d/`.

Like the values of keys, attributes can double up characters to escape them.

![argument diagram](syntax-diagrams/attributes.svg)

#### `attribute`

An individual attribute can just be a name without a value.

![argument diagram](syntax-diagrams/attribute.svg)

#### `attribute-name`

Names must escape `=`, `,` and `/` characters.

![argument diagram](syntax-diagrams/attribute-name.svg)

Values must escape `,` and `/` characters, but don't need to escape `=`.

#### `attribute-value`

![argument diagram](syntax-diagrams/attribute-value.svg)

## `value`

Values can be prefixed with [Flags](#flags) to control their behaviour when
missing/empty.

Values starting with `@` are references to variables or files. (File references
start with `/` or `./`, otherwise they're variables). Otherwise, a value starts
with `=` and the remaining content is the argument's value, without any
unescaping or further parsing.

![argument diagram](syntax-diagrams/value.svg)

> ### Warning ‼️
>
> To be parsed unambiguously, a value needs to be preceded by either a key or
> metadata section, for example `foo=bar` or `:=bar`. An argument with `=` at
> the start such as `=bar` defines a [`key`](#key), which is subject to
> double-char escaping and further parsing to identify [`metadata`](#metadata)
> and [`value`](#value) sections.
