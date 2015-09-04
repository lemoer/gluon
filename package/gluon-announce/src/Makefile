all: announce.so

announce.so: announce.c
	$(CC) -shared -Iinclude $(CPPFLAGS) $(CFLAGS) $(LDFLAGS) -Wall -o $@ $^ $(LDLIBS) -llua
