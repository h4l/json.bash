#!/usr/bin/env bash
set -euo pipefail

# This is a demo of using json.bash's Bash API to create a JSON payload to send
# a push notification to your phone using ntfy.sh.
# See their docs for the API: https://docs.ntfy.sh/publish/#publish-as-json
#
# (ntfy.sh is free and doesn't need registration. To use it, you install the
# mobile app and enter a unique topic name to subscribe to.)

# Import the json function (json.bash needs to be on your $PATH for source to
# find it; if it's not, use a relative or absolute path to it).
source json.bash

default_topic="json.bash_$(head -c 256 /dev/urandom | sha1sum | cut -c 1-4)"
default_title="I sent this notification"
default_message="I created this notification's JSON using json.bash"
default_tags=(json 🐚 bash)
default_priority=3

echo "Let's send a push notification using ntfy.sh"
echo "See https://docs.ntfy.sh/publish/#publish-as-json"
echo "Enter a ntfy.sh topic name to send to:"
read -e -p "topic (${default_topic:?}) " topic
echo "Enter the message title:"
read -e -p "title (${default_title:?}) " title
echo "Enter the message body:"
read -e -p "message (${default_message:?}) " message
echo "Enter some tags, separated by spaces:"
read -e -p "tags (${default_tags[*]}) " -a tags
echo "Enter the priority integer 1 = min, 5 = max:"
read -e -p "priority ($default_priority) " priority

topic=${topic:-${default_topic:?}}
title=${message:-${default_title:?}}
message=${message:-${default_message:?}}
priority=${priority:-${default_priority:?}}
tags=("${tags[@]:-"${default_tags[@]:?}"}")

# Here's where we create the ntfy.sh JSON payload with the json function:
out=actions json action=view label="json.bash repo stats" \
  url='https://github.com/h4l/json.bash/pulse'
out=notification json @topic @title @message @tags:string[] @priority:number \
  click='https://github.com/h4l/json.bash' @actions:raw[]

echo -e "\nHere's your notification JSON:"
echo "${notification:?}"
echo
echo "(Make sure you've subscribed to the topic in the ntfy mobile app.)"
read -e -p "send notification y/n? (y) " send
send=${send:-y}

if [[ ! $send =~ ^(y|yes|true)$ ]]; then echo "Not sending."; exit 0; fi

echo "Sending..."
curl -v --fail -d "${notification:?}" ntfy.sh
