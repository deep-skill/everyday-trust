export type CaseVerdict = 'high_risk' | 'suspicious' | 'no_signals_detected' | 'inconclusive';
export interface CaseResult {
  id: string;
  analysis_status: string;
  revision: number;
  verdict: CaseVerdict;
  baseline_verdict: CaseVerdict;
  risk_origin: string;
  summary: string;
  signals: { id: string; severity: string; message: string; checked_at: string; source: string }[];
  advice: string[];
  domains: { domain: string | null; official_brand: string | null; age_status: string; redirect_status: string; destination_status?: string; checked_hosts?: string[]; feed_status?: string; feed_checked_at?: string; feed_published_at?: string }[];
  coverage: Record<string, string>;
  analysis_mode: string;
  analyzed_at: string;
  expires_at?: string;
}
export interface HistoryItem { id: string; result: CaseResult; created_at: string }
export const verdictLabels: Record<CaseVerdict, string> = {
  high_risk: 'Alto riesgo', suspicious: 'Sospechoso', no_signals_detected: 'Sin señales detectadas', inconclusive: 'Indeterminado'
};
