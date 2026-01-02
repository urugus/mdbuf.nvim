import { closeRenderer, getRenderer } from './renderer.js';
import { VERSION, createRpcServer } from './rpc.js';

const main = async (): Promise<void> => {
  // Initialize renderer
  console.error('[mdbuf-server] Initializing Playwright renderer...');
  const renderer = await getRenderer();
  console.error('[mdbuf-server] Renderer initialized');

  // Create RPC server
  const server = createRpcServer({
    render: (params) => renderer.render(params),
    ping: () => ({ status: 'ok', version: VERSION }),
    shutdown: async () => {
      await closeRenderer();
      process.exit(0);
    },
  });

  // Handle cleanup on exit
  process.on('exit', () => {
    closeRenderer().catch(console.error);
  });

  // Start server
  server.listen();
};

main().catch((error) => {
  console.error('[mdbuf-server] Fatal error:', error);
  process.exit(1);
});
