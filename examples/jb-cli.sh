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

# Environment variables can be used to incrementally build JSON documents
export menuitem=$(json_type=raw jb-array \
  ="$(jb value=New onclick="CreateNewDoc()")" \
  ="$(jb value=Open onclick="OpenDoc()")" \
  ="$(jb value=Close onclick="CloseDoc()")"
)
export popup=$(jb @menuitem:raw)
export menu=$(jb id=file value=File @popup:raw)
# Environment variables can be explicitly passed without exporting globally
menu=${menu:?} jb @menu:raw

# Or nest jb calls with command substitution
jb menu:raw="$(
  jb id=file value=File popup:raw="$(
    jb menuitem:raw="$(
      json_type=raw jb-array \
        ="$(jb value=New onclick="CreateNewDoc()")" \
        ="$(jb value=Open onclick="OpenDoc()")" \
        ="$(jb value=Close onclick="CloseDoc()")"
    )"
  )"
)"

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

jb Image:raw="$(
  jb Width:number=800 Height:number=600 Title="View from 15th Floor" \
    Thumbnail:raw="$(
      jb url="http://www.example.com/image/481989943" height:number=125 \
      width:number=100
    )" \
    Animated:false IDs:raw="$(json_type=number jb-array 116 943 234 38793)"
)"

