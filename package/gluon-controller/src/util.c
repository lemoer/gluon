#include "util.h"

#include <stdio.h>
#include <ctype.h>
#include <assert.h>
#include <stddef.h>
#include <string.h>
#include <stdarg.h>

bool is_ipv6_link_local(const char *address) {
	if (strlen(address) < 3)
		return false;

	if (!index(address, ':'))
		return false;

	if (address[0] != 'f' || address[1] != 'e')
		return false;

	const char *nibble_3 = "89ab";
	if (!index(nibble_3, address[2]))
		return false;

	if (!isxdigit(address[3]))
		return false;

	return true;
}


bool gluon_json_get_path(json_object *obj, void *dest, enum json_type T, int depth, ...) {
	va_list sp;

	va_start(sp, depth);
	json_object *el = obj;

	for(int i = 0; i < depth; i++) {
		const char *field_name = va_arg(sp, const char*);
		el = json_object_object_get(el, field_name);

		if (!el)
			return false;
	}

	if (json_object_get_type(el) != T)
		return false;

	switch (T) {
		case json_type_int:
			*((int*) dest) = json_object_get_int(el);
			break;
		case json_type_string:
			*((const char**) dest) = json_object_get_string(el);
			break;
		case json_type_array:
			*((struct json_object **) dest) = el;
			break;
		default:
			fprintf(stderr, "Error: gluon_json_get_path() NIY!\n");
			exit(1);
			assert(false); // NIY
	}

	return true;
}

bool gluon_json_string_array_contains(json_object *haystack, const char *needle) {
	for (int i = 0; i < json_object_array_length(haystack); i++) {
		json_object *el = json_object_array_get_idx(haystack, i);
		const char *str = json_object_get_string(el);
		if (!str)
			continue;

		if (!strcmp(str, needle))
			return true;
	}

	return false;
}
