
const CONFIG_URL = '/cgi-bin/api/v1/config';

Vue.use(VueRouter);

let config = {};
let options = {};

function globalState() {
	return {
		config: config,
		options: options,
		translator: (msg) => msg // properly instantiated later
	}
}

// As we want to access the tranlator from multiple components, we store the
// promise here. That way the promise can then be awaited in all those components.
let language = (navigator.language || navigator.userLanguage).split('-')[0];
let translatorPromise = getTranslator(language);

async function getTranslator(lang) {
	let enTranslator = (msg) => msg;

	switch (lang) {
		case "en":
			return enTranslator;
		case "de":
			break;
		case "fr":
			break;
		default:
			console.warn('Locale for ' + lang + ' not found. Using english translation instead.');
			return enTranslator;
	}

	let poResponse = await fetch('i18n/' + lang + '.po');
	let poData = await poResponse.text();

	// wrap async
	let wrapByPromise = (readyFun) => {
		return new Promise(resolve => {
			readyFun(resolve);
		})
	}

	Pomo.load(poData, { format: 'po', mode: 'literal'});
	Pomo.unescapeStrings = true;
	await wrapByPromise(Pomo.ready);

	function pomoTranslator(msg) {
		let translation = Pomo.getText(msg, { error: () => {} });

		if (translation === undefined)
			return msg;

		return translation.translation;
	}

	return pomoTranslator;
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
	props: ['description', 'path', 'objectOrFalse'],
	created: async function() {
		this.translator = await translatorPromise;
	},
	computed: {
		id: function () {
			return this.title.toLowerCase().replace(/ /g, '');
		},
		schema: function() {
			return getSchemaByPath(this, this.path);
		},
		type: function () {
			return this.schema.type || 'string';
		},
		title: function () {
			return this.translator(this.schema.title);
		},
		enums: function () {
			let enums = [];
			for (var i = 0; i < this.schema.enum.length; i++) {
				enums.push({
					value: this.schema.enum[i],
					title: this.translator(this.schema.enum_titles[i])
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
		},
		translatedDescription: function () {
			return this.translator(this.description)
		}
	},
	template: `
		<div class="gluon-value">
			<label class="gluon-value-title" :for="id">{{ title }}</label>
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
				<div v-if="description" class="gluon-value-description">{{ translatedDescription }}</div>
			</div>
		</div>`
});

Vue.component('gl-descr', {
	data: globalState,
	created: async function() {
		this.translator = await translatorPromise;
	},
	computed: {
		translated: function () {
			let trimAndRemoveNewlines =
				(txt) => txt.split('\n').map((s) => s.trim()).join(' ').trim();
			let content = trimAndRemoveNewlines(unescape(this.$slots.default[0].text));
			return this.translator(content);
		}
	},
	template: `
		<div class="gluon-section-descr" v-html="translated">
		</div>
	`
})


Vue.component('location', {
	data: globalState,
	computed: {
		hasLocation: propertyExistsInSchema('wizard.location')
	},
	template: `
	<fieldset v-if="hasLocation" class="gluon-section">
		<gl-descr>
			If you want the location of your node to be displayed on public
			maps, you can enter its coordinates here.
		</gl-descr>
		<gl-option path="wizard.location" object-or-false=true />
		<template v-if="config.wizard.location">
			<gl-option path="wizard.location.share_location" />
			<gl-option path="wizard.location.lat" description="e.g. 53.873621" />
			<gl-option path="wizard.location.lon" description="e.g. 10.689901" />
		</template>
	</fieldset>
	`,
});

Vue.component('domain', {
	data: globalState,
	computed: {
		hasDomain: propertyExistsInSchema('wizard.domain')
	},
	template: `
	<fieldset v-if="hasDomain" class="gluon-section">
		<gl-option path="wizard.domain" />
	</fieldset>
	`,
});

Vue.component('contact', {
	data: globalState,
	computed: {
		hasContact: propertyExistsInSchema('wizard.contact')
	},
	template: `
	<fieldset v-if="hasContact" class="gluon-section">
		<gl-descr>
			Please provide your contact information here to allow others to contact
			you. Note that this information will be visible %3Cem%3Epublicly%3C/em%3E
			on the internet together with your node's coordinates. This means it
			can be downloaded and processed by anyone. This information is not
			required to operate a node. If you chose to enter data, it will be
			stored on this node and can be deleted by yourself at any time.
		</gl-descr>
		<gl-option path="wizard.contact" description="e.g. mail or phone number"/>
	</fieldset>
	`,
});

let wizard = Vue.component('wizard', {
	template: `
	<div>
		<h2 name="content">Willkommen!</h2>

		<p>
			Willkommen zum Einrichtungsassistenten für deinen neuen Hannoveraner
			Freifunk-Knoten. Fülle das folgende Formular deinen Vorstellungen
			entsprechend aus und sende es ab.
		</p>

		<fieldset class="gluon-section">
			<gl-descr>
				Dieser Knoten aktualisiert seine Firmware automatisch, sobald
				eine neue Version vorliegt.
			</gl-descr>
		</fieldset>

		<domain />
		<location />
		<contact />
	</div>
	`
});

const router = new VueRouter({
	routes: [
		{ path: '/wizard', component: wizard },
		{ path: '/', redirect: '/wizard'}
	]
});

let vue = new Vue({
	el: '#app',
	data: globalState,
	router: router,
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
