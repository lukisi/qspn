NULL = 
ACLOCAL_AMFLAGS = -I m4

noinst_LTLIBRARIES = \
	libqspn.la \
	$(NULL)

noinst_PROGRAMS =  \
	qspnclient \
	$(NULL)

TESTS = \
	test_serialize_helpers \
	$(NULL)

check_PROGRAMS = \
	test_serialize_helpers \
	$(NULL)

EXTRA_PROGRAMS = \
	auto_graph \
	simulator \
	discover_paths \
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
	--pkg ntkd-common \
	--pkg ntkd-tasklet-system \
	--pkg ntkdrpc\
	--pkg zcd-tasklet-system \
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

libqspn_la_LIBADD = -lm \
	$(GOBJECT_LIBS) \
	$(GEE_LIBS) \
	$(JSONGLIB_LIBS) \
	$(NTKDCOMMON_LIBS) \
	$(TASKLETSYSTEM_LIBS) \
	$(NTKDRPC_LIBS) \
	$(NULL)

qspnclient_SOURCES =  \
	main.vala \
	tasklet_system_tasklet.vala \
	base_fake_address_manager.vala \
	qspn.vapi \
	$(NULL)

qspnclient_VALAFLAGS = \
	--pkg gee-0.8 \
	--pkg ntkd-common \
	--pkg ntkd-tasklet-system \
	--pkg tasklet \
	--pkg ntkdrpc \
	--pkg zcd-tasklet-system \
	$(NULL)

qspnclient_CPPFLAGS = \
	-w \
	$(GOBJECT_CFLAGS) \
	$(GEE_CFLAGS) \
	$(NTKDCOMMON_CFLAGS) \
	$(TASKLETSYSTEM_CFLAGS) \
	$(TASKLET_CFLAGS) \
	$(NTKDRPC_CFLAGS) \
	$(NULL)

qspnclient_LDADD = \
	$(GOBJECT_LIBS) \
	$(GEE_LIBS) \
	$(NTKDCOMMON_LIBS) \
	$(TASKLETSYSTEM_LIBS) \
	$(TASKLET_LIBS) \
	$(NTKDRPC_LIBS) \
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

discover_paths_SOURCES = \
	testsuites/discover_paths/discover_paths.vala \
	testsuites/discover_paths/tasklet_system_tasklet.vala \
	testsuites/discover_paths/fake_classes.vala \
	testsuites/discover_paths/generic_naddr.vala \
	testsuites/discover_paths/base_fake_address_manager.vala \
	qspn.vapi \
	$(NULL)

discover_paths_VALAFLAGS = \
	--pkg gee-0.8 \
	--pkg ntkd-common \
	--pkg ntkd-tasklet-system \
	--pkg tasklet \
	--pkg ntkdrpc \
	--pkg zcd-tasklet-system \
	$(NULL)

discover_paths_CPPFLAGS = \
	-w \
	$(GOBJECT_CFLAGS) \
	$(GEE_CFLAGS) \
	$(TASKLET_CFLAGS) \
	$(NTKDRPC_CFLAGS) \
	$(NULL)

discover_paths_LDADD = \
	$(GOBJECT_LIBS) \
	$(GEE_LIBS) \
	$(TASKLET_LIBS) \
	$(NTKDRPC_LIBS) \
	$(builddir)/libqspn.la \
	$(NULL)

simulator_SOURCES = \
	testsuites/simulator/simulator.vala \
	testsuites/simulator/tasklet_system_tasklet.vala \
	testsuites/simulator/base_fake_address_manager.vala \
	testsuites/simulator/generic_naddr.vala \
	testsuites/simulator/serialize_helpers.vala \
	qspn.vapi \
	$(NULL)

simulator_VALAFLAGS = \
	--pkg gee-0.8 \
	--pkg ntkd-common \
	--pkg ntkd-tasklet-system \
	--pkg tasklet \
	--pkg ntkdrpc \
	--pkg zcd-tasklet-system \
	$(NULL)

simulator_CPPFLAGS = \
	-w \
	$(GOBJECT_CFLAGS) \
	$(GEE_CFLAGS) \
	$(NTKDCOMMON_CFLAGS) \
	$(TASKLETSYSTEM_CFLAGS) \
	$(TASKLET_CFLAGS) \
	$(NTKDRPC_CFLAGS) \
	$(NULL)

simulator_LDADD = \
	$(GOBJECT_LIBS) \
	$(GEE_LIBS) \
	$(NTKDCOMMON_LIBS) \
	$(TASKLETSYSTEM_LIBS) \
	$(TASKLET_LIBS) \
	$(NTKDRPC_LIBS) \
	$(builddir)/libqspn.la \
	$(NULL)

MAINTAINERCLEANFILES = \
	$(srcdir)/qspn.vapi \
	$(NULL)

qspn.vapi: libqspn_la_vala.stamp
	$(NULL)

