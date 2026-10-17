export type Verdict = 'scam' | 'suspicious' | 'likely_safe' | 'unknown';

export type Severity = 'high' | 'medium' | 'low' | 'info';

export interface Signal {
	id: string;
	severity: Severity;
	message: string;
}

export interface UrlFinding {
	input: string;
	finalUrl: string;
	hostname: string;
	registrableDomain: string | null;
	officialBrand: string | null;
	imitatedBrand: string | null;
	domainAgeDays: number | null;
	signals: Signal[];
}

export interface PhoneFinding {
	input: string;
	normalized: string;
	country: 'PE' | 'foreign' | 'unknown';
	signals: Signal[];
}

export interface AnalysisResult {
	verdict: Verdict;
	score: number;
	summary: string;
	urls: UrlFinding[];
	phones: PhoneFinding[];
	signals: Signal[];
	advice: string[];
}
