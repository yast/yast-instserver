# Makefile.am for instserver/src
#

SUBDIRS = httpd

yncludedir = @yncludedir@/instserver
YCPCFLAGS = -I ./include

client_DATA =			\
	instserver.ycp		\
	instserver_auto.ycp

ynclude_DATA =			\
	helps.ycp		\
	routines.ycp		\
	wizards.ycp		\
	dialogs.ycp		\
	complex.ycp

desktop_DATA =			\
	instserver.desktop

module_DATA =			\
	Instserver.ycp	

EXTRA_DIST = $(client_DATA) $(ynclude_DATA) $(module_DATA) $(desktop_DATA)

install-data-local:
	install -d -m 755 $(DESTDIR)/var/lib/YaST2/instserver


include:
	mkdir include && ln -sf ../ include/instserver

ycpchook = include


include $(top_srcdir)/Makefile.am.common
