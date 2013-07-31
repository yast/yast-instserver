# Sources for instserver

module_DATA = \
  modules/Instserver.rb

client_DATA = \
  clients/instserver.rb

yncludedir = @yncludedir@/instserver
ynclude_DATA = \
  include/instserver/wizards.rb \
  include/instserver/dialogs.rb \
  include/instserver/complex.rb \
  include/instserver/routines.rb \
  include/instserver/helps.rb

desktop_DATA = \
  desktop/instserver.desktop

EXTRA_DIST = $(module_DATA) $(client_DATA) $(ynclude_DATA) $(desktop_DATA)

include $(top_srcdir)/Makefile.am.common