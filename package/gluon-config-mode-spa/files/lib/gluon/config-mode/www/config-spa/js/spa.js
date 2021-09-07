
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

function propertyExistsInSchema(propertyPath) {
	return function () {
		let schema = this.options.schema;
		for (let key of propertyPath.split('.')) {
			if (schema && schema.properties && key in schema.properties) {
				schema = schema.properties[key];
			} else {
				return false;
			}
		}
		return true;
	}
};


Vue.component('gl-option', {
	data () {
		return {
			content: this.value
		}
	},
	model: 'value',
	props: ['name', 'value', 'description', 'type'],
	computed: {
		id: function () {
			return this.name.toLowerCase().replace(/ /mg, '');
		}
	},
	template: `
		<div class="gluon-value">
			<label class="gluon-value-title" :for="id">{{ name }}</label>
			<div class="gluon-value-field">
				<input v-if="type === 'number'" v-model="content" class="gluon-input-text" @input="onInput" type="text">
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

Vue.component('location', {
	data: function () {
		return {
			config: config,
			options: options,
			show: true,
			locationBackup: {}
		}
	},
	computed: {
		hasLocation: propertyExistsInSchema('wizard.location')
	},
	watch: {
		show: function (val) {
			if (val) {
				Vue.set(config.wizard, 'location', this.locationBackup);
			} else {
				if (config.wizard.location)
					this.locationBackup = config.wizard.location;

				Vue.set(config.wizard, 'location', false);
			}
		},
	},
	template: `
	<div v-if="hasLocation" class="gluon-section-node">
		<gl-option name="Set Location" type="boolean" v-model.boolean="show" />
		<template v-if="config.wizard.location">
			<gl-option name="Share Node Location" v-model.boolean="config.wizard.location.share_location" type="boolean" />
			<gl-option name="Latitude" v-model.number="config.wizard.location.lat" description="e.g. 53.873621" type="number" />
			<gl-option name="Longitude" v-model.number="config.wizard.location.lon" description="e.g. 10.689901" type="number" />
		</template>
	</div>
	`,
});

let vue = new Vue({
	el: '#test',
	data: globalState,
	template: '<div><location /></div>',
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
