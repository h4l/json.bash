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

## Syntax

See [dos/plans/005-revised-syntax.md](./005-revised-syntax.md) for the argument
grammar that supports this feature.
