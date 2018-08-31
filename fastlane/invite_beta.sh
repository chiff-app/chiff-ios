#!/bin/bash

echo Sending beta invitations...
read -s -p "Enter mail password for user demo and press [ENTER]: " password

for EMAIL in "$@"
do
sendEmail -f "Keyn <beta@keyn.io>" -u Keyn Beta -t $EMAIL -s mail.keyn.io:587 -xu demo -xp $password -o message-content-type=html -o message-file=beta_invite.html -o message-charset=utf-8
bundle exec fastlane pilot add $EMAIL -g "Beta A"
done

echo Done!