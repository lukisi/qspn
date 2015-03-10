NULL = 
ACLOCAL_AMFLAGS = -I m4

EXTRA_LTLIBRARIES = \
	libqspn.la \
	$(NULL)

bin_PROGRAMS =  \
	qspnclient \
	$(NULL)

TESTS = \
	test_qspn \
	auto_graph \
	$(NULL)

check_PROGRAMS = \
	test_qspn \
	auto_graph \
	discover_paths \
	$(NULL)

test_qspn_SOURCES = \
	testsuites/test_qspn/test_qspn.vala \
	testsuites/test_qspn/fake_classes.vala \
	testsuites/test_qspn/generic_naddr.vala \
	testsuites/test_qspn/base_dispatcher.vala \
	qspn.vapi \
	$(NULL)

test_qspn_VALAFLAGS = \
	--pkg gio-2.0 \
	--pkg gee-0.8 \
	--pkg tasklet \
	--pkg zcd \
	--pkg ntkd-rpc\
	$(NULL)

test_qspn_CPPFLAGS = \
	-w \
	$(GOBJECT_CFLAGS) \
	$(GIO_CFLAGS) \
	$(GEE_CFLAGS) \
	$(TASKLET_CFLAGS) \
	$(ZCD_CFLAGS) \
	$(NTKDRPC_CFLAGS) \
	$(NULL)

test_qspn_LDADD = \
	$(GOBJECT_LIBS) \
	$(GIO_LIBS) \
	$(GEE_LIBS) \
	$(TASKLET_LIBS) \
	$(ZCD_LIBS) \
	$(NTKDRPC_LIBS) \
	$(builddir)/libqspn.la \
	$(NULL)

auto_graph_SOURCES = \
	testsuites/auto_graph/auto_graph.vala \
	testsuites/auto_graph/fake_classes.vala \
	testsuites/auto_graph/generic_naddr.vala \
	testsuites/auto_graph/base_dispatcher.vala \
	qspn.vapi \
	$(NULL)

auto_graph_VALAFLAGS = \
	--pkg gio-2.0 \
	--pkg gee-0.8 \
	--pkg tasklet \
	--pkg zcd \
	--pkg ntkd-rpc\
	$(NULL)

auto_graph_CPPFLAGS = \
	-w \
	$(GOBJECT_CFLAGS) \
	$(GIO_CFLAGS) \
	$(GEE_CFLAGS) \
	$(TASKLET_CFLAGS) \
	$(ZCD_CFLAGS) \
	$(NTKDRPC_CFLAGS) \
	$(NULL)

auto_graph_LDADD = -lm \
	$(GOBJECT_LIBS) \
	$(GIO_LIBS) \
	$(GEE_LIBS) \
	$(TASKLET_LIBS) \
	$(ZCD_LIBS) \
	$(NTKDRPC_LIBS) \
	$(builddir)/libqspn.la \
	$(NULL)

discover_paths_SOURCES = \
	testsuites/discover_paths/discover_paths.vala \
	testsuites/discover_paths/fake_classes.vala \
	testsuites/discover_paths/generic_naddr.vala \
	testsuites/discover_paths/base_dispatcher.vala \
	qspn.vapi \
	$(NULL)

discover_paths_VALAFLAGS = \
	--pkg gio-2.0 \
	--pkg gee-0.8 \
	--pkg tasklet \
	--pkg zcd \
	--pkg ntkd-rpc\
	$(NULL)

discover_paths_CPPFLAGS = \
	-w \
	$(GOBJECT_CFLAGS) \
	$(GIO_CFLAGS) \
	$(GEE_CFLAGS) \
	$(TASKLET_CFLAGS) \
	$(ZCD_CFLAGS) \
	$(NTKDRPC_CFLAGS) \
	$(NULL)

discover_paths_LDADD = \
	$(GOBJECT_LIBS) \
	$(GIO_LIBS) \
	$(GEE_LIBS) \
	$(TASKLET_LIBS) \
	$(ZCD_LIBS) \
	$(NTKDRPC_LIBS) \
	$(builddir)/libqspn.la \
	$(NULL)

qspnclient_SOURCES =  \
	main.vala \
	qspn.vapi \
	$(NULL)

qspnclient_VALAFLAGS = \
	--pkg gio-2.0 \
	--pkg gee-0.8 \
	--pkg tasklet \
	--pkg posix \
	--pkg zcd \
	--pkg ntkd-rpc\
	--pkg linux \
	$(NULL)

qspnclient_CPPFLAGS = \
	-w \
	$(GOBJECT_CFLAGS) \
	$(GIO_CFLAGS) \
	$(GEE_CFLAGS) \
	$(TASKLET_CFLAGS) \
	$(ZCD_CFLAGS) \
	$(NTKDRPC_CFLAGS) \
	$(NULL)

qspnclient_LDADD = \
	$(GOBJECT_LIBS) \
	$(GIO_LIBS) \
	$(GEE_LIBS) \
	$(TASKLET_LIBS) \
	$(ZCD_LIBS) \
	$(NTKDRPC_LIBS) \
	$(builddir)/libqspn.la \
	$(NULL)

libqspn_la_SOURCES = \
	qspn.vala \
	interfaces.vala \
	$(NULL)

libqspn_la_VALAFLAGS = \
	-H qspn.h \
	--library qspn \
	--pkg gio-2.0 \
	--pkg gee-0.8 \
	--pkg tasklet \
	--pkg posix \
	--pkg zcd \
	--pkg ntkd-rpc\
	--pkg linux \
	$(NULL)

libqspn_la_CPPFLAGS = \
	-w \
	$(GOBJECT_CFLAGS) \
	$(GIO_CFLAGS) \
	$(GEE_CFLAGS) \
	$(TASKLET_CFLAGS) \
	$(ZCD_CFLAGS) \
	$(NTKDRPC_CFLAGS) \
	$(NULL)

libqspn_la_LIBADD = -lm \
	$(GOBJECT_LIBS) \
	$(GIO_LIBS) \
	$(GEE_LIBS) \
	$(TASKLET_LIBS) \
	$(ZCD_LIBS) \
	$(NTKDRPC_LIBS) \
	$(NULL)

CLEANFILES = \
	$(srcdir)/qspn.vapi \
	$(srcdir)/qspn.h \
	$(srcdir)/libqspn_la_vala.stamp \
	$(srcdir)/main.c \
	$(srcdir)/qspn.c \
	$(srcdir)/interfaces.c \
	$(srcdir)/testsuites/test_qspn/test_qspn.c \
	$(srcdir)/testsuites/test_qspn/generic_naddr.c \
	$(srcdir)/testsuites/test_qspn/base_dispatcher.c \
	$(srcdir)/testsuites/test_qspn/fake_classes.c \
	$(srcdir)/testsuites/auto_graph/auto_graph.c \
	$(srcdir)/testsuites/auto_graph/generic_naddr.c \
	$(srcdir)/testsuites/auto_graph/base_dispatcher.c \
	$(srcdir)/testsuites/auto_graph/fake_classes.c \
	$(srcdir)/testsuites/discover_paths/discover_paths.c \
	$(srcdir)/testsuites/discover_paths/generic_naddr.c \
	$(srcdir)/testsuites/discover_paths/base_dispatcher.c \
	$(srcdir)/testsuites/discover_paths/fake_classes.c \
	$(NULL)

qspn.vapi: libqspn_la_vala.stamp
	$(NULL)

