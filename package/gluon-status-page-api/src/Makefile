CFLAGS += -std=c99 -D_BSD_SOURCE

CFLAGS_JSONC = $(shell pkg-config --cflags json-c)
LDFLAGS_JSONC = $(shell pkg-config --libs json-c)

all: neighbours-routing-metrics neighbours-wifi-signal-levels respondd.so

neighbours-routing-metrics: neighbours-routing-metrics.c
	$(CC) $(CPPFLAGS) $(CFLAGS) $(CFLAGS_JSONC) $(LDFLAGS) $(LDFLAGS_JSONC) -Wall -o $@ $^ $(LDLIBS)

neighbours-wifi-signal-levels: neighbours-wifi-signal-levels.c
	$(CC) $(CPPFLAGS) $(CFLAGS) $(CFLAGS_JSONC) $(LDFLAGS) $(LDFLAGS_JSONC) -Wall -o $@ $^ $(LDLIBS) -liwinfo

respondd.so: respondd.c
	$(CC) $(CPPFLAGS) $(CFLAGS) $(LDFLAGS) -shared -fPIC -o $@ $^ $(LDLIBS)
