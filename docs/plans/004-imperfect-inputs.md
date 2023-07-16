# Handling of imperfect inputs

Give users control over how problematic inputs are handled by `json` / `jb`.

In the context of a shell, it's common to successfully receive an empty value
when an upstream program feeding a pipeline fails. Therefore reliably mapping
shell data sources to JSON requires control over how empty values are handled.

As well as detecting errors, gracefully handling inputs that are expected to be
absent sometimes is a common need, so providing an idiomatic way for missing
values to be omitted or substituted with a default value should improve
usability. Because without built-in support, the user must detect the presence
of an optional input out-of-band, and then not provide the argument that would
otherwise reference the absent input.

It's also necessary to map from non-JSON values to JSON, such as creating strict
JSON true/false values from signals such as whether a string is non-empty, or
bool-like words such as Yes/No/Y/N etc.

This plan describes a design for `json.bash` to support these features.

## Approach

### Value coercion

`json` will not provide a way to adjust the encoding of input values to JSON
values. For example, it does not allow `TRUE` to be encoded as JSON boolean
`true`. This kind of behaviour is instead achieved using an external filter
program to implement the desired mapping, with `json` receiving the encoded
result. For example, with the imaginary program `truthy`:

```Console
$ truthy Yes
true
$ jb active:bool@=<(truthy Yes)
{"active":true}
```

This approach keeps `json` simple, and allows maximum flexibility when
representing non-JSON data as JSON. For example, boolean true/false
representation is done in many different ways, and depends on the locale of the
input data. If `json` did support a specific mapping method (e.g. `Yes` maps to
JSON `true`) then this would only satisfy a sub-set of situations, and may
complicate other situations that don't want to allow `Yes` to mean `true`.

### Error handling

`json` handles encoding errors using external filter programs, rather than
internally.

- Errors from encoding raw source data

  If an argument needs to handle invalid input data, it does so by not directly
  reading the input data itself. The error-handling argument read input from a
  filter program that performs the encoding and successfully emits nothing when
  its input is faulty. The error-handling argument can provide a substitute for
  the empty value, omit it, or raise its own error.

- Errors from upstream `json` calls that are being consumed by one of the
  arguments of a `json` call.

  Errors from upstream `json` calls emit a `0x18` Cancel. If a `json` call
  should emit different JSON for an argument if an upstream error occurred, it
  can do so by wrapping the upstream source with a filter program that detects
  `0x18` Cancel and successfully emits nothing. The `json` call can provide a
  substitute for the empty value, emit it, or raise its own error.

`json` **does** allow control over errors that occur when starting to read an
input source, but not errors that occur after data has started to be encoded.

Arguments can:

- Substitute empty input data for a default JSON value.
- Omit the entry for an argument that receives an empty input value
- Opt to treat input sources (files, variables) that are not readable as empty,
  rather than errors
- Raise an error when an argument receives an empty input value

## Argument handling

When `json` processes an argument to emit a JSON entry for it, its behaviour
varies according to the error handling options of the argument.

The result of processing an argument's keys and values is one of the following.

1. The input dereferences without error, the data is non-empty and is valid for
   the type. Handled according to
   [Non-empty, valid value](#non-empty-valid-value)
1. The input dereferences to a value that is empty — Handled according to
   [Empty value](#empty-value)
1. The input references a variable that does not exist — Handled according to
   [No value available](#no-value-available)
1. The input references a file that is not readable — Handled according to [No
   value available](#no-value-available
1. The input dereferences to a value that not empty but is an invalid input for
   the argument's type — Handled according to
   [Non-empty, invalid value](#non-empty-invalid-value)

### Non-empty, valid value

The value is encoded as JSON. It will be emitted as part of the argument's entry
in the JSON object or array, unless the key or value of the entry is omitted due
to being substituted with an empty value, as described in
[Empty value](#empty-value).

### Non-empty, invalid value

An error is raised, stating that the argument's value is not a valid input for
the argument's type.

This situation cannot be handled or ignored within the `json` call that is
processing the argument that triggered this error — instead a downstream program
must detect and handle the `0x18` Cancel that results from this error. (See
[Error handling](#error-handling) for details.)

### No value available

The key or value is a reference to a variable or file, which cannot be read
(whether due to a variable not being defined, a file not existing, or other
error that prevents the reference being readable).

The `no_key` and `no_val` attributes determine the behaviour in this case, for
keys and values respectively. When the applicable `no_*` has the value `empty`,
the key or value is treated as if it was read successfully with an empty value,
following the procedure in [Empty value](#empty-value). Otherwise, an error
describing the failure to dereference the key or value is raised.

### Empty value

When The argument's key or value is read successfully but the resulting value is
empty (or was made an empty value via a `no_*=empty` attribute), the behaviour
depends on the `empty*` attributes of the argument.

An argument does not store its empty behaviour in a single attribute with a
fixed name. Instead, one of a priority-ordered list of possible `empty*`
attribute names is resolved by checking for the existence of each name until a
match is found. (A match is guaranteed, as the lowest-priority values have
[Default attributes](#default-attributes) defined.)

The key or value has 4 properties which are used when resolving the default:

- `{type}`: The input's type name (`string`, `number`, etc). Keys are always
  type `string`
- `{collection}`: If the value is an array or object, `array` or `object`
  respectively, otherwise the empty string.
- `{position}`: Whether the input is the key or value of the entry: `key` or
  `val`
- `{source}`: Where the input was read from
  - inline argument value: `arg` (Also used when a key or value is not
    syntactically present in the argument.)
  - @name variable: `var`
  - @/file: `file`

The attribute defining the empty behaviour is resolved by finding the first
attribute that exists, trying all the attribute names resulting from populating
the following templates with the above properties, in order, starting from 1.:

- For key or single values:
  1. `empty_{position}`
  1. `empty`
  1. `empty_{source}_{type}`
  1. `empty_{source}`
  1. `empty_{type}`
- For array or object values:
  1. `empty_{position}`
  1. `empty`
  1. `empty_{source}_{type}_{collection}`
  1. `empty_{source}_{collection}`
  1. `empty_{type}_{collection}`
  1. `empty_{collection}`

> (The ordering and naming are chosen to allow the `empty` or `empty_key`
> properties to succinctly override the default behaviour value for specific
> argument, while allowing fine-grained control over the behaviour of empty
> values from different sources and types.)

The value of the resolved `empty*` attribute is interpreted as follows:

- `error` — an error is raised, stating that the value is empty but is not
  permitted to be empty.
- `error={message}` — an error is raised, stating that entry for this argument
  could not be created, including the `{message}` as an explanation.
- `omit` — no entry for the argument created. If a key is omitted, any error
  that would result from encoding the value is not raised.
- `{type}={value}` — encode `{value}` as `{type}` according to
  `json.encode_{type} {value}`
- Otherwise, encode entire value as JSON. This will fail if the value is not
  valid JSON, which results in an error, stating that the value is empty and
  should have been substituted, but the substitute value is not valid JSON.

## Default attributes

Attributes defined by `json.define_defaults` (and thus the default-defaults for
`json`) have following defaults:

- `empty_array=[]`
- `empty_auto=""`
- `empty_bool=false`
- `empty_false=false`
- `empty_json=error`
- `empty_null=null`
- `empty_number=0`
- `empty_object={}`
- `empty_raw=error`
- `empty_string=""`
- `empty_true=true`

## Shorthand syntax

The argument syntax is extended to allow arguments to define optional entries
without explicitly setting attributes in common cases.

The argument type grammar rule is currently defined as:

```
type = ":" ( "string" | "number" | "bool" | "true" | "false"
           | "null" | "raw" | "auto" )
```

With shorthand optional syntax, it becomes:

```
type             = ":" key-flags
                   ( "string" | "number" | "bool" | "true" | "false" | "null"
                     | "raw" | "auto" )
                   value-flags

key-flags        = [required-flag] [error-empty-flag] [ omit-empty-flag ]
value-flags      = [required-flag] [error-empty-flag]
                   [ omit-empty-flag | null-empty-flag ]
required-flag    = "!"
error-empty-flag = "~"
omit-empty-flag  = "?"
null-empty=flag   = "??"
```

When present, the flag rules implicitly define the following attributes at the
beginning of the argument's attributes list:

- `key-flags`:
  - `required-flag`: `no_key=error,empty_key=error`
  - `error-empty-flag`: `no_key=empty,empty_key=omit`
  - `null-empty=flag`: `empty_key=null`
- `value-flags`:
  - `required-flag`: `no_val=error,empty_val=error`
  - `error-empty-flag`: `no_val=empty,empty_val=omit`
  - `null-empty=flag`: `empty_val=null`
