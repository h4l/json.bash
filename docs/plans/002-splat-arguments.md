# Splat arguments

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