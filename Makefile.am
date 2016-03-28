NULL = 
ACLOCAL_AMFLAGS = -I m4

noinst_LTLIBRARIES = \
	libmacgetter.la \
	libqspn.la \
	$(NULL)

#noinst_PROGRAMS =  \
#	qspnclient \
#	$(NULL)

TESTS = \
	test_serialize_helpers \
	$(NULL)
#	test_split_signal \
#	test_not_split_signal \
#

check_PROGRAMS = \
	test_serialize_helpers \
	$(NULL)
#	simulator \
#

EXTRA_PROGRAMS = \
	auto_graph \
	$(NULL)

libmacgetter_la_SOURCES = \
	mac-getter/hw.c \
	mac-getter/hw.h \
	$(NULL)

libmacgetter_la_CPPFLAGS = \
	$(NULL)

libmacgetter_la_LIBADD = \
	$(NULL)

libqspn_la_SOURCES = \
	qspn.vala \
	serialize_helpers.vala \
	$(NULL)

libqspn_la_VALAFLAGS = \
	-H qspn.h \
	--library qspn \
	--pkg gee-0.8 \
	--pkg json-glib-1.0 \
	--pkg tasklet-system \
	--pkg ntkd-common \
	--pkg ntkdrpc\
	$(NULL)

libqspn_la_CPPFLAGS = \
	-w \
	$(GOBJECT_CFLAGS) \
	$(GEE_CFLAGS) \
	$(JSONGLIB_CFLAGS) \
	$(NTKDCOMMON_CFLAGS) \
	$(TASKLETSYSTEM_CFLAGS) \
	$(NTKDRPC_CFLAGS) \
	$(NULL)

libqspn_la_LIBADD = \
	-lm \
	$(GOBJECT_LIBS) \
	$(GEE_LIBS) \
	$(JSONGLIB_LIBS) \
	$(NTKDCOMMON_LIBS) \
	$(TASKLETSYSTEM_LIBS) \
	$(NTKDRPC_LIBS) \
	$(NULL)

qspnclient_SOURCES =  \
	main.vala \
	generic_naddr.vala \
	client_serialize_helpers.vala \
	mac-getter/hw.vapi \
	qspn.vapi \
	$(NULL)

qspnclient_VALAFLAGS = \
	--pkg gee-0.8 \
	--pkg ntkd-common \
	--pkg tasklet-system \
	--pkg pth-tasklet \
	--pkg ntkdrpc \
	$(NULL)

qspnclient_CPPFLAGS = \
	-w \
	$(GOBJECT_CFLAGS) \
	$(GEE_CFLAGS) \
	$(NTKDCOMMON_CFLAGS) \
	$(TASKLETSYSTEM_CFLAGS) \
	$(PTHTASKLET_CFLAGS) \
	$(NTKDRPC_CFLAGS) \
	$(NULL)

qspnclient_LDADD = \
	-lm \
	$(GOBJECT_LIBS) \
	$(GEE_LIBS) \
	$(NTKDCOMMON_LIBS) \
	$(TASKLETSYSTEM_LIBS) \
	$(PTHTASKLET_LIBS) \
	$(NTKDRPC_LIBS) \
	$(builddir)/libmacgetter.la \
	$(builddir)/libqspn.la \
	$(NULL)

test_serialize_helpers_SOURCES =  \
	testsuites/test_serialize_helpers/test_serialize_helpers.vala \
	testsuites/test_serialize_helpers/serialize_helpers.vala \
	$(NULL)

test_serialize_helpers_VALAFLAGS = \
	--pkg gee-0.8 \
	--pkg json-glib-1.0 \
	$(NULL)

test_serialize_helpers_CPPFLAGS = \
	-w \
	$(GOBJECT_CFLAGS) \
	$(GEE_CFLAGS) \
	$(JSONGLIB_CFLAGS) \
	$(NULL)

test_serialize_helpers_LDADD = \
	$(GOBJECT_LIBS) \
	$(GEE_LIBS) \
	$(JSONGLIB_LIBS) \
	$(NULL)

auto_graph_SOURCES = \
	testsuites/auto_graph/auto_graph.vala \
	$(NULL)

auto_graph_VALAFLAGS = \
	--pkg gee-0.8 \
	$(NULL)

auto_graph_CPPFLAGS = \
	-w \
	$(GOBJECT_CFLAGS) \
	$(GEE_CFLAGS) \
	$(NULL)

auto_graph_LDADD = -lm \
	$(GOBJECT_LIBS) \
	$(GEE_LIBS) \
	$(NULL)

simulator_SOURCES = \
	testsuites/simulator/simulator.vala \
	testsuites/simulator/generic_naddr.vala \
	testsuites/simulator/serialize_helpers.vala \
	qspn.vapi \
	$(NULL)

simulator_VALAFLAGS = \
	--pkg gee-0.8 \
	--pkg ntkd-common \
	--pkg tasklet-system \
	--pkg pth-tasklet \
	--pkg ntkdrpc \
	$(NULL)

simulator_CPPFLAGS = \
	-w \
	$(GOBJECT_CFLAGS) \
	$(GEE_CFLAGS) \
	$(NTKDCOMMON_CFLAGS) \
	$(TASKLETSYSTEM_CFLAGS) \
	$(PTHTASKLET_CFLAGS) \
	$(NTKDRPC_CFLAGS) \
	$(NULL)

simulator_LDADD = \
	$(GOBJECT_LIBS) \
	$(GEE_LIBS) \
	$(NTKDCOMMON_LIBS) \
	$(TASKLETSYSTEM_LIBS) \
	$(PTHTASKLET_LIBS) \
	$(NTKDRPC_LIBS) \
	$(builddir)/libqspn.la \
	$(NULL)

MAINTAINERCLEANFILES = \
	$(srcdir)/qspn.vapi \
	$(NULL)

qspn.vapi: libqspn_la_vala.stamp
	$(NULL)

