#!/bin/sh
sleep 5
ip route del default
srsue /config/uefake.conf --usim.imsi=001010000000001 --usim.k=c8eba87c1074edd06885cb0486718341 --usim.algo=milenage --usim.opc=17b6c0157895bcaa1efc1cef55033f5f --nas.apn=internet --nas.apn_protocol=ipv4 &
#let's wait till core network gives connectivity to UE
#tun_srsue is the device name of ue
UE_IFNAME="tun_srsue"
WAIT=1
[ "$WAIT" ] && {
  while true; do
    grep -q '^1$' "/sys/class/net/$UE_IFNAME/carrier" && break
    ip link ls dev "$UE_IFNAME" && break
    sleep 1
  done > /dev/null 2>&1
  WAIT=0
}
echo "pinging 10 times to the p-gw"
ping -c 10 45.45.0.1 
ip r a default dev tun_srsue
echo "pinging till I die to the internet"
ping  8.8.8.8