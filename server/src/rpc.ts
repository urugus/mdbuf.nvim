import { createInterface } from 'node:readline';
import type { JsonRpcError, JsonRpcRequest, JsonRpcResponse, RpcMethods } from './types.js';

const VERSION = '0.1.0';

/**
 * JSON-RPC 2.0 error codes
 */
const ErrorCodes = {
  PARSE_ERROR: -32700,
  INVALID_REQUEST: -32600,
  METHOD_NOT_FOUND: -32601,
  INVALID_PARAMS: -32602,
  INTERNAL_ERROR: -32603,
} as const;

/**
 * Create a JSON-RPC error response
 */
function createErrorResponse(
  id: number | string | null,
  code: number,
  message: string,
  data?: unknown
): JsonRpcResponse {
  return {
    jsonrpc: '2.0',
    id: id ?? 0,
    error: { code, message, data },
  };
}

/**
 * Create a JSON-RPC success response
 */
function createSuccessResponse(id: number | string, result: unknown): JsonRpcResponse {
  return {
    jsonrpc: '2.0',
    id,
    result,
  };
}

/**
 * Create and start JSON-RPC server over stdio
 */
export function createRpcServer(methods: RpcMethods) {
  const rl = createInterface({
    input: process.stdin,
    output: process.stdout,
    terminal: false,
  });

  function sendResponse(response: JsonRpcResponse): void {
    const json = JSON.stringify(response);
    process.stdout.write(`${json}\n`);
  }

  async function handleRequest(line: string): Promise<void> {
    let request: JsonRpcRequest;

    // Parse JSON
    try {
      request = JSON.parse(line);
    } catch {
      sendResponse(createErrorResponse(null, ErrorCodes.PARSE_ERROR, 'Parse error'));
      return;
    }

    // Validate request
    if (
      request.jsonrpc !== '2.0' ||
      typeof request.method !== 'string' ||
      request.id === undefined
    ) {
      sendResponse(
        createErrorResponse(request.id ?? null, ErrorCodes.INVALID_REQUEST, 'Invalid Request')
      );
      return;
    }

    // Handle methods
    try {
      let result: unknown;

      switch (request.method) {
        case 'render':
          result = await methods.render(request.params as Parameters<RpcMethods['render']>[0]);
          break;

        case 'ping':
          result = { status: 'ok', version: VERSION };
          break;

        case 'shutdown':
          sendResponse(createSuccessResponse(request.id, {}));
          process.exit(0);
          break; // unreachable but satisfies linter

        default:
          sendResponse(
            createErrorResponse(
              request.id,
              ErrorCodes.METHOD_NOT_FOUND,
              `Method not found: ${request.method}`
            )
          );
          return;
      }

      sendResponse(createSuccessResponse(request.id, result));
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Unknown error';
      sendResponse(createErrorResponse(request.id, ErrorCodes.INTERNAL_ERROR, message));
    }
  }

  return {
    listen(): void {
      // Log to stderr so it doesn't interfere with JSON-RPC
      console.error(`[mdbuf-server] Starting JSON-RPC server v${VERSION}`);

      rl.on('line', (line) => {
        if (line.trim()) {
          handleRequest(line).catch((error) => {
            console.error('[mdbuf-server] Unhandled error:', error);
          });
        }
      });

      rl.on('close', () => {
        console.error('[mdbuf-server] Connection closed');
        process.exit(0);
      });

      // Handle process signals
      process.on('SIGTERM', () => {
        console.error('[mdbuf-server] Received SIGTERM');
        process.exit(0);
      });

      process.on('SIGINT', () => {
        console.error('[mdbuf-server] Received SIGINT');
        process.exit(0);
      });
    },
  };
}
