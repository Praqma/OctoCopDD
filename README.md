# OctoCop (Traffic) Director for Docker

For a demo do the following steps:
* Bring up the docker-compose application provided by this repo
* Run "./ocdd.sh initialize" when run for the first time.
* Run ./ocdd.sh , which will setup IP addresses, IP Tables rules and DNS.

Run some docker containers on the host and then run `ocdd.sh` . There is no need to expose any ports of the docker containers. Though you are encourged to use `-P` in the docker run command to expose the container ports on any randomly chosen ports on the host. These ports do not matter at all and the load balancer does not account for them. The magic is in the iptables rules, not the exposed ports of the containers.

Ideally, you should run all your containers through docker-compose. That is the preferred way. If you don't do it through docker-compose, then you will not get service names in DNS.

When `ocdd.sh` finishes running, it will setup additional IP addresses on the docker host, and will setup necessary forwarding rules. These rules can be listed using `sudo iptables-save | grep PRAQMA` . You will see which IP is handling which container , by looking at the rules. This will be made more user friendly in the coming days.

This is kind of version 1. In coming days , I will further simplify the logic and will add capability to update DNS too. 

Enjoy! 

# Future work / To Do:
* Introduce pushd and popd, so the program can be run from anywhere on the filesystem. Right now you need to change directory into the project directory.
* Clean up code. Some places still have hard coded file names.
* Clean up / remove files that are not needed anymore.
* Setup a cron job to monitor changes in the docker system. Right now you need to run ./ocdd.sh each time you make changes to your docker-compose application suite.
* Watch for changes in docker-compose, and only act if there are changes reported by docker API. 
