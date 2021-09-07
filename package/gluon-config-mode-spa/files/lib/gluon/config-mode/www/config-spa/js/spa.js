
const CONFIG_URL = '/cgi-bin/api/v1/config';

let config = {};
let options = {};

function globalState() {
	return {
		config: config,
		options: options
	}
}

async function loadToObject(obj, url, method) {
	const response = await fetch(url, { method: method} );
	const data = await response.json();
	for (var key in data) {
		delete obj[key];
		// ensure reactivity
		Vue.set(obj, key, data[key]);
	}
}

function getSchemaByPath(t, propertyPath) {
	let schema = t.options.schema;
	for (let key of propertyPath.split('.')) {
		if (schema && schema.properties && key in schema.properties) {
			schema = schema.properties[key];
		} else {
			return false;
		}
	}
	return schema;
}

function setByPath(t, propertyPath, value) {
	let obj = t.config;
	let path = propertyPath.split('.');
	let option = path.splice(-1);

	for (let key of path) {
		if (!(key in obj)) {
			Vue.set(obj, key, {})
		}
		obj = obj[key];
	}

	Vue.set(obj, option, value);
}

function getByPath(t, propertyPath) {
	let obj = t.config;

	for (let key of propertyPath.split('.')) {
		obj = obj[key];
	}

	return obj;
}

function propertyExistsInSchema(propertyPath) {
	return function () {
		return getSchemaByPath(this, propertyPath);
	}
};

Vue.component('gl-input-checkbox-object-or-false', {
	data () {
		return {
			content: this.value,
			restoredContent: {}
		}
	},
	model: 'value',
	props: ['value', 'id'],
	watch: {
		content: function (val) {
			if (val) {
				this.$emit('input', this.restoredContent);
			} else {
				if (this.value)
					this.restoredContent = this.value;

				this.$emit('input', false);
			}
		},
	},
	template: `
		<input class="gluon-input-checkbox" type="checkbox" :id="id" v-model="content">
	`,
});

Vue.component('gl-option', {
	data: globalState,
	props: ['name', 'description', 'path', 'objectOrFalse'],
	computed: {
		id: function () {
			return this.name.toLowerCase().replace(/ /g, '');
		},
		schema: function() {
			if (this.path)
				return getSchemaByPath(this, this.path);
			else
				return {};
		},
		type: function () {
			return this.schema.type || 'string';
		},
		enums: function () {
			console.assert(this.schema.enum);
			let enums = [];
			for (var i = 0; i < this.schema.enum.length; i++) {
				enums.push({
					value: this.schema.enum[i],
					title: this.schema.enum_titles[i]
				})
			}
			return enums;
		},
		value: {
			get() {
				return getByPath(this, this.path);
			},
			set(newValue) {
				if (this.schema.type == 'number')
					newValue = parseFloat(newValue);

				return setByPath(this, this.path, newValue);
			}
		}
	},
	template: `
		<div class="gluon-value">
			<label class="gluon-value-title" :for="id">{{ name }}</label>
			<div class="gluon-value-field">
				<input v-if="type === 'number'" v-model="value" class="gluon-input-text" type="text">
				<select v-if="'enum' in schema" v-model="value">
					<option value=""></option>
					<option v-for="e in enums" :value="e.value">{{ e.title }}</option>
				</select>
				<input v-else-if="type === 'string'" v-model="value" class="gluon-input-text" type="text">
				<template v-if="type === 'boolean' || objectOrFalse">
					<gl-input-checkbox-object-or-false v-if="objectOrFalse" v-model="value" :id="id" />
					<input class="gluon-input-checkbox" v-if="!objectOrFalse" type="checkbox" value="1" :id="id" v-model="value">
					<label :for="id"></label>
				</template>
				<br>
				<div v-if="description" class="gluon-value-description">{{ description }}</div>
			</div>
		</div>`
});


Vue.component('location', {
	data: globalState,
	computed: {
		hasLocation: propertyExistsInSchema('wizard.location')
	},
	template: `
	<div v-if="hasLocation" class="gluon-section-node">
		<gl-option name="Set Node Location" path="wizard.location" object-or-false=true />
		<template v-if="config.wizard.location">
			<gl-option name="Share Node Location" path="wizard.location.share_location" />
			<gl-option name="Latitude" path="wizard.location.lat" description="e.g. 53.873621" />
			<gl-option name="Longitude" path="wizard.location.lon" description="e.g. 10.689901" />
		</template>
	</div>
	`,
});

Vue.component('domain', {
	data: globalState,
	computed: {
		hasDomain: propertyExistsInSchema('wizard.domain')
	},
	template: `
	<div v-if="hasDomain" class="gluon-section-node">
		<gl-option name="Domain" path="wizard.domain" />
	</div>
	`,
});

let vue = new Vue({
	el: '#test',
	data: globalState,
	template: '<div> <domain /> <location /></div>',
	created: async function () {
		await this.load();
	},
	methods: {
		async load() {
			await loadToObject(this.config, CONFIG_URL, 'GET');
			await loadToObject(this.options, CONFIG_URL, 'OPTIONS');
		}
	}
});
