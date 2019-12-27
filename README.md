# docker-vran using a No-RF driver

This repo package a srsUE and an srsENB release in two separate containers (see srsLTE repo https://github.com/srsLTE/srsLTE). Instead of using over-the-air transmission the transport is configured without radio interface using a virtual network and ZeroMQ to exchange RAN messages as emulated baseband transport layer.  

## Building srsLTE with ZeroMQ 

ZeroMQ has different modes of operation, srsLTE uses Request/Reply mode. The ZMQ module has two entities, a transmitter as a repeater and as a requester. The receiver will asynchronously send requests for data to the transmitter and this will reply with base-band samples. Consequently, the receiver will store the received data in a buffer, waiting to be read. Both modules shall operate at the same base rate so their bandwidth expectations can be satisfied.

### Installing ZeroMQ support for srsLTE

Here I added a few notes on the to the usual Dockerfile to build srsLTE. The steps below are already present the `Dockerfile` provided in this repo. First thing installing ZeroMQ library using apt-get or using the sources. I've used apt-get in an Ubuntu 18.04 container:

```
apt-get install libzmq3-dev
```

After this it is necessary to compile the srsLTE sources.

```
git clone https://github.com/srsLTE/srsLTE.git cd srsLTE
mkdir build
cd build
cmake ../ 
```

Make sure you read ZEROMQ library is detected in the output of cmake:

```
...
-- FINDING ZEROMQ.
-- Checking for module 'ZeroMQ'
-- No package 'ZeroMQ' found
-- Found libZEROMQ: /usr/local/include, /usr/local/lib/libzmq.so ...
```

If the ZeroMQ libraries are found you are good to go. Then install srsLTE as usual:

```
make
make install
```

## Configuring the vENODEB

Some notes here on the modification of the default config files provided by srsLTE:

### ZeroMQ

We mofified the type of RF device used as front-end:

```
device_name = zmq
device_args = "rx_port=tcp://192.168.51.101:5555,tx_port=tcp://*:5554,id=enb,base_srate=1.92e6"
```

where 192.168.1.101 is the IP address of the UE. In this example I used a network created by docker using default bridge driver to exchange ZeroMQ messages between UE and eNodeB.

I only managed to make it work with 6 resource blocks (to be further investigated):

```
[enb]
default parameter
n_prb = 6
```


### Radio resource configuration parameters
Some of the files we haven't modified whereas files with fake on it have been modified. 

```
rr.conf:  contains radio resource configuration
drb.conf: data bearers configuration
sibfake.conf: SIB configuration modified
sibmsbfn.conf: SIB MSBFN configuration
enbfake.conf: enb config modified
uefake.conf: ue config modified
```

Tuned manually the transmission time delay (counted in samples) in the RF configuration part.This setting must be applied in both the eNodeB and the UE.

```
[rf]
.....
time_adv_nsamples = 0
```

Without this modification there are problems at teh RACH when establishing the RRC connection setup (e.g., RRC can't be establisthed due to T300 timer expiration cause of some discarded frame in buffer).

### vENODEB networks

enb.mme_addr : Ip address of the MME  
enb.gtp_bind_addr : Ip address assined to the eNodeB to connect with S-GW
enb.s1c_bind_addr : Ip addres assigned to eNodeB to connect with the MME

Instead of using over-the air medium we use a docker network based on default bridge driver `rfemu` is the name of the network in `docker-compose.yml` of this repo where the vUE is in a container and the veNodeB is in another container:
                                                                  
                                 ZeroMQ Messages                   
              ┌──────────┐                             ┌──────────┐
              │          │          ┌─────────┐        │          │
              │   UE     │◀─────────┤ bridge  ├───────▶│   eNodeB │
              │          │          └─────────┘        │          │
              └──────────┘                             └──────────┘

### Configuring SIB

The file `sibfake.con` contains some adjustment for our emulated setting. First all timers are increased to their allowed maximum:

```
ue_timers_and_constants = {
      t300 = 2000; // in ms
      t301 = 2000;  // in ms
      t310 = 2000; // in ms
      n310 = 20;
      t311 = 30000; // in ms
n311 = 10; };
```

Also, because of the `n_prb` setting some changes are required in `sib.conf` file parameter `prach_freq_offset`. In `prach_cnfg` block:

```
 prach_cnfg =
        {
            root_sequence_index = 128;
            prach_cnfg_info =
            {
                high_speed_flag = false;
                prach_config_index = 3;
                prach_freq_offset = 0;
                zero_correlation_zone_config = 5;
            };
        };
```

## Configuring the vUE

In the file `uefake.conf` there are some modifications of the by-default UE parameters. Parameters changed here are:

```
device_name = zmq
device_args = "rx_port=tcp://192.168.51.100:5554,tx_port=tcp://*:5555,id=ue,base_srate=1.92e6"
```

where 192.168.51.100 is the IP address of the eNodeB used for RAN downlink messages through ZMQ bus.

At the RF level, it is important to tune manually the parameter related to the number of advertised samples RF with the same value as the one declared in the eNodeB.

```
[rf]
.....
time_adv_nsamples = 0
```

Without this setting I observed problems at the RACH when establishing the RRC connection setup (T300 timer expiration).

### UE network

To establish the emulated transport just attach port of network `rfemu` as specified in the `docker-compose.yml`.

## Run vUE+veNodeB

To run the UE and eNodeB in two containers in the same baremetal/VM machine:

```
docker-compose -f docker-compose.yml build --no-cache
docker-compose up -d
```

Tested using srsLTE 19.09 sw release and ubuntu 18.04 as base container.
Once containers are running you can start checking the logs:

### vENODEB debugging:

```
docker logs enodezmq -f
linux; GNU C++ version 7.3.0; Boost_106501; UHD_003.010.003.000-0-unknown


Built in Release mode using commit 0e89fa9f on branch master.

---  Software Radio Systems LTE eNodeB  ---

Reading configuration file /config/enbfake.conf...
Opening 1 RF devices with 1 RF channels...
Using base rate=1.92e6"
Using rx_port=tcp://192.168.50.101:5555
Using tx_port=tcp://*:5554
Using ID=enb
Current sample rate is 1.92 MHz with a base rate of 1.92 MHz (x1 decimation)

Warning burst preamble is not calibrated for device zmq. Set a value manually

Setting frequency: DL=2685.0 Mhz, UL=2565.0 MHz
Setting Sampling frequency 1.92 MHz
Current sample rate is 1.92 MHz with a base rate of 1.92 MHz (x1 decimation)
Current sample rate is 1.92 MHz with a base rate of 1.92 MHz (x1 decimation)
Setting manual TX/RX offset to 0 samples

==== eNodeB started ===
Type <t> to view trace
Closing stdin thread.
RACH:  tti=351, preamble=22, offset=0, temp_crnti=0x46
User 0x46 connected
```

### vUE debugging:

```
docker logs uezmq -f
linux; GNU C++ version 7.3.0; Boost_106501; UHD_003.010.003.000-0-unknown

Reading configuration file /config/uefake.conf...

Built in Release mode using commit 0e89fa9f on branch master.

Opening 1 RF devices with 1 RF channels...
Using base rate=1.92e6"
Using rx_port=tcp://192.168.50.100:5554
Using tx_port=tcp://*:5555
Using ID=ue
Current sample rate is 1.92 MHz with a base rate of 1.92 MHz (x1 decimation)

Warning burst preamble is not calibrated for device zmq. Set a value manually

Waiting PHY to initialize ... done!
Attaching UE...
Closing stdin thread.
Searching cell in DL EARFCN=3400, f_dl=2685.0 MHz, f_ul=2565.0 MHz
Current sample rate is 1.92 MHz with a base rate of 1.92 MHz (x1 decimation)
Current sample rate is 1.92 MHz with a base rate of 1.92 MHz (x1 decimation)
Setting manual TX/RX offset to 0 samples
.
Found Cell:  Mode=FDD, PCI=1, PRB=6, Ports=1, CFO=-0.0 KHz
Current sample rate is 1.92 MHz with a base rate of 1.92 MHz (x1 decimation)
Current sample rate is 1.92 MHz with a base rate of 1.92 MHz (x1 decimation)
Setting manual TX/RX offset to 0 samples
Found PLMN:  Id=00101, TAC=4660
Random Access Transmission: seq=22, ra-rnti=0x2
Random Access Complete.     c-rnti=0x46, ta=0
RRC Connected
Network attach successful. IP: 45.45.0.9
 nTp) 25/12/2019 16:26:15 TZ:0
```

Ping to P-GW, we can observe is slighly higher with ZeroMQ than using sharedmemory:

```
docker exec -it uezmq bash -c "ping 45.45.0.1"
PING 45.45.0.1 (45.45.0.1) 56(84) bytes of data.
64 bytes from 45.45.0.1: icmp_seq=1 ttl=64 time=48.9 ms
64 bytes from 45.45.0.1: icmp_seq=2 ttl=64 time=54.1 ms
64 bytes from 45.45.0.1: icmp_seq=3 ttl=64 time=56.9 ms
64 bytes from 45.45.0.1: icmp_seq=4 ttl=64 time=65.1 ms
64 bytes from 45.45.0.1: icmp_seq=5 ttl=64 time=45.8 ms
64 bytes from 45.45.0.1: icmp_seq=6 ttl=64 time=53.6 ms
64 bytes from 45.45.0.1: icmp_seq=7 ttl=64 time=56.4 ms
```

After attachment note that you have to manually add a default route and deleting default route in the UE to reach the Internet through `tun_srsue`:

```
docker exec -it uezmr bash -c "ip r d default"
docker exec -it uezmr bash -c "ip r a default dev tun_srsue"
docker exec -it uezmr bash -c "ping 8.8.8.8"
PING 8.8.8.8 (8.8.8.8) 56(84) bytes of data.
64 bytes from 8.8.8.8: icmp_seq=1 ttl=52 time=69.4 ms
64 bytes from 8.8.8.8: icmp_seq=2 ttl=52 time=59.7 ms
64 bytes from 8.8.8.8: icmp_seq=3 ttl=52 time=75.3 ms
64 bytes from 8.8.8.8: icmp_seq=4 ttl=52 time=60.8 ms
```


## Caveats//ToDo

- Currently UE and eNodeB in the same machine. Put them in different machines.
- Try with more resource blocks (n_prb=6).
- Increase the number of UEs.

