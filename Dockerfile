FROM ubuntu:18.04
MAINTAINER "Jose Nuñez <jonunyez@gmail.com>"
ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update
RUN apt-get -yq dist-upgrade

RUN apt-get install --no-install-recommends -yq \
     cmake \
     libuhd-dev \
     uhd-host \
     libboost-program-options-dev \
     libvolk1-dev \
     libfftw3-dev \
     libmbedtls-dev \
     libsctp-dev \
     libconfig++-dev \
     curl \
     iputils-ping \
     unzip
WORKDIR /root

RUN apt-get --no-install-recommends -qy install build-essential git ca-certificates libzmq3-dev
RUN git clone https://github.com/srsLTE/srsLTE.git && cd srsLTE 

RUN mkdir -p /root/srsLTE/build

WORKDIR /root/srsLTE/build
RUN cmake ../
RUN make
RUN make -j `nproc` install
RUN ldconfig

WORKDIR /root
RUN mkdir /config

# eNB specific files
RUN cp /root/srsLTE/srsenb/drb.conf.example /config/drb.conf
RUN cp /root/srsLTE/srsenb/enb.conf.example /config/enb.conf
RUN cp /root/srsLTE/srsenb/rr.conf.example /config/rr.conf
RUN cp /root/srsLTE/srsenb/sib.conf.example /config/sib.conf
RUN cp /root/srsLTE/srsenb/sib.conf.mbsfn.example /config/sib.mbsfn.conf


RUN apt-get --no-install-recommends -qy install iproute2 tshark net-tools iperf iperf3

ENV TZ=Europe/Madrid
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone
