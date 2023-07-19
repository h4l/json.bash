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
match is found.

The key or value has 4 properties which are used when resolving the default:

- `{type}`: The input's type name (`string`, `number`, etc). Keys are always
  type `string`
- `{collection}`: If the value is an array or object, `array` or `object`
  respectively, otherwise the empty string.
- `{source}`: Where the input was read from
  - inline argument value: `arg` (Also used when a key or value is not
    syntactically present in the argument.)
  - @name variable: `var`
  - @/file: `file`

The attribute defining the empty behaviour is resolved by finding the first
attribute that exists, trying all the attribute names resulting from populating
the following templates with the above properties, in order, starting from 1. If
an attribute set but is empty, resolution continues as if the attribute did not
exist:

- For keys:
  1. `empty_key`
  1. `empty_{source}_key`
  1. `empty_{source}_string`
  1. `empty_string`
- For single values:
  1. `empty`
  1. `empty_{source}_{type}`
  1. `empty_{source}`
  1. `empty_{type}`
- For array or object values:
  1. `empty`
  1. `empty_{source}_{type}_{collection}`
  1. `empty_{source}_{collection}`
  1. `empty_{type}_{collection}`
  1. `empty_{collection}`

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
`json`) have following defaults.

- `empty_file_key=error`
- `empty_var_key=error`
- `empty_file=error`
- `empty_var=error`
- `empty_array=[]`
- `empty_auto=""`
- `empty_bool=false`
- `empty_false=false`
- `empty_json=null`
- `empty_null=null`
- `empty_number=0`
- `empty_object={}`
- `empty_raw=error`
- `empty_string=""`
- `empty_true=true`

The effect is that empty keys and values from file and variable references are
errors, but empty values from inline argument values can be empty. When these
errors are overridden to the empty string, empty values will receive default
values appropriate for their intended type.

## Shorthand syntax

The argument syntax is extended to allow arguments to define optional entries
without explicitly setting attributes in common cases. Keys and values can be
preceeded by:

- `+` to make all empty values errors
- `~` to have missing or unreadable files/variables treated as empty instead of
  errors
- `?` to omit entries with an empty value
- `??` to substitute the empty value for the a default value for its type (which
  may be customised by setting defaults for the `json` call, in the same way as
  the [Default attributes](#default-attributes) are defined)

For details of the syntax changes, refer to
[docs/plans/005-revised-syntax.md](./005-revised-syntax.md).

When present, the flag rules implicitly define the following attributes at the
beginning of the argument's attributes list:

<!--
TODO: I'm not sure that the order of ? as omit and ?? as sub is what we should
go with. Omitting seems stronger and more surprising/less clear than sub, so it
seems like it could be surprising/confusing for omit to be the first and easier
of the two options.

My thinking for making omit the easier option was that omitting an empty property
seems safer than introducing a default value, or null. It's generally easier to
handle a property's absence than having to check for it being a default value.

Probably need to try it in practice to see how each alternative feels to use in
practice.
 -->

- `key-flags`:
  - required-flag `+`:
    `no_key=error,empty_key=error,empty_arg_key=error,empty_file_key=error,empty_var_key=error`
  - error-empty-flag `~`: `no_key=empty`
  - omit-empty-flag `?`:
    `empty_key=,empty_arg_key=omit,empty_file_key=omit,empty_var_key=omit`
  - sub-empty-flag `??`:
    `empty_key=,empty_arg_key=,empty_file_key=,empty_var_key=`
- `value-flags`:
  - required-flag `+`:
    `no_val=error,empty=error,empty_arg=error,empty_file=error,empty_var=error`
  - error-empty-flag `~`: `no_val=empty`
  - omit-empty-flag `?`: `empty=,empty_arg=omit,empty_file=omit,empty_var=omit`
  - sub-empty-flag `??`: `empty=,empty_arg=,empty_file=,empty_var=`

The effect of `sub-empty-flag` setting the empty attributes to the empty string
is that resolution will cascade to the default empty values, defined in
[Default attributes](#default-attributes).

The required-flag `+` makes empty values from inline argument values errors. It
will also restore the default empty-error behaviour for other sources, which
will have an effect if the defaults in effect are to not error.

## Examples

```Console
$ # Using the syntax revision from docs/plans/005-revised-syntax.md

# @name is empty and omitted due to ?
$ name= jb id:number=1 @name? other=
{"id":1,"other":""}

# ? applied to key and value
$ name= jb id:number=1 ?@name?
{"id":1}

# @name is empty and uses the default value of "" due to ??
$ name= jb id:number=1 @name??
{"id":1,"name":""}

$ # jb-catch does not exist, but works like this
$ jb ok:true | jb-catch
{"ok":true}

$ # jb-catch sees the 0x18 Cancel from the initial jb failing, and outputs nothing
$ jb ok:true=error | jb-catch
0

$ name="proj_1" jb @name repo_details:json??@<(
>   jb url@=<(grep -P '^https://.*$' ./repo.txt) | jb-catch
> )
...
{"name":"proj_1","repo_details":null}

$ grep -P '^https://.*$' ./repo.txt
grep: ./repo.txt: No such file or directory

$ jb url@<(grep -P '^https://.*$' ./repo.txt)
...
json(): empty file referenced by argument: '/dev/fd/...' from 'url@=/dev/fd/...'
␘

$ prop= jb @prop=Example
json(): argument references empty variable: $prop from '@prop=Example'

$ jb @prop=Example
json(): argument references unbound variable: $prop from '@prop=Example'

$ jb ~@prop=Example
json(): argument references empty variable: $prop from '~@prop=Example'

$ jb ~?@prop=Example
{}

$ jb ~??@prop=Example
{"":"Example"}

$ jb ~@propstring/empty_key="missing"/=Example
{"missing":"Example"}

$ value= jb ~??@prop:/empty_string="missing"/@value
json(): argument references empty variable: $value from '~??@prop:/empty_string="missing"/@=value'

$ value= jb ~??@prop:/empty_string="missing"/?@value
{}

$ value= jb ~??@prop:/empty_string="missing"/??@value
{"missing":"missing"}

$ value= jb ~??@prop:/empty_key="nokey",empty="noval"/?@value
{"nokey":"noval"}

# Get non-empty = true using the :true type and false default
$ enabled=1 active= jb @enabled:true/empty=false/ @active:true/empty=false/
{"enabled":true,"active":false}
```
