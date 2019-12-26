docker network create -d macvlan --subnet=10.15.16.0/24 --gateway=10.15.16.1 -o parent=eno1.666 s1c
docker network create -d macvlan --subnet=10.15.17.0/24 --gateway=10.15.17.1 -o parent=eno1.667 s1u
