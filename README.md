# `$ jb name=json.bash creates=JSON`

`json.bash` is a command-line tool and bash library that creates JSON.

```console tesh-session="intro"
$ jb name=json.bash creates=JSON dependencies:[,]=Bash,Grep
{"name":"json.bash","creates":"JSON","dependencies":["Bash","Grep"]}

$ # Values are strings unless explicitly typed
$ jb id=42 size:number=42 surname=null data:null
{"id":"42","size":42,"surname":"null","data":null}

$ # Reference variables with @name
$ id=42 date=2023-06-23 jb @id created@date modified@date
{"id":"42","created":"2023-06-23","modified":"2023-06-23"}

$ # Pull data from files
$ printf hunter2 > /tmp/password; jb @/tmp/password
{"password":"hunter2"}

$ # Pull data from shell pipelines
$ jb sizes:number[]@<(seq 1 4)
{"sizes":[1,2,3,4]}

$ # Nest jb calls
$ jb type=club members:json[]@<(jb name=Bob; jb name=Alice)
{"type":"club","members":[{"name":"Bob"},{"name":"Alice"}]}

$ # The Bash API can reference arrays and create JSON efficiently — without forking
$ source json.bash
$ out=people json name=Bob; out=people json name=Alice; sizes=(42 91 2)
$ id="abc.123" json @id @sizes:number[] @people:json[]
{"id":"abc.123","sizes":[42,91,2],"people":[{"name":"Bob"},{"name":"Alice"}]}
```

`json.bash`'s _[one thing]_ is to get shell-native data (environment variables,
files, program output) to somewhere else, using JSON encapsulate it robustly.

[one thing]: https://en.wikipedia.org/wiki/Unix_philosophy

Creating JSON from the command line or a shell script can be useful when:

- You need some ad-hoc JSON to interact with a JSON-consuming application
- You need to bundle up some data to share or move elsewhere. JSON can a good
  alternative to base64-encoding or a file archive.

It does no transformation or filtering itself, instead it pulls data from things
you **already know how to use**, like files, command-line arguments, environment
variables, shell pipelines and shell scripts. It glues together data from these
sources, giving it enough structure to make the data easy to consume reliably in
downstream programs.

It's something like a reverse `tee` — it pulls together data sources, using JSON
to represent the aggregation. It's not an alternative to to data-processing
tools like `jq`, rather it helps assemble JSON to send into JSON-consuming tools
like `jq`.

---

## Contents

1. [Install](#install)
1. [How-to guides](#how-to-guides)
1. [Background & performance notes](#background--performance-notes)
1. [Credits](#credits)

## Install

### Container image

We publish the container image
[`ghcr.io/h4l/json.bash/jb`](https://github.com/h4l/json.bash/pkgs/container/json.bash%2Fjb)
with `jb-*` and `json.bash`, perhaps useful to try without installing.

```Console
$ docker container run --rm ghcr.io/h4l/json.bash/jb msg=Hi
{"msg":"Hi"}

$ # Get a bash shell to try things interactively
$ docker container run --rm -it ghcr.io/h4l/json.bash/jb
bash-5.2# jb os-release:{}@<(xargs < /etc/os-release env -i)
{"os-release":{"NAME":"Alpine Linux","ID":"alpine","VERSION_ID":"3.18.2","PRETTY_NAME":"Alpine Linux v3.18","HOME_URL":"https://alpinelinux.org/","BUG_REPORT_URL":"https://gitlab.alpinelinux.org/alpine/aports/-/issues"}}
```

### OS Packages

Package-manager files are available for any package manager supported by
[`fpm`][fpm] (at least apk, deb, freebsd, rpm, sh (self extracting), tar,
possibly more).

We publish the container image
[`ghcr.io/h4l/json.bash/pkg`](https://github.com/h4l/json.bash/pkgs/container/json.bash%2Fpkg)
that can generate a package file in whichever format you like:

```Console
$ docker container run --rm -v "$(pwd):/pkg" ghcr.io/h4l/json.bash/pkg deb
Generating: /pkg/json.bash_0.2.2-dev.deb

$ ls
json.bash_0.2.2-dev.deb
$ dpkg -i /pkg/json.bash_0.2.2-dev.deb
```

[fpm]: https://fpm.readthedocs.io/

### Manual install

Installing manually is quite straightforward.

<details>
  <summary>Expand this for instructions</summary>

```bash
# Alternatively, use /usr/local/bin to install system-wide
cd ~/.local/bin
curl -fsSL -O "https://raw.githubusercontent.com/h4l/json.bash/HEAD/json.bash"
chmod +x json.bash
ln -s json.bash jb
ln -s json.bash jb-array

# If your shell is bash, you can alias jb and jb-array to the bash functions for
# better performance. You should add this line to your ~/.bashrc
source json.bash; alias jb=json jb-array=json.array

# Optional: if you'd also like jb-echo, jb-cat, jb-stream
for name in jb-echo jb-cat jb-stream; do
  curl -fsSL -O "https://raw.githubusercontent.com/h4l/json.bash/HEAD/bin/${name:?}"
  chmod +x "${name:?}"
done
```

To uninstall, remove `json.bash`, `jb`, `jb-array`, `jb-echo`, `jb-cat` and
`jb-stream` from the directory you installed them to (run `which -a json.bash`
to find where it is).

</details>

## How-to guides

1. [The `json.bash` commands](#the-jsonbash-commands)
1. [Object keys](#object-keys)
1. [Object values](#object-values)
1. [Arrays (mixed types, fixed length)](#arrays-mixed-types-fixed-length)
1. [Argument types](#argument-types)
1. [Array values (uniform types, variable length)](#array-values-uniform-types-variable-length)
1. [Object values (uniform types, variable length)](#object-values-uniform-types-variable-length)
1. [`...` arguments (merge entries into the host object/array)](#-arguments-merge-entries-into-the-host-objectarray)
1. [Missing / empty values](#missing--empty-values)
1. [Nested JSON with `:json` and `:raw` types](#nested-json-with-json-and-raw-types)
1. [File references](#file-references)
1. [Argument structure](#argument-structure)
1. [Error handling](#error-handling)
1. [Security and correctness](#security-and-correctness)
1. [`jb-cat`, `jb-echo`, `jb-stream` utility programs](#jb-cat-jb-echo-jb-stream-utility-programs)
1. [Streaming output](#streaming-output)

These examples mostly use `jb`, which is the `json.bash` library run as a
stand-alone program. From within a bash script you get better performance by
running `source json.bash` and using the `json` bash function, which is a
superset of stand-alone `jb` and much faster because it doesn't execute new
child processes when called. See the
[Background & performance notes](#background--performance-notes) section for
more.

### The `json.bash` commands

`jb` / `jb-array` / `json` / `json.array`

```console tesh-session="commands"
$ # The jb program creates JSON objects
$ jb
{}

$ # The jb-array creates arrays, but otherwise works like jb.
$ jb-array :number=4
[4]

$ # From a bash shell or bash script, use the json and json.array functions
$ source json.bash  # no path is needed if json.bash is on $PATH
$ json
{}

$ # json.array creates arrays, but otherwise works like json
$ json.array
[]
```

Each argument defines an entry in the object or array. Arguments can contain a
key, type and value in this structure:

<img
  width="100%"
  src="docs/syntax-diagrams/minimal-argument.svg"
  alt="A railroad syntax diagram showing a high-level summary of the key, type and value structure of an argument."
  title="Minimal Argument Structure Diagram">

The [Argument structure](#argument-structure) section has more details.

### Object keys

Each argument creates an entry in the JSON object. The first part of each
argument defines the key.

```console tesh-session="object-keys"
$ jb msg=hi
{"msg":"hi"}

$ # Keys can contain most characters (except @:=, unless escaped)
$ jb "🐚"=JSON
{"🐚":"JSON"}

$ # Key values can come from variables
$ key="The Message" jb @key=hi
{"The Message":"hi"}

$ # Key variables can contain any characters
$ key="@key:with=reserved-chars" jb @key=hi
{"@key:with=reserved-chars":"hi"}

$ # Each argument defines a key
$ var=c jb a=X b=Y @var=Z
{"a":"X","b":"Y","c":"Z"}

$ # Keys may be reused, but should not be, because JSON parser behaviour for
$ # duplicate keys is undefined.
$ jb a=A a=B a=C
{"a":"A","a":"B","a":"C"}

$ # The reserved characters can be escaped by doubling them
$ jb =@@handle=ok a::z=ok 1+1==2=ok
{"@handle":"ok","a:z":"ok","1+1=2":"ok"}
```

### Object values

The last part of each argument after a `=` or `@` defines the value. Values can
contain their value directly, or reference a variable or file.

```console tesh-session="object-values"
$ jb message="Hello World"
{"message":"Hello World"}

$ greeting="Hi there" jb message@greeting
{"message":"Hi there"}

$ # Variable references without a value define the key and value in one go.
$ greeting="Hi" name=Bob jb @greeting @name
{"greeting":"Hi","name":"Bob"}

$ # This also applies (less usefully) to inline entries.
$ jb message
{"message":"message"}

$ # Inline values following a `=` have no content restrictions.
$ jb message=@value:with=reserved-chars
{"message":"@value:with=reserved-chars"}

$ # @ values that begin with / or ./ are references to files
$ printf hunter2 > /tmp/password; jb secret@/tmp/password
{"secret":"hunter2"}

$ # File references without a value define the key and value in one go.
$ jb @/tmp/password
{"password":"hunter2"}
```

File references are more powerful than they might first appear, as they enable
all sorts of dynamic content to be pulled into JSON data, including nested `jb`
calls. See [File references](#file-references).

### Arrays (mixed types, fixed length)

Creating arrays is much like creating objects — arguments hold values, either
directly, or referencing variables or files.

```console tesh-session="arrays"
$ jb-array Hi "Bob Bobson"
["Hi","Bob Bobson"]

$ message=Hi name="Bob Bobson" jb-array @message @name
["Hi","Bob Bobson"]

$ printf 'Bob Bobson' > /tmp/name
$ jb-array Hi @/tmp/name
["Hi","Bob Bobson"]

$ # Array values in arguments cannot contain @:= characters (unless escaped by
$ # doubling them), because they would clash with @variable and :type syntax.
$ # However, values following a = can contain anything, so long as they follow a
$ # key or type section.
$ jb-array :='@foo:bar=baz' :='{"not":"parsed"}' =@@es::cap==ed
["@foo:bar=baz","{\"not\":\"parsed\"}","@es:cap=ed"]

$ # Values from variables have no restrictions. Arrays use the same argument
$ # syntax as objects, so values in the key or value position work the same.
$ s1='@foo:bar=baz' s2='{"not":"parsed"}' jb-array @s1: :@s2
["@foo:bar=baz","{\"not\":\"parsed\"}"]

$ # It's possible to set a key as well as value for array entries, but the key
$ # is ignored.
$ a=A b=B jb-array @a@a @b=B c=C
["A","B","C"]
```

`jb-array` is best for creating tuple-like arrays with a fixed number of entries
with a mix of types. Use
[value arrays](#value-arrays-uniform-types-variable-length) to create
variable-length arrays containing the same type.

`json.array` is the Bash API equivalent of `jb-array`.

### Argument types

Values are strings unless explicitly typed.

```console tesh-session="types" tesh-exitcodes="0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 1 0"
$ # These arguments are strings because they don't use a type
$ jb data=42 surname=null favourite_word=true
{"data":"42","surname":"null","favourite_word":"true"}

$ # Non-string values need explicit types
$ jb size:number=42
{"size":42}

$ # true/false/null have types which don't require redundant values
$ jb active:true enabled:false data:null
{"active":true,"enabled":false,"data":null}

$ # Regardless, they can be given values if desired
$ jb active:true=true enabled:false=false data:null=null
{"active":true,"enabled":false,"data":null}

$ # The bool type allows either true or false values.
$ active=true jb @active:bool enabled:bool=false
{"active":true,"enabled":false}

$ # The auto type outputs true/false/null and number values.
$ jb a:auto=42 b:auto=Hi c:auto=true d:auto=false e:auto=null f:auto=[] g:auto={}
{"a":42,"b":"Hi","c":true,"d":false,"e":null,"f":"[]","g":"{}"}

$ # auto can be used selectively like other types
$ data=42 jb a=42 b:auto=42 c:auto@data
{"a":"42","b":42,"c":42}

$ # In the Bash API (but not yet the jb CLI), the default type can be changed
$ # using the json_defaults option. First you create a named defaults set:
$ source json.bash
$ json.define_defaults num :number

$ # Then use the name with json_defaults when calling json to use your defaults
$ json_defaults=num json data=42
{"data":42}

$ # In which case strings need to be explicitly typed
$ json_defaults=num json data=42 msg=Hi
json.encode_number(): not all inputs are numbers: 'Hi'
json(): Could not encode the value of argument 'msg=Hi' as a 'number' value. Read from inline value.
␘

$ json_defaults=num json data=42 msg:string=Hi
{"data":42,"msg":"Hi"}
```

<details>
  <summary>Why does <code>json.bash</code> require explicit types?</summary>
  <h4>Why does <code>json.bash</code> require explicit types?</h4>
  <p>Type coercion can look good in demos, but my opinion is that in practice,
  fields are more commonly of a specific type than a union of several options,
  so coercing types by default makes it harder to achieve correct behaviour in
  the common case. The <a href="https://hitchdev.com/strictyaml/why/implicit-typing-removed/">Norway Problem</a>
  is worth reading about if you're not familiar with it.</p>

  <p>Regardless, you can make the <code>:auto</code> type the default by using <code>json_defaults</code> when calling <code>json</code> from the
  Bash API (as demonstrated above). (This isn't yet exposed through the
  <code>jb</code> CLI.)</p>
</details>

### Array values (uniform types, variable length)

Arrays of values can be created using `[]` after the `:` type marker.

```console tesh-session="array-values"
$ jb sizes:number[]=42
{"sizes":[42]}

$ # The value is split on the character inside the []
$ jb names:[,]="Alice,Bob,Dr Chris"
{"names":["Alice","Bob","Dr Chris"]}

$ # Using a newline \n as the split character makes each line an array
$ # element. This integrates with line-oriented command-line tools:
$ jb sizes:number[$'\n']="$(seq 3)"
{"sizes":[1,2,3]}
```

[File references](#file-references) with process substitution are the a better
way to get the output of other programs into JSON though.

```console tesh-session="array-values"
$ # The default type is used if the type name is left out
$ jb sizes:[,]="1,2,3"
{"sizes":["1","2","3"]}

$ # [:] is shorthand for /collection=array,split=:/
$ jb names:/collection=array,split=:/="Alice:Bob:Dr Chris"
{"names":["Alice","Bob","Dr Chris"]}

$ # To split on null bytes, use split= (empty string). When used with inline and
$ # bash values this effectively inhibits splitting, because bash variables
$ # can't contain null bytes.
$ printf 'AB\nCD\x00EF\nGH\n\x00' | jb nullterm:[]/split=/@/dev/stdin
{"nullterm":["AB\nCD","EF\nGH\n"]}

$ # When using the Bash API, @var references can be bash arrays
$ source json.bash
$ names=("Bob Bobson" "Alice Alison") sizes=(42 55)
$ json @names:string[] @sizes:number[]
{"names":["Bob Bobson","Alice Alison"],"sizes":[42,55]}

$ # json.array values can be arrays too
$ json.array @names:string[] @sizes:number[] :null[] :bool[]=true
[["Bob Bobson","Alice Alison"],[42,55],[null],[true]]

$ # And jb-array values can be arrays as well
$ jb-array :[,]="Bob Bobson,Alice Alison" :number[,]=42,55 :null[] :bool[]=true
[["Bob Bobson","Alice Alison"],[42,55],[null],[true]]
```

Arrays can be created from existing JSON arrays using the `[:json]` array
format:

```console tesh-session="array-values"
$ jb tags:[:json]="$(jb-array foo bar baz)"
{"tags":["foo","bar","baz"]}

$ # The type of values in the argument's array must match the argument type
$ jb measures:number[:json]='[1,2,3,4]'
{"measures":[1,2,3,4]}

$ # Otherwise an error occurs
$ jb measures:number[:json]='[1,2,"oops"]'
json.encode_array_entries_from_json(): provided entries are not all valid JSON arrays with 'number' values — '[1,2,"oops"]'
json(): Could not encode the value of argument 'measures:number[:json]=[1,2,"oops"]' as an array with 'number' values. Read from inline value, without splitting (one chunk), interpreted chunks with 'json' format.
␘
```

### Object values (uniform types, variable length)

Variable-length JSON objects can be created using `{}` after the `:` type
marker. Object values use the same `key=value` syntax used in arguments'
attributes section (`:/a=b,c=d/`).

```console tesh-session="object-values"
$ # The default type is used if the type name is left out
$ jb sizes:{}=small=s,medium=m,large=l
{"sizes":{"small":"s","medium":"m","large":"l"}}

$ jb measurements:number{}=small=5,medium=10,large=15
{"measurements":{"small":5,"medium":10,"large":15}}
```

Like array values (`[]`), object values consume multiple lines of input when
reading files

```console tesh-session="object-values"
$ # env is a command-line tool that prints environment variables
$ env -i small=s medium=m large=l
small=s
medium=m
large=l

$ # We can encode variables from env as a JSON object
$ env -i small=s medium=m large=l | jb sizes:{}@/dev/stdin
{"sizes":{"small":"s","medium":"m","large":"l"}}
```

As with array values, JSON data can be used as values:

```console tesh-session="object-values"
$ jb user=h4l repo=json.bash >> info
$ jb @./info:{:json}
{"info":{"user":"h4l","repo":"json.bash"}}

$ jb file_types:string[,]=bash,md,hcl year_created:number=2023 >> info
$ # The values of the JSON objects are validated to match the argument's type,
$ # so the :json type must be used to consume arbitrary JSON
$ jb @./info:json{:json}
{"info":{"user":"h4l","repo":"json.bash","file_types":["bash","md","hcl"],"year_created":2023}}
```

### `...` arguments (merge entries into the host object/array)

An argument prefixed with `...` (commonly called splat, spread or unpacking in
programming languages) results in the argument's entries being merged directly
into the object or array being created.

```console tesh-session="splat"
$ jb id=ab12 ...:=user=h4l,repo=json.bash ...:number=year=2023,min_radish_count=3
{"id":"ab12","user":"h4l","repo":"json.bash","year":2023,"min_radish_count":3}

$ seq 5 8 | jb-array :number=0 ...:number[,]=1,2,3,4 ...:number@/dev/stdin
[0,1,2,3,4,5,6,7,8]
```

### Missing / empty values

References to undefined variables, missing files or unreadable files are missing
values. Empty array variables, empty string variables, empty files and empty
argument values are empty values.

Missing or empty keys or values are errors by default, apart from empty argument
values, like `foo=`.

The flags `+` `~` `?` and `??` alter how missing/empty values behave.

| Flag | Name             | Effect                                          |
| ---- | ---------------- | ----------------------------------------------- |
| `+`  | strict           | All missing/empty values are errors.            |
| `~`  | optional         | Missing files/variables are treated as empty.   |
| `?`  | substitute empty | Empty values are substituted with a default.    |
| `??` | omit empty       | Entries with an empty key or value are omitted. |

```console tesh-session="missing-empty"
$ # empty argument values are substituted by default
$ jb str= num:number= bool:bool= arr:[]= obj:{}=
{"str":"","num":0,"bool":false,"arr":[],"obj":{}}

$ # Using ? substitutes the empty var for the default string, which is ""
$ empty= jb @empty?
{"empty":""}

$ # The empty attribute controls the default value. It's interpreted as JSON.
$ CI=true jb ci:bool/empty=false/?@CI
{"ci":true}

$ CI= jb ci:true/empty=false/?@CI
{"ci":false}

$ # empty_key controls the default value for empty keys
$ PROP= jb ?@PROP:true/empty_key='"🤷"'/
{"🤷":true}

$ # The type= can be used to encode a raw value as JSON for empty attributes
$ PROP=👌 jb ?@PROP:true/empty_key=string=🤷/
{"👌":true}

$ # ?? causes an empty value to be omitted entirely
$ CI= jb ci:bool??@CI
{}

$ # ~ causes a missing value to be empty. A ? is needed to prevent the empty
$ # value being an error.
$ jb github_actions:bool~?@GITHUB_ACTION
{"github_actions":false}

$ # Empty variables are errors if ? isn't used.
$ empty= jb @empty
json.apply_empty_action(): The value of argument '@empty' must be non-empty but is empty.
json(): Could not encode the value of argument '@empty' as a 'string' value. Read from variable $empty. (Use the '?' flag after the :type to substitute the entry's empty value with a default, or the '??' flag to omit the entry when it has an empty value.)
␘

$ # (Only the json Bash function, not the jb executable can access bash array variables.)
$ . json.bash
$ empty_array=()

$ # Using ? substitutes the empty array for the default, which is []
$ json @empty_array:[]?
{"empty_array":[]}

$ # Empty arrays are errors without ?.
$ json @empty_array:[]
json.apply_empty_action(): The value of argument '@empty_array:[]' must be non-empty but is empty.
json(): Could not encode the value of argument '@empty_array:[]' as an array with 'string' values. Read from array-variable $empty_array. (Use the '?' flag after the :type to substitute the entry's empty value with a default, or the '??' flag to omit the entry when it has an empty value.)
␘

$ # Missing / empty files work like variables
$ jb @./config:/empty=null/~?
{"config":null}
```

### Nested JSON with `:json` and `:raw` types

Nested objects and arrays are created using the `:json` or `:raw` types. The
`:json` type validates the provided value(s) and fails if they're not actually
JSON, whereas the `:raw` type allow _any_ value to be inserted (even invalid
JSON).

The reason for both is that `:json` depends on grep (with PCRE) being present,
so `:raw` can be used in situations where only bash is available, and validation
isn't necessary (e.g. when passing the output of one `json.bash` call into
another). `:raw` also supports [streaming output](#streaming-output), which
`:json` does not.

```console tesh-session="nested-json"
$ # Like other types, :json and :raw values can be directly embedded in arguments
$ jb user:json='{"name":"Bob Bobson"}'
{"user":{"name":"Bob Bobson"}}

$ # Or come from variable references
$ user='{"name":"Bob Bobson"}' jb @user:json
{"user":{"name":"Bob Bobson"}}

$ # Or files
$ jb name="Bob Bobson" > /tmp/user; jb @/tmp/user:json
{"user":{"name":"Bob Bobson"}}

$ # Arrays of JSON work the same way as other types.
$ jb users:json[$'\n']="$(jb name=Bob; jb name=Alice)"
{"users":[{"name":"Bob"},{"name":"Alice"}]}

$ # :json and :raw values are not formatted — whitespace in them is preserved
$ jb user:json=$'{\n  "name": "Bob Bobson"\n}'
{"user":{
  "name": "Bob Bobson"
}}

$ # :json detects invalid JSON and fails with an error
$ jb oops:json='{"truncated":'
json.encode_json(): not all inputs are valid JSON: '{"truncated":'
json(): Could not encode the value of argument 'oops:json={"truncated":' as a 'json' value. Read from inline value.
␘

$ # However :raw performs no validation, so it must only be used with great care
$ # 🚨 This emits invalid JSON without failing! 🚨
$ jb broken:raw='{"truncated":'
{"broken":{"truncated":}
```

### File references

The `@ref` syntax can be used to reference the content of files. If an ` @ref`
starts with `/` or `./` it's taken to be a file (rather than a shell variable).

```console tesh-session="file-references"
$ printf 'orange #3\nblue #5\n' > colours

$ jb my_colours@./colours
{"my_colours":"orange #3\nblue #5\n"}

$ # The final path segment is used as the key if a key isn't set.
$ jb @./colours
{"colours":"orange #3\nblue #5\n"}

$ # Array values split on newlines
$ jb @./colours:[]
{"colours":["orange #3","blue #5"]}

$ printf 'apple:pear:grape' > fruit

$ # The file can be split on a different character by naming it in the []
$ jb @./fruit:[:]
{"fruit":["apple","pear","grape"]}

$ # Which is shorthand for
$ jb @./fruit:/collection=array,split=:/
{"fruit":["apple","pear","grape"]}

$ # Split on null by setting split to the empty string
$ printf 'foo\nbar\n\x00bar baz\n\x00' > nullterminated
$ jb @./nullterminated:[]/split=/
{"nullterminated":["foo\nbar\n","bar baz\n"]}

$ # Read from stdin using the special /dev/stdin file
$ seq 3 | jb counts:number[]@/dev/stdin
{"counts":[1,2,3]}
```

File references become especially powerful when combined with process
substitution — a shell feature that provides a dynamic, temporary file
containing the output of another program.

```console tesh-session="file-references"
$ # Use process substitution to nest jb calls and pull multiple shell pipelines
$ # into one JSON output.
$ jb counts:number[]@<(seq 3) \
>    people:json[]@<(jb name=Bob; jb name=Alice)
{"counts":[1,2,3],"people":[{"name":"Bob"},{"name":"Alice"}]}
```

#### Aside: Process substitution 101

```Console tesh-session="psub-101"
$ # What's going on when we use process substitution? The <(...) syntax.
$ jb msg@<(printf "Hi!")
{"msg":"Hi!"}

$ # The shell replaces <(...) with a file path. That file contains the output of
$ # the command inside the <(...) when read. (But the catch is, the file only
$ # exists while the command runs, and it's not a normal file, so the contents
$ # isn't stored on disk.)

$ # We can see this if we echo the the substitution:
$ echo This is the substitution result: <(printf "Hi!")
This is the substitution result: /dev/fd/...

$ # If we cat the substitution instead of echoing it, we read the file contents:
$ cat <(printf "Hi!")
Hi!

$ # So when we use this with jb, it's as if we ran:  jb msg@/dev/fd/...

$ # We can see this in action by enabling tracing in Bash:
$ set -o xtrace;  jb msg@<(printf "Hi!");  set +o xtrace
+ jb msg@/dev/fd/...
++ printf 'Hi!'
{"msg":"Hi!"}
+ set +o xtrace
```

Because `<(...)` becomes a path, you don't _have_ to quote it, which makes
forming commands a bit easier than using _command substitution_ to do the same
thing (`echo "$(printf like this)"`). And you only pass a short file path as an
argument, not a potentially huge string.

#### Back to file references

```console tesh-session="file-references"
$ # Process substitution can nest multiple times
$ jb owners:json@<(
>   jb people:json[]@<(jb name=Bob; jb name=Alice)
> )
{"owners":{"people":[{"name":"Bob"},{"name":"Alice"}]}}

$ # Files can be referenced indirectly using a shell variable.
$ # If @var is used and $var is not set, but $var_FILE is, the filename is read
$ # from $var_FILE and the content of the file is used.
$ printf 'secret123' > db_password
$ db_password_FILE=./db_password jb @db_password
{"db_password":"secret123"}
```

(This pattern is often used to securely pass secrets via environment variables,
[without directly exposing the secret's value itself in the environment](#environment-variable-exposure),
to avoid accidental exposure.)

```console tesh-session="file-references"
$ # Nesting lots of process substitution levels can become unwieldy, but we can
$ # flatten the nesting by holding the process substitution filenames in shell
$ # variables, using the _FILE var feature to reference them:
$ people_FILE=<(jb name=Bob; jb name=Alice) \
> owners_FILE=<(jb @people:json[]) \
> jb @owners:json
{"owners":{"people":[{"name":"Bob"},{"name":"Alice"}]}}
```

### Argument structure

Arguments have 3 main parts: a key, type and value. The structure (omitting some
details for clarity) is:

<img
  width="100%"
  src="docs/syntax-diagrams/approximate-argument.svg"
  alt="A railroad syntax diagram showing the key, type and value structure of an argument, in more detail than the minimal argument diagram, but still omitting some details."
  title="Approximate Argument Structure Diagram">

The [Argument syntax](docs/syntax.md) page has more detail.

### Error handling

`json.bash` aims to fail quickly, cleanly and clearly when problems happen.

> Please open an issue if you discover a case where an error goes unreported, is
> not reported clearly, or you find it's not easy to prevent incorrect data
> getting generated.

Invalid values in typed arguments will cause an error — values are not coerced
if a type is specified. `:bool` and `:null` are pedantic — values must be
exactly `true` / `false` / `null`.

```console tesh-session="error-handling-start" tesh-exitcodes="1"
$ active=tRuE jb @active:bool
json.encode_bool(): not all inputs are bools: 'tRuE'
json(): Could not encode the value of argument '@active:bool' as a 'bool' value. Read from variable $active.
␘
```

Errors are reported with specific exit statuses:

```console tesh-session="error-handling"
$ # Errors in user-provided data fail with status 1
$ jb data:json='invalid'; echo status=$?
json.encode_json(): not all inputs are valid JSON: 'invalid'
json(): Could not encode the value of argument 'data:json=invalid' as a 'json' value. Read from inline value.
␘
status=1

$ # Errors in developer-provided arguments fail with status 1
$ jb bad_arg:cheese; echo status=$?
json.parse_argument(): type name must be one of auto, bool, false, json, null, number, raw, string or true, but was 'cheese'
json(): Could not parse argument 'bad_arg:cheese'. Argument is not structured correctly, see --help for examples.
␘
status=2

$ # Arguments referencing variables that don't exist fail with status 3
$ jb @missing; echo status=$?
json(): Could not process argument '@missing'. Its value references unbound variable $missing. (Use the '~' flag after the :type to treat a missing value as empty.)
␘
status=3

$ # Arguments referencing files that don't exist fail with status 4
$ jb @/does/not/exist; echo status=$?
/.../bin/jb: line ...: /does/not/exist: No such file or directory
json(): Could not open the file '/does/not/exist' referenced as the value of argument '@/does/not/exist'.
␘
status=4
```

`jb` can detect errors in upstream `jb` calls that are pulled into a downstream
`jb` process, such as when several `jb` calls are fed into each other using
[process substitution](#file-references).

```console tesh-session="error-handling-upstream-error" tesh-exitcodes="0 1"
$ # The jb call 3 levels deep reading the missing file ./not-found fails
$ jb club:json@<(
>   jb name="jb Users" members:json[]@<(
>     jb name=h4l; jb name@./not-found
>   )
> )
...: ./not-found: No such file or directory
json(): Could not open the file './not-found' referenced as the value of argument 'name@./not-found'.
json.encode_json(): not all inputs are valid JSON: '{"name":"h4l"}' $'\030'
json(): Could not encode the value of argument 'members:json[]@/dev/fd/...' as an array with 'json' values. Read from file /dev/fd/..., split into chunks on $'\n', interpreted chunks with 'raw' format.
json.encode_json(): not all inputs are valid JSON: $'\030'
json(): Could not encode the value of argument 'club:json@/dev/fd/...' as a 'json' value. Read from file /dev/fd/..., up to the first 0x00 byte or end-of-file.
␘
```

Notice the [␘][cancel-symbol] symbol in the output? It's the Unicode symbol for
the [Cancel control character][cancel].

[cancel-symbol]: https://en.wikipedia.org/wiki/Unicode_control_characters
[cancel]: https://en.wikipedia.org/wiki/Cancel_character

`jb` propagates errors by emitting a [Cancel control character][cancel] when it
fails, which causes its output to be invalid JSON, which prevents the erroneous
output from being parsed by downstream JSON-consuming programs (`jb` or
otherwise). We call this Stream Poisoning, because the Cancel control character
poisons the output, and this poisoned output flows downstream until it's
detected.

The result of this is that it's safe to pipe the output of a `jb` program into
another JSON-consuming program, with the knowledge that you'll get an error if
something has failed upstream, without needing to meticulously collect and check
the every exit status of every program contributing to the output.

See [docs/stream-poisoning.md](docs/stream-poisoning.md) for more on how this
works.

### Security and correctness

`jb` can safely generate JSON from untrusted user input, but there are some ways
to get this wrong.

It's safe to use untrusted input in:

- Inline values — after the value's `=` in an argument.

  With argument `key:type=value` Anything after the value's `=` in an argument
  is used as-is and not interpreted/unescaped, so it can contain untrusted
  input.

  The `=` must be preceded by a key or `:` (type section marker), otherwise an
  argument starting with a `=` such as `=foo` is parsed as a key, which could
  allow text inserted into the argument to be parsed as the value if not escaped
  correctly.

- Variable references — the _value_ held in a variable referenced by an
  argument.

  With argument `@foo`, the value of `$foo` is is used as-is and not
  interpreted/unescaped, so it can contain untrusted input.

- File references — the contents of a file referenced by a argument.

  The contents of files is not interpreted/unescaped, so they can contain
  untrusted input.

In general, avoid inserting user-provided input into the argument string passed
to jb before the value's `=`. To create dynamic object property names from user
input, store the user-provided value in a variable or file, and use an `@ref` to
reference it:

```console tesh-session="safe-dynamic-prop"
$ dynamic_prop='Untrusted' jb @dynamic_prop=value
{"Untrusted":"value"}
```

If you format user-input into an argument string, they could insert an `@ref` of
their choice, and pull in a file or variable they shouldn't have access to. You
can escape special characters in argument values by doubling characters, but
it's safer to use an `@ref` — if you get an `@ref` wrong you get an error,
whereas if you get escaping wrong, you may create a vulnerability.

References are not supported when specifying argument attributes, like
`/empty=x/`, so `,` in these values needs to be escaped by doubling it. E.g. to
use a comma as a split char, use `/empty=string='Why,, yes.'/`:

```console tesh-session="split-comma"
$ empty= jb msg:/empty=string='Why,, yes.'/??@empty
{"msg":"Why, yes."}
```

To pass a dynamic file location, use a `_FILE` variable reference or read the
file with a normal shell construct and redirect the input. You must also
separately validate that the referenced file should be accessible.

```console tesh-session="dynamic-file"
$ printf 'Example\nContent\n' > /tmp/example
$ user_file=/tmp/example

$ user_specified_FILE=$user_file jb user_file_content@user_specified
{"user_file_content":"Example\nContent\n"}

$ jb user_file_content@<(cat "$user_file")
{"user_file_content":"Example\nContent\n"}

$ jb user_file_content="$(<"$user_file")"  # $() strips the trailing newline
{"user_file_content":"Example\nContent"}
```

#### Environment variable exposure

`jb` `@var` refs have the advantage over normal shell `$var` refs in that they
are not expanded by the shell before executing the command, so sensitive values
in shell variables are not exposed as process arguments when using `@var`:

```console tesh-session="arg-value-leak"
$ password=hunter2

$ # shell $var — secret's value is in process arguments
$ jb password="$password" visible_args:[]/split=/@/proc/self/cmdline
{"password":"hunter2","visible_args":["bash","/.../bin/jb","password=hunter2","visible_args:[]/split=/@/proc/self/cmdline"]}

$ # jb @var — only the variable name is in process arguments
$ password=$password jb @password visible_args:[]/split=/@/proc/self/cmdline
{"password":"hunter2","visible_args":["bash","/.../bin/jb","@password","visible_args:[]/split=/@/proc/self/cmdline"]}
```

### `jb-cat`, `jb-echo`, `jb-stream` utility programs

`json.bash` has a few single-purpose utility programs that were originally demo
programs for the Bash API, but could be use useful by themselves:

```console tesh-session="jb-utils"
$ # jb-echo is like echo, but each argument becomes a string element in a JSON array
$ jb-echo foo "bar baz" boz
["foo","bar baz","boz"]

$ printf 'The Cat\nsat on\nthe mat.\n' > catmat
$ printf 'The Bat\nhid in\nthe hat.\n' > bathat

$ # jb-cat is like cat, but the output is stream-encoded as a single JSON string
$ jb-cat catmat bathat
"The Cat\nsat on\nthe mat.\nThe Bat\nhid in\nthe hat.\n"

$ # jb-stream is a filter program that encodes each input line as a JSON string
$ cat catmat bathat | jb-stream
"The Cat"
"sat on"
"the mat."
"The Bat"
"hid in"
"the hat."
```

### Streaming output

By default `jb` collects output in a buffer and outputs it all at once at the
end. This has the advantage that it does not emit partial output if an error
occurs mid-way through.

However, setting the `JSON_BASH_STREAM=true` makes `jb` output content
incrementally. `jb` can stream-encode values it's pulling from file references:

- Single string values from files are stream-encoded
- Arrays of any type coming from files are stream-encoded (individual elements
  are fully buffered), but elements are emitted incrementally
- `:raw` values from files are streamed

`:json` values can't be streamed unfortunately — `jb` (ab)uses grep to validate
JSON using PCRE's recursive matching features, but sadly grep buffers complete
inputs, even when backtracking and matched-region output are disabled.

### Argument syntax details

The full syntax of `jb` arguments is documented in a (pseudo) grammar in
[hack/syntax_patterns.bash](hack/syntax_patterns.bash).

## Background & performance notes

Quite reasonably, you may be wondering why anyone would use Bash to implement a
JSON encoder. Won't that be ridiculously slow? I thought so too. Initially, I
just wanted to encode JSON strings from Bash without needing to depend on a
separate program. My initial few attempts at this were indeed hideously slow.
But after a few iterations I was able to get decent performance by operating
only on entire strings (or arrays of strings) (not byte-by-byte, or
string-by-string for arrays), and absolutely avoiding any forking of subshells.

If you don't fork, and minimise the number of Bash-level operations, Bash can do
surprisingly well. Of course, performance still can't compare with a C program.
Well, that depends what you're measuring. Because starting a new process can be
surprisingly slow. So a race between `json.bash` and program like [`jq`][jq] or
[`jo`][jo] is a bit like a 100m race between a tortoise and a hare, where the
tortoise gets a 1 hour headstart.

If you care about latency rather than throughput, calling `json` from an
already-running Bash script is a little faster than running a separate `jo`
process. And significantly faster than running `jq`, which is really slow to
start.

There's a very basic benchmark script at
[hack/hot_loop.bash](hack/hot_loop.bash):

```
$ time hack/hot_loop.bash json.bash 10000 > /dev/null
json.bash

real    0m8.193s
user    0m8.174s
sys     0m0.019s

$ time hack/hot_loop.bash jo 10000 > /dev/null
jo

real    0m9.393s
user    0m2.566s
sys     0m7.386s

$ # Note: 1000 not 10_000
$ time hack/hot_loop.bash jq 1000 > /dev/null
jq

real    0m20.453s
user    0m19.127s
sys     0m1.386s
```

If we just use `json.bash`'s `json.encode_string` encoding function to manually
construct the JSON (not the full argument parsing stuff) we can do a lot better
still:

```
$ time hack/hot_loop.bash custom-json.bash 10000 > /dev/null
custom-json.bash

real    0m1.901s
user    0m1.891s
sys     0m0.011s
```

This kind of purpose-specific encoding is what I had in mind when I started
this. I was calling `jq` lots of times from a Bash script, finding it to be very
slow, and wondering if I could start a single `jq` process and make a kind of
tiny RPC protocol, sending it JSON from the Bash script to avoid the startup
delay on each operation. That would require some ability to encode JSON from
Bash.

I wasn't planning to write something comparable to `jo` when I started, but idea
of a `jo`-like program that only depends on bash kind of appealed to me. Maybe I
should port it to a more suitable language though. The program is a now a lot
larger in size and scope than I originally anticipated when starting, I
certainly wouldn't have written it in bash if I'd known how large it'd become.
🙃

[jo]: https://github.com/jpmens/jo
[jq]: https://github.com/jqlang/jq

## Credits

- [jo] for the general idea of a command-line program that generates JSON
- [tesh] which automatically runs and tests the command-line output examples
  here — it would not be at all practical to maintain these kind of examples
  without it. With tesh the examples become a beneficial second layer of tests,
  rather than a maintenance burdon.
- [jq] for making it pleasant to use with JSON on the command-line and in shell
  scripts

[tesh]: https://github.com/OceanSprint/tesh
