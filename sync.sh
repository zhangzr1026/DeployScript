#!/usr/bin/expect

#Usage:
#chmod +x sync.sh
#./sync.sh

set timeout 30

spawn rsync -avzP  10.0.0.21:/tomcat/ /tomcat/

expect "password:"

send "vanelife123456!@#\r"

spawn rsync -avzP  10.0.0.21:/deploy/ /deploy/

expect "password:"

send "vanelife123456!@#\r"

interact
