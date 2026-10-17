export interface Brand {
	name: string;
	/** Registrable domains the brand actually uses. */
	domains: string[];
	/** Tokens scammers embed in lookalike domains. */
	keywords: string[];
}

// Only domains confirmed as official belong here: a wrong entry would mark a
// phishing site as legitimate.
export const BRANDS: Brand[] = [
	{ name: 'BCP', domains: ['viabcp.com'], keywords: ['bcp', 'viabcp', 'zonasegura'] },
	{ name: 'Yape', domains: ['yape.com.pe'], keywords: ['yape'] },
	{ name: 'Interbank', domains: ['interbank.pe'], keywords: ['interbank'] },
	{ name: 'BBVA', domains: ['bbva.pe', 'bbva.com'], keywords: ['bbva'] },
	{ name: 'Scotiabank', domains: ['scotiabank.com.pe', 'scotiabank.com'], keywords: ['scotiabank', 'scotia'] },
	{ name: 'Banco de la Nación', domains: ['bn.com.pe'], keywords: ['bancodelanacion', 'bancanacion'] },
	{ name: 'Mibanco', domains: ['mibanco.com.pe'], keywords: ['mibanco'] },
	{ name: 'BanBif', domains: ['banbif.com.pe'], keywords: ['banbif'] },
	{ name: 'Banco Falabella', domains: ['bancofalabella.pe', 'falabella.com.pe', 'falabella.com'], keywords: ['falabella'] },
	{ name: 'Ripley', domains: ['ripley.com.pe', 'bancoripley.com.pe'], keywords: ['ripley'] },
	{ name: 'SUNAT', domains: ['sunat.gob.pe'], keywords: ['sunat'] },
	{ name: 'Serpost', domains: ['serpost.com.pe'], keywords: ['serpost'] },
	{ name: 'Olva Courier', domains: ['olvacourier.com'], keywords: ['olva', 'olvacourier'] },
	{ name: 'Movistar', domains: ['movistar.com.pe', 'movistar.com'], keywords: ['movistar'] },
	{ name: 'Claro', domains: ['claro.com.pe'], keywords: ['claro'] },
	{ name: 'Entel', domains: ['entel.pe'], keywords: ['entel'] },
	{ name: 'Bitel', domains: ['bitel.com.pe'], keywords: ['bitel'] },
	{ name: 'Mercado Libre', domains: ['mercadolibre.com.pe', 'mercadolibre.com'], keywords: ['mercadolibre'] },
	{ name: 'Netflix', domains: ['netflix.com'], keywords: ['netflix'] },
	{ name: 'WhatsApp', domains: ['whatsapp.com', 'wa.me'], keywords: ['whatsapp'] }
];

export const URL_SHORTENERS = new Set([
	'bit.ly',
	'tinyurl.com',
	'cutt.ly',
	'is.gd',
	't.ly',
	'rebrand.ly',
	'shorturl.at',
	'ow.ly',
	'rb.gy',
	'tiny.cc',
	'acortar.link',
	'n9.cl',
	'l.ead.me',
	'goo.su'
]);

// TLDs that are cheap and disproportionately used in phishing campaigns.
export const SUSPICIOUS_TLDS = new Set([
	'xyz',
	'top',
	'shop',
	'click',
	'icu',
	'online',
	'site',
	'live',
	'lat',
	'buzz',
	'cfd',
	'sbs',
	'rest',
	'cyou',
	'monster',
	'vip',
	'info'
]);
