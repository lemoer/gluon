
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

function propertyExistsInSchema(propertyPath) {
	return function () {
		return getSchemaByPath(this, propertyPath);
	}
};

Vue.component('gl-option', {
	data () {
		return {
			content: this.value,
			options: options
		}
	},
	model: 'value',
	props: ['name', 'value', 'description', 'type', 'path'],
	computed: {
		id: function () {
			return this.name.toLowerCase().replace(/ /g, '');
		},
		enums: function () {
			if (!this.path)
				return [];

			let schema = getSchemaByPath(this, this.path);
			let enums = [];
			for (var i = 0; i < schema.enum.length; i++) {
				enums.push({
					value: schema.enum[i],
					title: schema.enum_titles[i]
				})
			}
			return enums;
		}
	},
	template: `
		<div class="gluon-value">
			<label class="gluon-value-title" :for="id">{{ name }}</label>
			<div class="gluon-value-field">
				<input v-if="type === 'number'" v-model="content" class="gluon-input-text" @input="onInput" type="text">
				<input v-if="type === 'text'" v-model="content" class="gluon-input-text" @input="onInput" type="text">
				<select v-if="type === 'dropdown'" v-model="content" @change="onInput">
					<option value=""></option>
					<option v-for="e in enums" :value="e.value">{{ e.title }}</option>
				</select>
				<template v-if="type === 'boolean'">
					<input class="gluon-input-checkbox" type="checkbox" value="1" :id="id" v-model="content" @input="onInput">
					<label :for="id"></label>
				</template>
				<br>
				<div v-if="description" class="gluon-value-description">{{ description }}</div>
			</div>
		</div>`,
	methods: {
		onInput(event) {
			// TODO: Remove this hacky stuff...
			if (this.type == 'boolean') {
				this.$emit('input', !this.content);
				return;
			}

			// Can add validation here
			this.$emit('input', this.content);
		},
	},
});

Vue.component('gl-object-enabler', {
	data () {
		return {
			content: this.value,
			restoredContent: {}
		}
	},
	model: 'value',
	props: ['name', 'value', 'description'],
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
		<gl-option :name="name" v-model="content" :description="description"
		           type="boolean"/>
	`,
});

Vue.component('location', {
	data: globalState,
	computed: {
		hasLocation: propertyExistsInSchema('wizard.location')
	},
	template: `
	<div v-if="hasLocation" class="gluon-section-node">
		<gl-object-enabler name="Set Node Location" v-model="config.wizard.location" />
		<template v-if="config.wizard.location">
			<gl-option name="Share Node Location" v-model.boolean="config.wizard.location.share_location" type="boolean" />
			<gl-option name="Latitude" v-model.number="config.wizard.location.lat" description="e.g. 53.873621" type="number" />
			<gl-option name="Longitude" v-model.number="config.wizard.location.lon" description="e.g. 10.689901" type="number" />
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
		<gl-option name="Domain" v-model="config.wizard.domain" type="dropdown" path="wizard.domain" />
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
