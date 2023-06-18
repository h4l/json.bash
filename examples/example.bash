#!/usr/bin/env bash
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../json.bash"

# We'll create this random example from json.org
# https://json.org/example.html
# {
#   "menu": {
#     "id": "file",
#     "value": "File",
#     "popup": {
#       "menuitem": [
#         {
#           "value": "New",
#           "onclick": "CreateNewDoc()"
#         },
#         {
#           "value": "Open",
#           "onclick": "OpenDoc()"
#         },
#         {
#           "value": "Close",
#           "onclick": "CloseDoc()"
#         }
#       ]
#     }
#   }
# }

menu="$(
    popup="$(
        menuitem="$(
            new="$(value=New onclick="CreateNewDoc()" json value onclick)"
            open="$(value=Open onclick="OpenDoc()" json value onclick)"
            close="$(value=Close onclick="CloseDoc()" json value onclick)"
            json_type=array json new:raw open:raw close:raw
        )"
        json menuitem:raw
    )"
    id=file value=File json id value popup:raw
)" \
json menu:raw

# https://datatracker.ietf.org/doc/html/rfc8259#section-13
# {
#   "Image": {
#     "Width": 800,
#     "Height": 600,
#     "Title": "View from 15th Floor",
#     "Thumbnail": {
#       "Url": "http://www.example.com/image/481989943",
#       "Height": 125,
#       "Width": 100
#     },
#     "Animated": false,
#     "IDs": [
#       116,
#       943,
#       234,
#       38793
#     ]
#   }
# }
ids=(116 943 234 38793)  # can't define arrays inline
image="$(
    width=800 height=600 title="View from 15th Floor"
    thumbnail="$(
        url="http://www.example.com/image/481989943" height=125 width=100
        json url=Url height=Height width=Width
    )"
)" \
# TODO: consider using this variant syntax name:type=value where name and value
#   are literals, but can be @var references. On the CLI they can refer to
#   envars.
# Allow execution via CLI.
json image:raw "My Thing":number=42 "Other Thing":string=@foo

things=("Red Apples" $'Blue Turnips\n🍲\n' $'\u0001\n')
name="Joe Bloggs" answer=42 json \
    yes:true _:true="Of course" \
    no:false _:false="Certainly not" \
    nothing:null \
    name name:array=names \
    answer answer:string=string_answer answer:array=array_answer