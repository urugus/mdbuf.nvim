// JSON-RPC types
export interface JsonRpcRequest {
  jsonrpc: '2.0';
  id: number | string;
  method: string;
  params?: unknown;
}

export interface JsonRpcResponse {
  jsonrpc: '2.0';
  id: number | string;
  result?: unknown;
  error?: JsonRpcError;
}

export interface JsonRpcError {
  code: number;
  message: string;
  data?: unknown;
}

// Render types
export interface RenderParams {
  markdown: string;
  filePath: string;
  viewport: {
    width: number;
    startLine?: number;
    endLine?: number;
  };
  options?: {
    css?: string;
    theme?: 'light' | 'dark';
  };
}

export interface SourceMap {
  lineToY: Record<number, number>;
  totalHeight: number;
}

export interface RenderResponse {
  imagePath: string;
  sourceMap: SourceMap;
  renderTime: number;
}

export interface PingResponse {
  status: 'ok';
  version: string;
}

// RPC method handlers
export interface RpcMethods {
  render: (params: RenderParams) => Promise<RenderResponse>;
  ping: () => PingResponse;
  shutdown: () => void;
}
