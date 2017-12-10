********************* README *********************


Tornar a porta visível de fora:

	sudo iptables -I INPUT -p tcp --dport 5000 -j ACCEPT 


