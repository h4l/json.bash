# Detecting errors in upstream processes via Stream Poisoning

`jb` can detect errors in upstream `jb` calls that are pulled into a downstream
`jb` process, such as when several `jb` calls are fed into each other using
[process substitution](#file-references).

```console tesh-session="error-handling-upstream-error" tesh-exitcodes="0 1"
$ # The jb call 3 levels deep reading the missing file ./not-found fails
$ jb club:json@=<(
>   jb name="jb Users" members:json[]@=<(
>     jb name=h4l; jb name@=./not-found
>   )
> )
/workspaces/json.bash/bin/jb: line ...: ./not-found: No such file or directory
json(): failed to read file referenced by argument: './not-found' from 'name@=./not-found'
json.encode_json(): not all inputs are valid JSON: '{"name":"h4l"}' $'\030'
json(): failed to encode file contents as json: '/dev/fd/...' from 'members:json[]@=/dev/fd/...'
json.encode_json(): not all inputs are valid JSON: $'\030'
json(): failed to encode file contents as json: '/dev/fd/...' from 'club:json@=/dev/fd/...'
␘
```

`jb` detects the error in the external process using _Stream Poisoning_ — a
simple in-band protocol that propagates an error signal from upstream processes
down to processes consuming their output.

The conventional pattern command-line programs use when needing to fail is to
exit with a non-zero exit status, emit nothing on stdout and an error message on
stderr.

The problem with this pattern is that a downstream program consuming the output
of a program failing upstream only has access to the stdout stream of the
program. The exit status of process failing in a sub-shell is not easily
available. (There are various caveats to this, e.g. bash provides the pipefail
option, but this only helps react to an upstream error after an operation has
completed, and doesn't help when using nested process substitution.)

`jb` takes the opinion that errors are part of the normal behaviour of `jb`, and
so it communicates errors in its normal output to stdout when it fails. This
lets `jb` propagate an error from the source, down through several intermediate
programs to the ultimate `jb` (or other JSON-processing) program. (Despite the
programs not being aware of each other.)

We call this pattern Stream Poisoning because it works by intentionally making
the JSON output of `jb` invalid by injecting a [Cancel control
character][cancel] (`\x18` / `\030` / `^X`). Control characters like Cancel are
not allowed to occur in valid JSON documents, so the presence _poisons_ the JSON
output by rendering it invalid. The _poison_ of the Cancel character will
propagate from the failed `jb` program, down through any intermediate programs
(even JSON-unaware programs handling text) until its presence causes the
most-downstream JSON-consuming program to fail.

[cancel]: https://en.wikipedia.org/wiki/Cancel_character

This is why you'll see [the Unicode visual symbol for Cancel][cancel-symbol]: ␘
after the error message when `jb` fails. Terminal programs typically don't
display a Cancel character, so when `jb` outputs an error to an interactive
terminal it prints a ␘ as well as the actual Cancel character to hint that the
output is not empty. When `jb` outputs to a non-interactive destination, like
input stream of another process, or a file, it only emits the actual Cancel
character.

[cancel-symbol]: https://en.wikipedia.org/wiki/Unicode_control_characters

```console tesh-session="error-handling-show-cancel"
$ # \030 is the octal escape for Cancel (0x18 / decimal 24)
$ jb @error | { read jbout; echo "jb stdout: ${jbout@Q}"; }
json(): argument references unbound variable: $error from '@error'
jb stdout: $'\030'
```

You might wonder why this is necessary, considering an empty string is not valid
JSON either. The trouble with that is that when we combine the outputs of
multiple programs in the shell, it's easy for the absence of output from a
failed program to go unnoticed. For example:

```console tesh-session="error-handling-hidden-error"
$ # Everything OK here — 3 things
$ jb important_things:json[]@=<(
>   echo '{"name":"Thing #1"}';
>   echo '{"name":"Thing #2"}';
>   echo '{"name":"Thing #3"}';
> )
{"important_things":[{"name":"Thing #1"},{"name":"Thing #2"},{"name":"Thing #3"}]}

$ # What if the process creating Thing #2 fails with an error? We silently loose it.
$ jb important_things:json[]@=<(
>   echo '{"name":"Thing #1"}';
>   false && echo '{"name":"Thing #2"}';  # ← 💥
>   echo '{"name":"Thing #3"}';
> )
{"important_things":[{"name":"Thing #1"},{"name":"Thing #3"}]}
```
