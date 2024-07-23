#!/usr/bin/env bash
set -euo pipefail

# Some examples of generating sample JSON data with the json.bash jb CLI
# Compare with ./bash-api.bash

cat <<EOT
Example: json.org https://json.org/example.html
{
  "menu": {
    "id": "file",
    "value": "File",
    "popup": {
      "menuitem": [
        {
          "value": "New",
          "onclick": "CreateNewDoc()"
        },
        {
          "value": "Open",
          "onclick": "OpenDoc()"
        },
        {
          "value": "Close",
          "onclick": "CloseDoc()"
        }
      ]
    }
  }
}
EOT
printf "\njson.bash jb CLI:\n"

# jb's @/file references combined with shell process substitution allow jb
# calls to nest:
jb menu:json@<(
  jb id=file value=File popup:json@<(
    jb menuitem:json[]@<(
      jb value=New onclick="CreateNewDoc()"; \
      jb value=Open onclick="OpenDoc()"; \
      jb value=Close onclick="CloseDoc()"
    )
  )
)

# Or nest jb calls with command substitution
jb menu:json="$(
  jb id=file value=File popup:json="$(
    jb menuitem:json[$'\n']="$(
      jb value=New onclick="CreateNewDoc()"; \
      jb value=Open onclick="OpenDoc()"; \
      jb value=Close onclick="CloseDoc()"
    )"
  )"
)"

# Environment variables can be used to incrementally build JSON documents
export menuitems=$(
  jb value=New onclick="CreateNewDoc()"; \
  jb value=Open onclick="OpenDoc()"; \
  jb value=Close onclick="CloseDoc()"
)
# Or temporary files
tmp=$(mktemp -d)
jb menuitem:json[$'\n']@menuitems > "${tmp:?}/popup"  # the filename is used as the key
export menu=$(jb id=file value=File @"${tmp:?}"/popup:json)
# Environment variables can be explicitly passed without exporting globally
menu=${menu:?} jb @menu:json

printf '\n'
cat <<EOT
Example: https://datatracker.ietf.org/doc/html/rfc8259#section-13
{
  "Image": {
    "Width": 800,
    "Height": 600,
    "Title": "View from 15th Floor",
    "Thumbnail": {
      "Url": "http://www.example.com/image/481989943",
      "Height": 125,
      "Width": 100
    },
    "Animated": false,
    "IDs": [
      116,
      943,
      234,
      38793
    ]
  }
}
EOT
printf "\njson.bash jb CLI:\n"

jb Image:json@<(
  jb Width:number=800 Height:number=600 Title="View from 15th Floor" \
    Thumbnail:json@<(
      jb url="http://www.example.com/image/481989943" height:number=125 \
      width:number=100
    ) \
    Animated:false "IDs:number[ ]=116 943 234 38793"
)
