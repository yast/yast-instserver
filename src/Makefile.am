# Makefile.am for instserver/src

yncludedir = @yncludedir@/instserver

client_DATA =			\
	instserver.ycp		\
	instserver_auto.ycp	\
	instserver_proposal.ycp

ynclude_DATA =			\
	helps.ycp		\
	wizards.ycp		\
	dialogs.ycp		\
	complex.ycp

desktop_DATA =			\
	instserver.desktop

module_DATA =			\
	Instserver.ycp		\
	Instserver.pm

EXTRA_DIST = $(client_DATA) $(ynclude_DATA) $(module_DATA) $(desktop_DATA)

include $(top_srcdir)/Makefile.am.common
