#!/bin/sh
sleep 5
srsenb /config/enbfake.conf --enb.name=dummyENB01 --enb.mcc=001 --enb.mnc=01 --enb.enb_id=18AF1 --enb.tac=0x1234 --enb.cell_id=01 --enb.mme_addr=10.15.16.2 --enb.gtp_bind_addr=10.15.17.9 --enb.s1c_bind_addr=10.15.16.9 --enb_files.rr_config=/config/rr.conf --enb_files.sib_config=/config/sibfake.conf --enb_files.drb_config=/config/drb.conf
