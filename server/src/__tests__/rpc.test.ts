import { describe, expect, it } from 'vitest';
import { ErrorCodes, VERSION, createRpcProcessor } from '../rpc.js';
import type { RenderResponse, RpcMethods } from '../types.js';

const createTestHarness = (methods: RpcMethods) => {
  const responses: unknown[] = [];
  const exits: number[] = [];

  const sendResponse = (response: unknown) => {
    responses.push(response);
  };

  const exit = ((code?: number) => {
    exits.push(code ?? 0);
    return undefined as never;
  }) as (code?: number) => never;

  const { handleRequest } = createRpcProcessor(methods, sendResponse, exit);

  return { exits, handleRequest, responses };
};

describe('createRpcProcessor().handleRequest', () => {
  it('JSON parse error を返す', async () => {
    const methods: RpcMethods = {
      render: async () => ({}) as RenderResponse,
      ping: () => ({ status: 'ok', version: VERSION }),
      shutdown: () => {},
    };
    const h = createTestHarness(methods);

    await h.handleRequest('{');

    expect(h.responses).toHaveLength(1);
    expect(h.responses[0]).toMatchObject({
      jsonrpc: '2.0',
      id: 0,
      error: { code: ErrorCodes.PARSE_ERROR },
    });
  });

  it('Invalid Request を返す', async () => {
    const methods: RpcMethods = {
      render: async () => ({}) as RenderResponse,
      ping: () => ({ status: 'ok', version: VERSION }),
      shutdown: () => {},
    };
    const h = createTestHarness(methods);

    await h.handleRequest(JSON.stringify({ foo: 'bar' }));

    expect(h.responses).toHaveLength(1);
    expect(h.responses[0]).toMatchObject({
      jsonrpc: '2.0',
      id: 0,
      error: { code: ErrorCodes.INVALID_REQUEST },
    });
  });

  it('Method not found を返す', async () => {
    const methods: RpcMethods = {
      render: async () => ({}) as RenderResponse,
      ping: () => ({ status: 'ok', version: VERSION }),
      shutdown: () => {},
    };
    const h = createTestHarness(methods);

    await h.handleRequest(JSON.stringify({ jsonrpc: '2.0', id: 1, method: 'nope' }));

    expect(h.responses).toHaveLength(1);
    expect(h.responses[0]).toMatchObject({
      jsonrpc: '2.0',
      id: 1,
      error: { code: ErrorCodes.METHOD_NOT_FOUND },
    });
  });

  it('ping を処理する', async () => {
    let called = 0;
    const methods: RpcMethods = {
      render: async () => ({}) as RenderResponse,
      ping: () => {
        called++;
        return { status: 'ok', version: VERSION };
      },
      shutdown: () => {},
    };
    const h = createTestHarness(methods);

    await h.handleRequest(JSON.stringify({ jsonrpc: '2.0', id: 2, method: 'ping' }));

    expect(h.responses).toHaveLength(1);
    expect(h.responses[0]).toMatchObject({
      jsonrpc: '2.0',
      id: 2,
      result: { status: 'ok', version: VERSION },
    });
    expect(called).toBe(1);
  });

  it('render を methods.render に委譲する', async () => {
    const methods: RpcMethods = {
      render: async (params) => ({ ok: true, params }) as unknown as RenderResponse,
      ping: () => ({ status: 'ok', version: VERSION }),
      shutdown: () => {},
    };
    const h = createTestHarness(methods);

    await h.handleRequest(
      JSON.stringify({
        jsonrpc: '2.0',
        id: 3,
        method: 'render',
        params: { markdown: '# hi' },
      })
    );

    expect(h.responses).toHaveLength(1);
    expect(h.responses[0]).toMatchObject({
      jsonrpc: '2.0',
      id: 3,
      result: { ok: true },
    });
  });

  it('メソッド例外は INTERNAL_ERROR を返す', async () => {
    const methods: RpcMethods = {
      render: async () => {
        throw new Error('boom');
      },
      ping: () => ({ status: 'ok', version: VERSION }),
      shutdown: () => {},
    };
    const h = createTestHarness(methods);

    await h.handleRequest(JSON.stringify({ jsonrpc: '2.0', id: 4, method: 'render' }));

    expect(h.responses).toHaveLength(1);
    expect(h.responses[0]).toMatchObject({
      jsonrpc: '2.0',
      id: 4,
      error: { code: ErrorCodes.INTERNAL_ERROR, message: 'boom' },
    });
  });

  it('shutdown は成功レスポンス後に exit(0) する', async () => {
    let shutdownCalled = 0;
    const methods: RpcMethods = {
      render: async () => ({}) as RenderResponse,
      ping: () => ({ status: 'ok', version: VERSION }),
      shutdown: () => {
        shutdownCalled++;
      },
    };
    const h = createTestHarness(methods);

    await h.handleRequest(JSON.stringify({ jsonrpc: '2.0', id: 5, method: 'shutdown' }));

    expect(h.responses).toHaveLength(1);
    expect(h.responses[0]).toMatchObject({ jsonrpc: '2.0', id: 5, result: {} });
    expect(h.exits).toEqual([0]);
    expect(shutdownCalled).toBe(1);
  });
});
