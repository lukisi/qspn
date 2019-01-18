NULL = 
ACLOCAL_AMFLAGS = -I m4

noinst_LTLIBRARIES = \
	libqspn.la \
	$(NULL)

TESTS = \
	test_serializables \
	two_nodes \
	$(NULL)

check_PROGRAMS = \
	test_serializables \
	system_peer \
	$(NULL)

libqspn_la_SOURCES = \
	api.vala \
	qspn.vala \
	destinations.vala \
	etp_message.vala \
	etp_retrieve.vala \
	etp_publish.vala \
	missing_arcs.vala \
	rngen.vala \
	serializables.vala \
	$(NULL)

libqspn_la_VALAFLAGS = \
	-H qspn.h \
	--library qspn \
	--vapidir $(GEE_PREFIX)/share/vala/vapi \
	--vapidir $(JSON_PREFIX)/share/vala-0.36/vapi \
	--vapidir $(TASKLETSYSTEM_VAPIDIR) \
	--vapidir $(NTKDCOMMON_VAPIDIR) \
	--vapidir $(NTKDRPC_VAPIDIR) \
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

test_serializables_SOURCES =  \
	testsuites/test_serializables/test_serializables.vala \
	testsuites/test_serializables/serializables.vala \
	$(NULL)

test_serializables_VALAFLAGS = \
	--vapidir $(GEE_PREFIX)/share/vala/vapi \
	--vapidir $(JSON_PREFIX)/share/vala-0.36/vapi \
	--pkg gee-0.8 \
	--pkg json-glib-1.0 \
	$(NULL)

test_serializables_CPPFLAGS = \
	-w \
	$(GOBJECT_CFLAGS) \
	$(GEE_CFLAGS) \
	$(JSONGLIB_CFLAGS) \
	$(NULL)

test_serializables_LDADD = \
	$(GOBJECT_LIBS) \
	$(GEE_LIBS) \
	$(JSONGLIB_LIBS) \
	$(NULL)

system_peer_SOURCES =  \
	testsuites/system_peer/system_peer.vala \
	testsuites/system_peer/rngen.vala \
	testsuites/system_peer/serializables.vala \
	testsuites/system_peer/qspn_helpers.vala \
	testsuites/system_peer/qspn_signals.vala \
	testsuites/system_peer/rpc/module_stubs.vala \
	testsuites/system_peer/rpc/skeleton_factory.vala \
	testsuites/system_peer/rpc/stub_factory.vala \
	testsuites/system_peer/task_idarc.vala \
	testsuites/system_peer/task_enter_net.vala \
	testsuites/system_peer/task_migrate.vala \
	qspn.vapi \
	$(NULL)

system_peer_VALAFLAGS = \
	--vapidir $(GEE_PREFIX)/share/vala/vapi \
	--vapidir $(TASKLETSYSTEM_VAPIDIR) \
	--vapidir $(PTHTASKLET_VAPIDIR) \
	--vapidir $(NTKDCOMMON_VAPIDIR) \
	--vapidir $(NTKDRPC_VAPIDIR) \
	--pkg gee-0.8 \
	--pkg ntkd-common \
	--pkg tasklet-system \
	--pkg pth-tasklet \
	--pkg ntkdrpc \
	$(NULL)

system_peer_CPPFLAGS = \
	-w \
	$(GOBJECT_CFLAGS) \
	$(GEE_CFLAGS) \
	$(NTKDCOMMON_CFLAGS) \
	$(TASKLETSYSTEM_CFLAGS) \
	$(PTHTASKLET_CFLAGS) \
	$(NTKDRPC_CFLAGS) \
	$(NULL)

system_peer_LDADD = \
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

