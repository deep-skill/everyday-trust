declare global {
	namespace App {
		interface Platform {
			env: {
				ANTHROPIC_API_KEY?: string;
			};
			ctx: ExecutionContext;
			caches: CacheStorage & { default: Cache };
		}
	}
}

export {};
