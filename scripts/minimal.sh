apt-get purge apache2

locale-gen en_US.UTF-8
locale-gen de_DE.UTF-8
dpkg-reconfigure locales


# use that in the /etc/apt/sources.list instead of the current content (which uses old saucy port)
deb http://ports.ubuntu.com/dists/ trusty main universe
deb-src http://ports.ubuntu.com/dists/ trusty main universe