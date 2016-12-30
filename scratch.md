iptables -t nat -D DOCKER ! -i docker0 -p tcp -m tcp -m multiport --dports 80,443 -j DNAT --to-destination 172.17.0.2


{
  "Id": "211592ba1f648a78f8eefcf7892418748f9a16bb039a2d418f4935abbb2a261a",
  "Names": [
    "/prickly_mirzakhani"
  ],
  "Image": "nginx",
  "ImageID": "sha256:0d409d33b27e47423b049f7f863faa08655a8c901749c2b25b93ca67d01a470d",
  "Command": "nginx -g 'daemon off;'",
  "Created": 1481204125,
  "Ports": [
    {
      "PrivatePort": 443,
      "Type": "tcp"
    },
    {
      "PrivatePort": 80,
      "Type": "tcp"
    }
  ],
  "Labels": {},
  "State": "running",
  "Status": "Up 21 minutes",
  "HostConfig": {
    "NetworkMode": "default"
  },
  "NetworkSettings": {
    "Networks": {
      "bridge": {
        "IPAMConfig": null,
        "Links": null,
        "Aliases": null,
        "NetworkID": "f87d44650b96c649234ad0fb46b8b1aaa119bcc452a05a4764db6c4eecea25e9",
        "EndpointID": "e88a4b5e871d2a14883fbcfa6d99e7dc7e00c34bbd1e3c048ee0e3e1e2c295c2",
        "Gateway": "172.17.0.1",
        "IPAddress": "172.17.0.3",
        "IPPrefixLen": 16,
        "IPv6Gateway": "",
        "GlobalIPv6Address": "",
        "GlobalIPv6PrefixLen": 0,
        "MacAddress": "02:42:ac:11:00:03"
      }
    }
  },
  "Mounts": []
}









[root@kworkhorse ~]# curl -s --unix-socket /var/run/docker.sock http:/containers/json \
                           | jq '.[] | .Names[0] + " " + .NetworkSettings.Networks.bridge.IPAddress' 
"/prickly_mirzakhani 172.17.0.3"
"/clever_swanson 172.17.0.2"
[root@kworkhorse ~]# 


[root@kworkhorse ~]# curl -s --unix-socket /var/run/docker.sock http:/containers/json | jq '.[]  .Ports[].PrivatePort' 
443
80
80
[root@kworkhorse ~]# 



jq '.[] | .Names[0] + " " + .NetworkSettings.Networks.bridge.IPAddress .Ports[].PrivatePort' 







[root@kworkhorse ~]# curl -s --unix-socket /var/run/docker.sock http:/containers/json | jq '.[]' | jq  -r "[.Names[0],.Ports[].PrivaworkSettings.Networks.bridge.IPAddress" | tr -d ']'  | tr ',\n' ' ' | tr '[' '\n'

   "/prickly_mirzakhani"    443    80  172.17.0.3 
   "/clever_swanson"    80  172.17.0.2 [root@kworkhorse ~]# 






[root@kworkhorse ~]# for container in $(docker ps -q); do docker inspect --format='{{.NetworkSettings.IPAddress}}   {{range $p, $conf := .NetworkSettings.Ports}} {{$p}} {{end}}'  $container  | sed 's/\/tcp//g' ; done
172.17.0.3    443  80 
172.17.0.2    80 
[root@kworkhorse ~]# 










-A DOCKER ! -i docker0 -p tcp -m tcp --dport 443 -j DNAT --to-destination 172.17.0.2:443
-A DOCKER ! -i docker0 -p tcp -m tcp --dport 80 -j DNAT --to-destination 172.17.0.2:80




[root@kworkhorse lb-iptables]# curl -s --unix-socket /var/run/docker.sock http:/containers/json | jq '.[] | select(.NetworkSettings.Networks.bridge.IPAddress == "'${IP}'") |  .Ports[].PrivatePort ' 
443
80
[root@kworkhorse lb-iptables]# 


[root@kworkhorse lb-iptables]# curl -s --unix-socket /var/run/docker.sock http:/containers/json | jq '.[] | select(.NetworkSettings.Networdge.IPAddress == "'${IP}'") |  .Ports[].PrivatePort ' | tr '\n' ',' | sed 's/,$/\n/'
443,80
[root@kworkhorse lb-iptables]# 




[root@kworkhorse lb-iptables]# curl -s --unix-socket /var/run/docker.sock http:/containers/json                            | jq '.[] | .Names[0] + " " + .NetworkSettings.Networks.bridge.IPAddress  , .Ports[].PrivatePort  '  
"/fervent_liskov 172.17.0.4"
8080
"/condescending_cori 172.17.0.3"
443
80
"/evil_hawking 172.17.0.2"
443
80
[root@kworkhorse lb-iptables]#






[root@kworkhorse lb-iptables]# curl -s --unix-socket /var/run/docker.sock http:/containers/json                            | jq '.[] | .Names[0] + " " + .NetworkSettings.Networks.bridge.IPAddress ,  .Ports[].PrivatePort|tostring'  
"/fervent_liskov 172.17.0.4"
"8080"
"/condescending_cori 172.17.0.3"
"443"
"80"
"/evil_hawking 172.17.0.2"
"80"
"443"
[root@kworkhorse lb-iptables]# 





[kamran@kworkhorse Downloads]$ echo '["a","b,c,d","e"]' | jq 'join(",")'
"a,b,c,d,e"
[kamran@kworkhorse Downloads]$ 








(Wireless IP/localhost)[laptop/desktop](192.168.124.1)-------(192.168.124.200)DockerHost(172.17.0.1)------{docker0 network}----Three containers





[kamran@dockerhost OctoCopDD]$ curl -s --unix-socket /var/run/docker.sock http:/containers/json | jq -r '.[] |  .NetworkSettings.Networks[].IPAddress'
172.19.0.4
172.19.0.3
172.19.0.2
172.17.0.2
[kamran@dockerhost OctoCopDD]$ 



[kamran@dockerhost OctoCopDD]$ curl -s --unix-socket /var/run/docker.sock http:/containers/json                            | jq -r '.[] | .Names[0] + " " + .NetworkSettings.Networks[].IPAddress'
/octocopdd_dns_1 172.19.0.4
/octocopdd_apache_1 172.19.0.3
/octocopdd_multitool_1 172.19.0.2
/big_colden 172.17.0.2
[kamran@dockerhost OctoCopDD]$ 



------------------------------

Delete all praqma rules from iptables:

[kamran@dockerhost OctoCopDD]$ sudo iptables-save  | grep PRAQMA | sed 's/^-A/iptables -t nat -D/' | sudo bash



