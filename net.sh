#! /usr/bin/bash
sudo iptables -I FORWARD 1 -i virbr0 -o wlan0 -s 192.168.122.0/24 -j ACCEPT
sudo iptables -I FORWARD 2 -i wlan0 -o virbr0 -d 192.168.122.0/24 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
sudo iptables -t nat -A POSTROUTING -s 192.168.122.0/24 -o wlan0 -j MASQUERADE
