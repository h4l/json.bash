# `json.bash` 🦬

`json.bash` is a bash library and or command-line tool that encodes JSON.

```console tesh-session="intro" tesh-setup=".tesh-setup"
$ source json.bash
$ json msg="Hello World" animals=🦬🐂🐃 bash:true dependencies:null
{"msg":"Hello World","animals":"🦬🐂🐃","bash":true,"dependencies":null}

$ # values are strings unless explicitly typed
$ json id=42 size:number=42 surname=null data:null
{"id":"42","size":42,"surname":"null","data":null}

$ # reference data in bash vars
$ people=("$(json name=Bob)" "$(json name=Alice)") sizes=(42 91 2)
$ id="abc.123" json @id @sizes:number[] @people:raw[]
{"id":"abc.123","sizes":[42,91,2],"people":[{"name":"Bob"},{"name":"Alice"}]}
```

Despite being implemented in bash, `json.bash` aims for (relatively) decent
performance by using (don't laugh) a "vectorised" encoding strategy to create
JSON strings with a constant number of bash operations, independent of the data
length, without iterating over string or array contents in bash (which is very
slow). As a result it can encode large files pretty quickly. Encoding time tends
to grow more with the quantity `json.bash` operations than the data size of each
item.

That said, performance of tools like [jo] or [jq] is much better. `json.bash` is
a bit of a toy compared to these, but it can be useful in situations where a
bash script needs to generate JSON with minimal startup time (forking a jq
process is slow), or when you need to generate a bit of JSON and wish to
minimise dependencies.

To be really minimal, just take the `encode_json_strings` function and use it to
write a small, data-specific script.

## Examples

`json.bash` contains functions `json`, `json.object` and `json.array`. It also
works as a command-line program, by symlinking `json.bash` with these names in a
dir on your `$PATH`. It works mostly the same as the functions, except that the
`@var` syntax can only reference environment variables, so bash array variables
are not available.

### `json` / `json.array` / `json.object`

```console tesh-session="examples" tesh-setup=".tesh-setup"
$ source json.bash

$ # The json function creates JSON objects
$ json
{}

$ # It creates arrays if json_return=array
$ json_return=array json
[]

$ # json.array is the same as json with json_return=array set
$ json.array
[]

$ # json.object is also defined, for consistency
$ json.object
{}
```

### Object keys

Each argument creates an entry in the JSON object. The first part of each
argument defines the key.

```console tesh-session="examples" tesh-setup=".tesh-setup"
$ json msg=hi
{"msg":"hi"}

$ # Keys can contain most characters (except @:=, and no - at the start)
$ json "🦬 says"=hi
{"🦬 says":"hi"}

$ # Key values can come from variables
$ key="The Message" json @key=hi
{"The Message":"hi"}

$ # Key variables can contain any characters
$ key="@key:with=reserved-chars" json @key=hi
{"@key:with=reserved-chars":"hi"}

$ # Each argument defines a key
$ var=c json a=X b=Y @var=Z
{"a":"X","b":"Y","c":"Z"}

$ # Keys may be reused, but should not be, because JSON parser behaviour for
$ # duplicate keys is undefined.
$ json a=A a=B a=C
{"a":"A","a":"B","a":"C"}
```

### Object values

The last part of each argument, after a `=` or `@=` defines the value. Values
can contain their value inline, or reference a variable.

```console tesh-session="examples"
$ json message="Hello World"
{"message":"Hello World"}

$ greeting="Hi there" json message@=greeting
{"message":"Hi there"}
```

Variable references without a value define the key and value in one go.

```console tesh-session="examples"
$ greeting="Hi" name=Bob json @greeting @name
{"greeting":"Hi","name":"Bob"}
```

This also works (less usefully) for inline entries.

```console tesh-session="examples"
$ json message
{"message":"message"}
```

Inline values following a `=` have no content restrictions.

```console tesh-session="examples"
$ json message=@value:with=reserved-chars
{"message":"@value:with=reserved-chars"}
```

### Arrays

$ # Creating arrays is much like creating objects – arguments can hold values

```console tesh-session="examples" tesh-setup=".tesh-setup"
$ json.array Hi "Bob Bobson"
["Hi","Bob Bobson"]

$ # As can variables
$ message=Hi name="Bob Bobson" json.array @message @name
["Hi","Bob Bobson"]

$ # Array values in arguments cannot contain @:= characters, because they would
$ # clash with @variable and :type syntax. However, values following a = can
$ # contain anything
$ json.array ='@foo:bar=baz' ='{"not":"parsed"}'
["@foo:bar=baz","{\"not\":\"parsed\"}"]

$ # Values from variables have no restrictions. Arrays use the same argument
$ # syntax as objects, so values in the key or value position work the same.
$ s1='@foo:bar=baz' s2='{"not":"parsed"}' json.array @s1 @=s2
["@foo:bar=baz","{\"not\":\"parsed\"}"]

$ # It's possible to set a key as well as value for array entries, but the key
$ # is ignored.
$ a=A b=B json.array @a@=a @b=B c=C
["A","B","C"]
```

### Value data types

```console tesh-session="examples" tesh-setup=".tesh-setup"
# Values are strings by default
json data=42 | equals_json '{data: "42"}'
# Non-string values need explicit types
json data:number=42 | equals_json '{data: 42}'
# The default string type can be changed with json_type
json_type=number json data=42 | equals_json '{data: 42}'
# In which case strings need to be explicitly typed
json_type=number json data=42 msg:string=Hi \
  | equals_json '{data: 42, msg: "Hi"}'
# true/false/null have types which don't require redundant values
json active:true enabled:false data:null \
  | equals_json '{active: true, enabled: false, data: null}'
# Regardless, they can be given values if desired
json active:true=true enabled:false=false data:null=null \
  | equals_json '{active: true, enabled: false, data: null}'
# The bool type allows either true or false values.
active=true json @active:bool enabled:bool=false \
  | equals_json '{active: true, enabled: false}'
# The auto type outputs true/false/null and number values. You can opt into
# this globally by exporting json_type=auto as an environment variable.
# JSON object and array values are not parsed with auto, only simple values.
json_type=auto json a=42 b="Hi" c=true d=false e=null f=[] g={} \
  | equals_json '{a: 42, b: "Hi", c: true, d: false, e: null,
                  f: "[]", g: "{}"}'
# auto can be used selectively like other types
data=42 json a=42 b:auto=42 c:auto@=data \
  | equals_json '{a: "42", b: 42, c: 42}'
```

### CLI

```console tesh-session="cli" tesh-setup=".tesh-setup"
$ ls -l bin
... json.array -> ../json.bash
... json.bash -> ../json.bash
... json.object -> ../json.bash
$ PATH="$(pwd)/bin:$PATH"
$ json.bash msg=Hi
{"msg":"Hi"}
$ json_type=number json.array 1 2 3 4
[1,2,3,4]
```

[jo]: https://github.com/jpmens/jo
[jq]: https://github.com/jqlang/jq
