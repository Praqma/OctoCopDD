---
title:      Introducing OctoCop; DNS based directory for docker.
subtitle:   Stop bothering your IT administrators everytime you want to launch a new service.
author:     KamranAzeem
comments:   true
tags:
  - Docker
  - Containers
  - Featured
avatar:     /images/stories/
nav-weight: 5
published: false
---
OctoCop DD or OCDD for short is a tool to make the life of IT administrators easy in situations when CoDers want to setup a CoDe (Continuous Delivery) server.
{: .kicker }
<!--break-->


![](ocdd-temp-logo.jpg)

# OctoCop Directory for Docker (OCDD)

[OCDD](https://github.com/praqma/octocopdd) is not a proxy, and is not a load balancer. It is merely a traffic re-director - thus the name.

# The itch:
It all started during one of Praqma's super-cool CoDe camps. A colleague of mine described a situation and wanted to have a solution for it: 

As a [CoDer](http://www.praqma.com/training/code-kickstart/) he had to provide and setup a server in some company which was supposed to run Jenkins, Artifactory and a few other software tools. The problem was that these tools were running on that server as Docker containers, and asking IT department to assign a IP address to these services and updating their DNS was proving to be a slow process. Also there were often times when a new service would be setup on the same server (as a Docker container), and again IT had to be involved. 

The idea was to have something in our control that did not bother anybody from the IT department. It was also possible that some of the services would possibly have a port conflict with other ports on the same server, but changing port numbers for the conflicting services was not an option as it would prove to be to costly to maintain the host-container mapping. 

# The solution:
After banging my head with the problem for some time, I thought that I could sooth this itch by doing the following:
* Ask IT to assign one fixed IP address to the CoDe server, and have it registered in their DNS **once**.
* Ask IT for a new sub-domain of their current domain-name being used in their infrastructure - done **once**.
* Setup our CoDe server to be an authoritative name server for that sub-domain obtained from the IT department - **once**.
* Ask IT to update their DNS server to forward all traffic for the above mentioned sub-domain to this CoDe server - **once**.
* Ask IT to provide you an unused **range of (private) IPs** from the scheme being used on the infrastructure - done **once**.

From this point on we were done with bothering the IT department, and could focus on setting up our server:

* Remove any host-container mapping from any docker / docker-compose application
* Setup a new infrastructure IP on host's network interface for each container running on this server, and,
* Use iptables redirection rules to redirect incoming traffic on the network interface for each IP to a corresponding container.
* Setup DNS entries in our DNS server, for all these new IP addresses now setup on the host's network interface card.
* Add C-Advisor to see necessary resource utilization information about the host and containers.
* Automate all the tasks except those mentioning 'once' in this list.

And then, OCDD was born, which looks something like this: 

![](OCDD-TheBigPicture.png)


# The working:
OCDD is actually a shell script, aptly named 'ocdd.sh'.

It can be considered as an add-on to your docker host serving as CoDe server. By add-on, I mean that it will not affect any docker/compose application currently running on your server, with two exceptions:

* If you are running some DNS service listening on port 53(tcp,udp)
* If you are running some web service on port 80

You can either disable OCDD's internal web service completely in docker-compose or configure it to run on a different port. If you are running some DNS service on your CoDe server, then OCDD will not work for you, it's DNS service is at the heart of it's overall design.

###So, what happens when you run OCDD? 

Well, first it initializes itself - which you have to do manually, the first time. Then, when run in the normal mode, it finds all the containers running on the Docker host, assigns an IP address from the unused range of IPs we know about - to the network interface of the server, sets up necessary iptables forwarding rules, and updates it's DNS zone file for the sub-domain it is responsible for. 

**That's it!** 

You can then access each container service on the CoDe server by using its DNS name or infrastructure IP from anywhere on the network. 

#The prerequisites

The following are prerequisites for OCDD to work correctly on a Docker host:
* You need to use either root or a user with password-less sudo access to setup OCDD.
* In addition to having [Docker](https://www.docker.com/) / Docker-Engine and Docker-Compose, you need to have [git](https://git-scm.com/) (to download this repo - of-course), and [jq](https://stedolan.github.io/jq/download/).
* You need to setup a persistent storage location (with correct ownership/permissions) on your Docker host for DNS and www services which comes with OCDD. In my case it is `/opt/ocdd/` , which contains dns and www directories inside it. 
* You need to know the name of the sub-domain you want your DNS service to be authoritative for.
* You need to know the range of IPs you can use for your containers.

The `ocdd.conf` file helps you configure how `ocdd.sh` will behave.

Here is what my `ocdd.conf` file looks like:

```
[kamran@dockerhost OctoCopDD]$ egrep -v "\#|^$" ocdd.conf 
DEBUG=0
DOCKER_SOCKET='/var/run/docker.sock'
DOCKER_API_URL='http://localhost/containers/json'
NETWORK_DEVICE='ens3'
IP_SUBNET='192.168.122'
IP_RANGE_START=11
IP_RANGE_END=30
TOOLBOX_SUBDOMAIN_NAME='toolbox.example.com'
STORAGE_DIR=/opt/ocdd
DNS_ZONE_FILE=${STORAGE_DIR}/dns/toolbox.example.com.zone
WEB_INDEX_FILE=${STORAGE_DIR}/www/index.html
```

# The examples:
By now you would like to see it in action by following some examples, right? 

I will surely do that for you.
In this example I will spin up Jenkins and Artifactory and use OCDD to guide trafic to them.

## First, get the repo on the new server:

```
[kamran@dockerhost ~]$ git clone https://github.com/Praqma/OctoCopDD.git
[kamran@dockerhost ~]$ cd OctoCopDD
[kamran@dockerhost OctoCopDD]$
```

## Start the example application (Jenkins + Artifactory):
Assume you have some containers running on the CoDe server. If you do not have anything at all, don't worry; there is an example/ directory in the repository, which has a very simple docker-compose file. It starts an instance of Jenkins and Artifactory. 

Before doing anything OCDD specific we can start that:

```
[kamran@dockerhost OctoCopDD]$ cd example/

[kamran@dockerhost example]$ docker-compose up -d
Starting example_jenkins_1
Starting example_artifactory_1
[kamran@dockerhost example]$ 

[kamran@dockerhost example]$ docker-compose ps
        Name                       Command               State                 Ports                
---------------------------------------------------------------------------------------------------
example_artifactory_1   catalina.sh run                  Up      8080/tcp                           
example_jenkins_1       /bin/tini -- /usr/local/bi ...   Up      50000/tcp, 8080/tcp 
[kamran@dockerhost example]$ 
```

Notice that the ports of Jenkins or Artifactory are **not** mapped on the host. This is very important to note. So now you have some 'production' docker-compose app running somwhere on the server, before OCDD is run. 

Next, we setup OCDD on this server.


## Initialize OCDD:
Change the directory back to the project root, and run `./ocdd initialize` .

```
[kamran@dockerhost example]$ cd ..

[kamran@dockerhost OctoCopDD]$ ./ocdd.sh initialize
Initializing OCDD ...
- Building fresh iplist.txt
- Removing OCDD specific iptables rules ...
- Removing additional IP addresses from the network interface - ens3 ...
- Removing services list from web server's index.html
- Stopping OCDD compose app (DNS, C-Advisor) ...

- Starting OCDD compose app (DNS, C-Advisor). This may take few minutes when run for the first time...
Recreating octocopdd_www_1
Recreating octocopdd_dns_1
Starting octocopdd_cadvisor_1

You can now run ./ocdd.sh without any parameters , so it could detect any running containers and does it's thing!

[kamran@dockerhost OctoCopDD]$ 
``` 

The script tells us to run `./ocdd.sh` to start OCDD.
But before we do that, it would be nice to have a look at `docker-compose ps` , while we are in the project root directory:

```
[kamran@dockerhost OctoCopDD]$ docker-compose ps
        Name                      Command               State                   Ports                  
------------------------------------------------------------------------------------------------------
octocopdd_cadvisor_1   /usr/bin/cadvisor -logtostderr   Up      8080/tcp                               
octocopdd_dns_1        /sbin/entrypoint.sh /usr/s ...   Up      0.0.0.0:53->53/tcp, 0.0.0.0:53->53/udp 
octocopdd_www_1        nginx -g daemon off;             Up      443/tcp, 0.0.0.0:80->80/tcp            
[kamran@dockerhost OctoCopDD]$
```

Notice that I have three containers running using through a separate (OCDD) docker-compose app. 

The most important of them is DNS, which has it's ports mapped to the Docker host. The next one is www, which is just a web server publishing a very simple web page. This one is completely optional, and you can disable it in the OCDD docker-compose.yaml file. The third one - C-Advisor is just for monitoring (and some fun). It provides you with an overall picture of the docker-host and all the containers running on it. 

It must be noticed that I changed directory to run OCDD, and used `docker-compose ps` command to see containers belonging to this docker-compose app only. If you want to look at all the containers on this Docker host, then you should use `docker ps`:

```
[kamran@dockerhost OctoCopDD]$ docker ps
CONTAINER ID        IMAGE                        COMMAND                  CREATED             STATUS              PORTS                                    NAMES
19424d3230fc        octocopdd_dns                "/sbin/entrypoint.sh "   3 days ago          Up 8 seconds        0.0.0.0:53->53/tcp, 0.0.0.0:53->53/udp   octocopdd_dns_1
91c3bd286ff2        nginx                        "nginx -g 'daemon off"   3 days ago          Up 8 seconds        0.0.0.0:80->80/tcp, 443/tcp              octocopdd_www_1
8113e8e5c447        jenkins:2.46.1               "/bin/tini -- /usr/lo"   3 days ago          Up 17 seconds       8080/tcp, 50000/tcp                      example_jenkins_1
96a50212ec2b        google/cadvisor:latest       "/usr/bin/cadvisor -l"   5 days ago          Up 8 seconds        8080/tcp                                 octocopdd_cadvisor_1
9b058c7b84fe        mattgruter/artifactory:3.9   "catalina.sh run"        5 days ago          Up 17 seconds       8080/tcp                                 example_artifactory_1
[kamran@dockerhost OctoCopDD]$ 
```

Again note that you do not need to map any ports of any of your applications to the Docker host, when you are using OCDD. It is OCDD's job to give you a nice DNS name for each service you have, and lets you access that using port forwarding. 


## Run the OCDD script in normal mode:
To see the real magic happening, run OCDD in normal mode. Simply execute `./ocdd.sh` :

```
[kamran@dockerhost OctoCopDD]$ ./ocdd.sh 

Found containers with following (docker-private) IP addresses:

dns 172.19.0.4
www 172.19.0.3
jenkins 172.18.0.3
cadvisor 172.19.0.2
artifactory 172.18.0.2

CONTAINER_COUNT on this docker host is 5 .


Generating iptables rules and DNS entries for each container...


Restarting octocopdd_dns_1 ... done
Restarting octocopdd_www_1 ... done

-------------------------------------------------------------------------------------

Here is how various hostnames and their IPs look like (in DNS) toolbox.example.com :

toolbox.example.com.	14400	IN	A	192.168.122.200
artifactory.toolbox.example.com. 14400 IN A	192.168.122.15
cadvisor.toolbox.example.com. 14400 IN	A	192.168.122.14
dns.toolbox.example.com. 14400	IN	A	192.168.122.11
dockerhost.toolbox.example.com.	14400 IN A	192.168.122.200
jenkins.toolbox.example.com. 14400 IN	A	192.168.122.13
www.toolbox.example.com. 14400	IN	A	192.168.122.12

[kamran@dockerhost OctoCopDD]$ 
```

While OCDD does it's thing, it also creates/updates the index.html file with the list of services. This is just in case someone tries to reach http://dockerhost.example.com. You can `curl` your localhost to get an idea about this web page.

```
[kamran@dockerhost OctoCopDD]$ curl localhost
<Title>The ACME ToolBox server</Title>
<H1>The ACME ToolBox server</H1>
<HR>

<br>* - dns.toolbox.example.com
<br>* - www.toolbox.example.com
<br>* - jenkins.toolbox.example.com
<br>* - cadvisor.toolbox.example.com
<br>* - artifactory.toolbox.example.com
[kamran@dockerhost OctoCopDD]$ 
```

That's it! Now lets access each service from a client computer and verify that we can indeed reach service using it's own DNS name.

## Access the web service of our dockerhost:
When you access the Docker host running OCDD, using it's fixed IP or the DNS name, you should be able to see the following:

![](web-list.png)

## Access the Jenkins service using it's own DNS name:
First notice that on a client computer, I am able to resolve `jenkins.toolbox.example.com` , where obviously `toolbox.example.com` is the sub-domain assigned to us.

```
[kamran@kworkhorse ~]$ dig jenkins.toolbox.example.com +short
192.168.122.13
[kamran@kworkhorse ~]$ 
```

Same goes for Artifactory:
```
[kamran@kworkhorse ~]$ dig artifactory.toolbox.example.com +short
192.168.122.15
[kamran@kworkhorse ~]$ 
```

Remember, you will need to specify the port of the service you are trying to access in addition to using it's DNS name. The design of OCDD is just to forward the traffic arriving at one infrastructure-IP and forward it to container IP, leaving the port to be used for the user. This allowed the OCDD's design to be much simpler.

So here is the screenshot that shows the Jenkins web page:

![](jenkins.png)


## Access the Artifactory service using it's own DNS name:

![](artifactory.png)


## C-Advisor:
Just for fun (and to get some important information about your containers), here is the C-Advisor:

![](cadvisor.png)


# The summary:
OctoCopDD completely soothes this itch of how to have control on CoDe server or services, without routinely bothering (read: bugging) IT department of an organization. The project is accessible through [https://github.com/praqma/octocopdd](https://github.com/praqma/octocopdd). Following our agile principle of *Continuous Improvement*, it is a work in progress - though production ready. I hope you will enjoy deploying and using it as much as I did while developing it.
