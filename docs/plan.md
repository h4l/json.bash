# Ideas / Planned Features

## Object values

We have two ways to create arrays: the `json.array` / `jb-array` command, suited
to tuple-like, heterogeneous arrays. And the `[]` type modifier, for value
arrays — homogeneous, variable length.

For objects, we only have the fixed length option, via `json` / `jb`. We need an
idiomatic way to create variable-length homogeneous objects.

### Proposal 1. — Allow `{}` in addition to `[]` for argument attributes

Using `{}` in an argument would make the argument an object-value, resulting in
it creating a single JSON object, containing properties from the split value,
like the way we create array values.

The clearest value-type would be multiple JSON objects, which we can merge into
one. For example:

```Console
$ jb users:json{}@=<(
>   username=h4l jb @username:json@=<(jb id=u123 name=Hal)
>   username=foo jb @username:json@=<(jb id=u456 name=Foo)
> )
{"users":{"h4l":{"id":"u123","name":"Hal"},"foo":{"id":"u456","name":"Foo"}}}
```

Rather than explicit calls, the content of the users psub could be a shell loop,
or an xargs / find pipeline to dynamically create entries.

This implies an `:object` type would be useful. It would be like `:json` but
only accept JSON rooted at an object. Similarly, `:array` could be defined.

## Splat arguments

Currently we don't provide a way to create a top-level value-array (the kind
created by a `[]` argument). The same issue would exist with `{}` value-object
arguments.

We could allow for arguments to specify that they merge into the object/array
being created by the `json` / `json.array` call, like how Python (and other
languages) allow merging lists, dicts using `*`/`**`. e.g. in Python:

```Python
>>> [1, 2, 3, *[4, 5, 6]]
[1, 2, 3, 4, 5, 6]
>>> {**{"foo": 123, "bar": 456}, "baz": 789}
{"foo": 123, "bar": 456, "baz": 789}
```

It could look like this:

```Console
$ jb l4h:json@=<(jb id=u789 name=Lah) +:object{}@=<(
>   username=h4l jb @username:json@=<(jb id=u123 name=Hal)
>   username=foo jb @username:json@=<(jb id=u456 name=Foo)
> )
{"l4h":{"id":"u789","name":"Lah"},"h4l":{"id":"u123","name":"Hal"},"foo":{"id":"u456","name":"Foo"}}
```

Using `*` as the merge/splat operator would conflict with shell globbing, but
`+` seems like a reasonable option. Also as we most likely would not
de-duplicate object keys, so we would be concatenating entries.

For arrays:

```Console
$ jb-array :number=42 +:number[:]=1:2:3:4 :number=5
[42,1,2,3,4,5]
```

## Optional and required values; Strict / permissive values

Currently we're strict about value representation — we fail with an error if a
value is not in exactly the right format. We could introduce a notation to
modify this, allowing coercion of values:

```Console
$ jb enabled:bool~=1 active:~bool=
{"enabled":true,"active":false}

$ jb enabled:bool~=1 active:~bool?=0
{"enabled":true,"active":false}
```

Also, allowing values to be omitted when not present. Also for missing files or
unset variables.

```Console
$ jb enabled:~bool=1 active:bool?=
{"enabled":true}
```

There could be advantages to making use of the extensible named attribute
syntax, rather than introducing syntax-level additions, like `~`. Currently
using attributes implies `[...]` which makes a value-array unless
`[array=false]` is used. We could allow a neutral attribute syntax using `()`
that preserves the default type:

```Console
$ # =true (empty key) implying a default
$ jb enabled:bool(~)=1 active:bool(?)= enhanced:bool(~,?,=true)=
{"enabled":true,"enhanced":true}

$ # A way to omit on invalid value for type could be useful, it would allow
$ # multiple args for the same key to represent a union of types without direct
$ # syntax support in arguments:
$ level=42 jb @level:number(!,?) @level:string(?)
{"level":42}

$ level=high jb @level:number(!,?) @level:string(?)
{"level":"high"}

$ level= jb @level:number(!,?) @level:string(?)
{}
```

Here `!`,`?` would mean strict encoding but optional, so omit rather than fail
when the value is not a number. `!` is the current default, but could re-apply
strictness when `json_defaults` was used to make the default permissive.

`()` need quoting in bash, so they would be awkward to use. Perhaps `//`
instead:

```Console
$ level=high jb @level:number/!,?/ @level:string/?/
{"level":"high"}

$ data= jb @data:/?/
{}
```
