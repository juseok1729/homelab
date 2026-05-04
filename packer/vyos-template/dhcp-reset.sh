source /opt/vyatta/etc/functions/script-template
configure
delete interfaces ethernet eth0 address
set interfaces ethernet eth0 address dhcp
commit
save
exit
