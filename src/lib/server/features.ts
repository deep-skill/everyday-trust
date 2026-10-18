import { env } from '$env/dynamic/private';
export function features() {
  return {
    safe_browsing: env.SAFE_BROWSING_ENABLED === 'true',
    urlscan: env.URLSCAN_ENABLED === 'true',
    report_actions: env.REPORT_ACTIONS_ENABLED === 'true',
    image_input: env.IMAGE_INPUT_ENABLED === 'true',
    community_reports: env.COMMUNITY_REPORTS_ENABLED === 'true'
  };
}
