#pragma once

#include <json-c/json.h>
#include <stdbool.h>

bool is_ipv6_link_local(const char *address);
bool gluon_json_get_path(json_object *obj, void *dest, enum json_type T, int depth, ...);
bool gluon_json_string_array_contains(json_object *haystack, const char *needle);
