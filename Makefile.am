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
	$(NULL)

check_PROGRAMS = \
	test_qspn \
	$(NULL)

test_qspn_SOURCES = \
	testsuites/test_qspn/test_qspn.vala \
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
	$(srcdir)/testsuites/test_qspn/generic_naddr.c \
	$(srcdir)/testsuites/test_qspn/base_dispatcher.c \
	$(srcdir)/testsuites/test_qspn/test_qspn.c \
	$(NULL)

qspn.vapi: libqspn_la_vala.stamp
	$(NULL)

