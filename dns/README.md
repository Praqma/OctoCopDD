# DNS as a container 
This Dockerfile creates a centos based bind/named container. 
The changes which need to be made can be made to the toolbox.example.zone file and the container can be rebuilt and re-run. OCDD will use this container image and will need to know about persistent storage for it's zone file. 

There is a possible port conflict of running this container on a ubuntu server, as ubuntu runs it's own small DNS service for name resolution; which consumes port 53 tcp and udp. We need to stop that service and only then this container can run. On RedHat/Fedora/CentOS systems, the dnsmasq service would need to be stopped before this container is run.

Reference: https://www.digitalocean.com/community/tutorials/how-to-configure-bind-as-a-private-network-dns-server-on-centos-7

Below is some of the interaction I did with the contaier while it was running.

```
[kamran@kworkhorse dns]$ docker run   --dns=127.0.0.1  -p 53:53/tcp -p 53:53/udp  -d example-com/dns 
WARNING: Localhost DNS setting (--dns=127.0.0.1) may fail in containers.
cfc7c19eed0c247895a77bcaedcd93398541ba9875d0bd0743836c3bc9832954


[kamran@kworkhorse dns]$ docker ps
CONTAINER ID        IMAGE               COMMAND                  CREATED             STATUS              PORTS                                    NAMES
cfc7c19eed0c        example-com/dns         "/sbin/entrypoint.sh "   3 seconds ago       Up 2 seconds        0.0.0.0:53->53/tcp, 0.0.0.0:53->53/udp   amazing_shirley


[kamran@kworkhorse dns]$ dig yahoo.com @127.0.0.1

;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 40410
;; flags: qr rd ra; QUERY: 1, ANSWER: 3, AUTHORITY: 5, ADDITIONAL: 9

;; QUESTION SECTION:
;yahoo.com.			IN	A

;; ANSWER SECTION:
yahoo.com.		1800	IN	A	98.138.253.109
yahoo.com.		1800	IN	A	98.139.183.24
yahoo.com.		1800	IN	A	206.190.36.45

;; Query time: 722 msec
;; SERVER: 127.0.0.1#53(127.0.0.1)
;; WHEN: Fri May 13 13:53:36 CEST 2016
;; MSG SIZE  rcvd: 340

[kamran@kworkhorse dns]$


[kamran@kworkhorse dns]$ dig toolbox.example.com @127.0.0.1

;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 20474
;; flags: qr aa rd ra; QUERY: 1, ANSWER: 0, AUTHORITY: 1, ADDITIONAL: 1

;; QUESTION SECTION:
;toolbox.example.com.			IN	A

;; AUTHORITY SECTION:
toolbox.example.com.		14400	IN	SOA	dockerhost.toolbox.example.com. sysadminemailaddress.tools.example.com. 3 3600 7200 3600 14400

;; Query time: 0 msec
;; SERVER: 127.0.0.1#53(127.0.0.1)
;; WHEN: Fri May 13 13:54:08 CEST 2016
;; MSG SIZE  rcvd: 122




[kamran@kworkhorse dns]$ dig dns.toolbox.example.com @127.0.0.1

;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 51188
;; flags: qr aa rd ra; QUERY: 1, ANSWER: 2, AUTHORITY: 1, ADDITIONAL: 1

;; QUESTION SECTION:
;dns.toolbox.example.com.		IN	A

;; ANSWER SECTION:
dns.toolbox.example.com.		14400	IN	CNAME	dockerhost.toolbox.example.com.
dockerhost.toolbox.example.com.	14400	IN	A	192.168.124.200

;; AUTHORITY SECTION:
toolbox.example.com.		14400	IN	NS	dockerhost.toolbox.example.com.

;; Query time: 0 msec
;; SERVER: 127.0.0.1#53(127.0.0.1)
;; WHEN: Fri May 13 13:54:16 CEST 2016
;; MSG SIZE  rcvd: 101

[kamran@kworkhorse dns]$ 
```
