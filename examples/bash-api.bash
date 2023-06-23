#!/usr/bin/env bash
set -euo pipefail
source json.bash

# Some examples of generating sample JSON data with the json.bash Bash API
# Compare with ./jb-cli.sh

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
printf "\njson.bash Bash API:\n"

# menuitem is an auto-created bash array
out=menuitem json value=New onclick="CreateNewDoc()"
out=menuitem json value=Open onclick="OpenDoc()"
out=menuitem json value=Close onclick="CloseDoc()"
out=popup json @menuitem:raw[]
out=menu json id=file value=File @popup:raw
json @menu:raw

printf '\n\n'
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
printf "\njson.bash Bash API:\n"

IDs=(116 943 234 38793)
out=Thumbnail json url="http://www.example.com/image/481989943" \
  height:number=125 width:number=100
out=Image json Width:number=800 Height:number=600 Title="View from 15th Floor" \
  @Thumbnail:raw Animated:false @IDs:number[]
json @Image:raw

printf '\n'
