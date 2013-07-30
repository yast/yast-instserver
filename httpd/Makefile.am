apacheconfdir = /etc/apache2/conf.d
apacheconf_DATA = inst_server.conf.in

install-data-local:
	install -d -m 755 $(DESTDIR)/etc/YaST2/instserver

EXTRA_DIST = $(apacheconf_DATA) 
