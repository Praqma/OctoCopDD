---
maintainer: 
- buep
- KamranAzeem
---

# OctoCop (Traffic) Director for Docker

OCDD makes the life of any IT administrator easy. 

OCDD sets up DNS on the host it is run on. It is expected from the IT department that they give us a subdomain such as toolbox.example.com and ddelegate management of that domain to us through this server - dockerhost.example.com . This is the best way to run the apps, as then IT doesn't need to be bothered with anything.

Also, it is expected that IT department will provide us with a range of IP addresses for our use, which no one else uses on the network. This way we can setup forwarding rules to all the containers running on dockerhost.

For a demo do the following steps:
* Install docker, docker-compose and jq on the host, on which you want to run ocdd.
* If running as ordinary user, then the user needs to have sudo privileges. Better run as root.
* Adjust ocdd.conf
* Make sure that the directories/paths listed in ocdd.conf exist, and are writeable by the user running the ocdd.sh script.
* Bring up the docker-compose application provided by this repo. (`docker-compose up -d`) 
* [optional] Bring up any other (additional) docker-compose application on this host, such as staci. (`cd ../staci; docker-compose up -d`) (in case of stai wait for significant amount of time ! :)
* Run "./ocdd.sh initialize" when run for the first time.
* Run ./ocdd.sh , which will setup IP addresses, IP Tables rules and DNS.
* Try reaching those services using the IP addresses and the dns names from an external computer. That external computer needs to have it's DNS resolv.conf file pointing to this server.

Also:
* OCDD comes with sample application suite which includes a (mandatory) DNS, and a network-toolkit, helpful in troubleshooting.
* Whenever the application suites / containers change on the dockerhost, simply run "./ocdd" again.

Run some docker containers on the host and then run `ocdd.sh` . There is no need to expose any ports of the docker containers. Though you are allowed to use `-P` ( or even `-p port:port` ) in the docker run command to expose the container ports on the host. These ports do not matter at all and OCDD does not consider them. The magic is in the iptables rules, not the exposed ports of the containers.

Ideally, you should run all your containers through docker-compose. That is the preferred way. If you don't do it through docker-compose, then you will not get service names in DNS.

When `ocdd.sh` finishes running, it will setup additional IP addresses on the docker host, and will setup necessary forwarding rules. These rules can be listed using `sudo iptables-save | grep OCDD` . You will see which IP is handling which container , by looking at the rules. This will be made more user friendly in the coming days.

You can use `dig axfr toolbox.example.com @127.0.0.1` on the dockerhost to obtain the complete zone information. This is helpful to know which DNS entries are setup in the DNS server on the dockerhost.

This is kind of version 1. In coming days , I will further simplify the logic and will add capability to update DNS too. 

Enjoy! 

# Future work / To Do:
* Setup a cron job to monitor changes in the docker system. Right now you need to run ./ocdd.sh each time you make changes to your docker-compose application suite.
* Watch for changes in docker-compose, and only act if there are changes reported by docker API. 
