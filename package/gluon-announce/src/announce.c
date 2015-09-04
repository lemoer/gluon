#include <sys/types.h>
#include <sys/stat.h>
#include <dirent.h>
#include <unistd.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>

#define GLUON_announce "gluon.announce"
#define ANNOUNCE_READER_BUFFER 512

static int _announce_collect_dir_fd(lua_State *L, int dir_fd);

struct announce_lua_reader_state {
  int fd;
  char buf[ANNOUNCE_READER_BUFFER];
};

const char* _announce_lua_reader(lua_State *L, void *data, size_t *size) {
  struct announce_lua_reader_state *state = data;
  *size = read(state->fd, state->buf, ANNOUNCE_READER_BUFFER);
  if (*size < 0) {
    perror("read");
    return NULL;
  }
  return state->buf;
}

static int _announce_collect_entry(lua_State *L, int fd, const char *name) {
  struct stat stat;
  struct announce_lua_reader_state reader_state;

  if (fstat(fd, &stat) < 0) {
    perror("fstat");
    return 0;
  }

  if (stat.st_mode & S_IFDIR)
    return _announce_collect_dir_fd(L, fd);

  if (!(stat.st_mode & (S_IFREG | S_IFLNK)))
    return 0;

  reader_state.fd = fd;
  lua_load(L, _announce_lua_reader, &reader_state, name);

  return 1;
}

static int _announce_collect_dir_fd(lua_State *L, int dir_fd) {
  DIR *dir = fdopendir(dir_fd);
  struct dirent *file;
  int file_fd;

  if (dir == NULL) {
    perror("opendir");
    return 0;
  }

  lua_newtable(L);
  while (file = readdir(dir)) {
    if (file->d_name[0] == '.')
      continue;

    file_fd = openat(dir_fd, file->d_name, O_RDONLY);
    if (file_fd < 0) {
      perror("openat");
      continue;
    }

    if (_announce_collect_entry(L, file_fd, file->d_name))
      lua_setfield(L, -2, file->d_name);
  }

  return 1;
}

static int announce_collect_dir(lua_State *L) {
  const char *path = lua_tostring(L, 1);
  int fd = open(path, O_RDONLY);

  if (fd < 0) {
    perror("open");
    return 0;
  }

  return _announce_collect_dir_fd(L, fd);
}

static int announce_exec_tree(lua_State *L) {
  int items = 0;
  lua_newtable(L);
  lua_pushnil(L);
  while (lua_next(L, 1)) {
    if (lua_isfunction(L, -1)) {
      if (lua_pcall(L, 0, 1, 0)) {
        fprintf(stderr, "%s\n", lua_tostring(L, -1));
        lua_pop(L, 1);
        continue;
      }
    }
    else if (lua_istable(L, -1)) {
      lua_pushcfunction(L, announce_exec_tree);
      lua_insert(L, -2);
      lua_call(L, 1, 1);
    }

    lua_pushvalue(L, -2);
    lua_insert(L, -3);
    lua_settable(L, -4);
    items++;
  }
  if (items == 0) {
    lua_newtable(L);
    lua_pushboolean(L, 1);
    lua_settable(L, -3);
  }
  return 1;
}

static int _announce_exec_tree_closure(lua_State *L) {
  // expects component on stack

  lua_pushstring(L, ".d");
  lua_concat(L, 2);
  lua_gettable(L, lua_upvalueindex(1));
  if (!lua_isnil(L, -1)) {
    lua_pushcfunction(L, announce_exec_tree);
    lua_insert(L, -2);
    lua_call(L, 1, 1);
  }

  return 1;
}

static int announce_init(lua_State *L) {
  // expect path on stack

  char initfile[PATH_MAX];
  snprintf(initfile, PATH_MAX, "%s/%s", lua_tostring(L, 1), ".init.lua");

  lua_pushcfunction(L, announce_collect_dir);
  lua_pushvalue(L, 1);
  lua_call(L, 1, 1);

  luaL_dofile(L, initfile);

  lua_pushcclosure(L, _announce_exec_tree_closure, 1);
  return 1;
}

const struct luaL_reg announce_methods[] = {
  { "collect_dir",      announce_collect_dir   },
  { "exec_tree",        announce_exec_tree     },
  { "init",             announce_init          },

  { }
};

int luaopen_gluon_announce(lua_State *L) {
  luaL_register(L, GLUON_announce, announce_methods);

  return 1;
}
