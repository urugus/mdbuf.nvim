import { mkdir, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { type Browser, type Page, chromium } from 'playwright';
import { generateHtmlDocument, markdownToHtml } from './markdown.js';
import type { RenderParams, RenderResponse, SourceMap } from './types.js';

export class Renderer {
  private browser: Browser | null = null;
  private page: Page | null = null;
  private outputDir: string;
  private renderCount = 0;

  constructor() {
    this.outputDir = join(tmpdir(), 'mdbuf');
  }

  async init(): Promise<void> {
    await mkdir(this.outputDir, { recursive: true });

    this.browser = await chromium.launch({
      headless: true,
    });

    this.page = await this.browser.newPage();
  }

  async close(): Promise<void> {
    if (this.page) {
      await this.page.close();
      this.page = null;
    }
    if (this.browser) {
      await this.browser.close();
      this.browser = null;
    }
  }

  async render(params: RenderParams): Promise<RenderResponse> {
    if (!this.page) {
      throw new Error('Renderer not initialized');
    }

    const startTime = performance.now();

    // Convert markdown to HTML
    const htmlBody = markdownToHtml(params.markdown);

    // Generate full HTML document
    const html = generateHtmlDocument(htmlBody, {
      width: params.viewport.width,
      theme: params.options?.theme || 'light',
      customCss: params.options?.css,
    });

    // Set page content and wait for Mermaid to render
    await this.page.setContent(html, { waitUntil: 'networkidle' });

    // Wait for Mermaid diagrams to render (if any)
    await this.page.evaluate(() => {
      return new Promise<void>((resolve) => {
        const mermaidElements = document.querySelectorAll('.mermaid');
        if (mermaidElements.length === 0) {
          resolve();
          return;
        }
        // Wait a bit for Mermaid to process
        setTimeout(resolve, 500);
      });
    });

    // Set viewport
    await this.page.setViewportSize({
      width: params.viewport.width,
      height: 800, // Initial height, will expand for full page
    });

    // Generate source map
    const sourceMap = await this.generateSourceMap();

    // Take screenshot
    const imagePath = await this.takeScreenshot();

    const renderTime = performance.now() - startTime;

    return {
      imagePath,
      sourceMap,
      renderTime: Math.round(renderTime),
    };
  }

  private async generateSourceMap(): Promise<SourceMap> {
    if (!this.page) {
      throw new Error('Renderer not initialized');
    }

    const result = await this.page.evaluate(() => {
      const elements = document.querySelectorAll('[data-source-line]');
      const lineToY: Record<number, number> = {};

      for (const el of elements) {
        const line = Number.parseInt(el.getAttribute('data-source-line') || '0', 10);
        if (line > 0) {
          lineToY[line] = (el as HTMLElement).offsetTop;
        }
      }

      return {
        lineToY,
        totalHeight: document.body.scrollHeight,
      };
    });

    return result;
  }

  private async takeScreenshot(): Promise<string> {
    if (!this.page) {
      throw new Error('Renderer not initialized');
    }

    this.renderCount++;
    const filename = `render-${Date.now()}-${this.renderCount}.png`;
    const imagePath = join(this.outputDir, filename);

    await this.page.screenshot({
      path: imagePath,
      fullPage: true,
      type: 'png',
    });

    return imagePath;
  }
}

// Singleton instance for reuse
let rendererInstance: Renderer | null = null;

export const getRenderer = async (): Promise<Renderer> => {
  if (!rendererInstance) {
    rendererInstance = new Renderer();
    await rendererInstance.init();
  }
  return rendererInstance;
};

export const closeRenderer = async (): Promise<void> => {
  if (rendererInstance) {
    await rendererInstance.close();
    rendererInstance = null;
  }
};
