import { type Tokens, marked } from 'marked';

// Track current line number for source mapping
let currentLine = 1;

/**
 * Reset line counter before parsing
 */
const resetLineCounter = (): void => {
  currentLine = 1;
};

/**
 * Get line number from token if available, otherwise use tracked line
 */
const getLineNumber = (token: { raw?: string }): number => {
  const line = currentLine;
  if (token.raw) {
    currentLine += token.raw.split('\n').length - 1;
  }
  return line;
};

// Configure marked with custom renderer
marked.use({
  renderer: {
    paragraph({ tokens, raw }: Tokens.Paragraph & { raw?: string }): string {
      const text = this.parser.parseInline(tokens);
      const line = getLineNumber({ raw });
      return `<p data-source-line="${line}">${text}</p>\n`;
    },

    heading({ tokens, depth, raw }: Tokens.Heading & { raw?: string }): string {
      const text = this.parser.parseInline(tokens);
      const line = getLineNumber({ raw });
      return `<h${depth} data-source-line="${line}">${text}</h${depth}>\n`;
    },

    list(token: Tokens.List): string {
      const line = getLineNumber({ raw: token.raw });
      const tag = token.ordered ? 'ol' : 'ul';
      const body = token.items
        .map((item) => {
          const itemBody = this.parser.parse(item.tokens);
          return `<li>${itemBody}</li>`;
        })
        .join('');
      return `<${tag} data-source-line="${line}">${body}</${tag}>\n`;
    },

    blockquote({ tokens, raw }: Tokens.Blockquote & { raw?: string }): string {
      const line = getLineNumber({ raw });
      const body = this.parser.parse(tokens);
      return `<blockquote data-source-line="${line}">${body}</blockquote>\n`;
    },

    code({ text, lang, raw }: Tokens.Code & { raw?: string }): string {
      const line = getLineNumber({ raw });
      const language = lang || '';

      // Mermaid diagram support
      if (language === 'mermaid') {
        return `<pre class="mermaid" data-source-line="${line}">${text}</pre>\n`;
      }

      const escaped = text
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;');
      return `<pre data-source-line="${line}"><code class="language-${language}">${escaped}</code></pre>\n`;
    },

    hr(token: Tokens.Hr): string {
      const line = getLineNumber({ raw: token.raw });
      return `<hr data-source-line="${line}" />\n`;
    },

    table(token: Tokens.Table): string {
      const line = getLineNumber({ raw: token.raw });
      let header = '<thead><tr>';
      for (let i = 0; i < token.header.length; i++) {
        const cell = token.header[i];
        const align = token.align[i];
        const style = align ? ` style="text-align:${align}"` : '';
        header += `<th${style}>${this.parser.parseInline(cell.tokens)}</th>`;
      }
      header += '</tr></thead>';

      let body = '<tbody>';
      for (const row of token.rows) {
        body += '<tr>';
        for (let i = 0; i < row.length; i++) {
          const cell = row[i];
          const align = token.align[i];
          const style = align ? ` style="text-align:${align}"` : '';
          body += `<td${style}>${this.parser.parseInline(cell.tokens)}</td>`;
        }
        body += '</tr>';
      }
      body += '</tbody>';

      return `<table data-source-line="${line}">${header}${body}</table>\n`;
    },
  },
  gfm: true,
  breaks: false,
});

/**
 * Convert markdown to HTML with source line annotations
 */
export const markdownToHtml = (markdown: string): string => {
  resetLineCounter();
  return marked.parse(markdown) as string;
};

/**
 * Generate full HTML document with styling
 */
export const generateHtmlDocument = (
  body: string,
  options: { width: number; theme: 'light' | 'dark'; customCss?: string; enableMermaid?: boolean }
): string => {
  const { width, theme, customCss, enableMermaid = true } = options;

  const baseStyles = `
    * {
      box-sizing: border-box;
    }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Helvetica, Arial, sans-serif;
      font-size: 16px;
      line-height: 1.6;
      width: ${width}px;
      margin: 0;
      padding: 24px;
      color: ${theme === 'dark' ? '#c9d1d9' : '#24292f'};
      background-color: ${theme === 'dark' ? '#0d1117' : '#ffffff'};
    }
    h1, h2, h3, h4, h5, h6 {
      margin-top: 24px;
      margin-bottom: 16px;
      font-weight: 600;
      line-height: 1.25;
    }
    h1 { font-size: 2em; border-bottom: 1px solid ${theme === 'dark' ? '#21262d' : '#d0d7de'}; padding-bottom: 0.3em; }
    h2 { font-size: 1.5em; border-bottom: 1px solid ${theme === 'dark' ? '#21262d' : '#d0d7de'}; padding-bottom: 0.3em; }
    h3 { font-size: 1.25em; }
    h4 { font-size: 1em; }
    p { margin-top: 0; margin-bottom: 16px; }
    a { color: ${theme === 'dark' ? '#58a6ff' : '#0969da'}; text-decoration: none; }
    a:hover { text-decoration: underline; }
    code {
      font-family: 'SFMono-Regular', Consolas, 'Liberation Mono', Menlo, monospace;
      font-size: 85%;
      padding: 0.2em 0.4em;
      background-color: ${theme === 'dark' ? '#161b22' : '#f6f8fa'};
      border-radius: 6px;
    }
    pre {
      padding: 16px;
      overflow: auto;
      font-size: 85%;
      line-height: 1.45;
      background-color: ${theme === 'dark' ? '#161b22' : '#f6f8fa'};
      border-radius: 6px;
    }
    pre code {
      padding: 0;
      background-color: transparent;
    }
    blockquote {
      margin: 0 0 16px 0;
      padding: 0 1em;
      color: ${theme === 'dark' ? '#8b949e' : '#57606a'};
      border-left: 0.25em solid ${theme === 'dark' ? '#3b434b' : '#d0d7de'};
    }
    table {
      border-collapse: collapse;
      width: 100%;
      margin-bottom: 16px;
    }
    th, td {
      padding: 6px 13px;
      border: 1px solid ${theme === 'dark' ? '#3b434b' : '#d0d7de'};
    }
    th {
      font-weight: 600;
      background-color: ${theme === 'dark' ? '#161b22' : '#f6f8fa'};
    }
    tr:nth-child(2n) {
      background-color: ${theme === 'dark' ? '#161b22' : '#f6f8fa'};
    }
    ul, ol {
      padding-left: 2em;
      margin-top: 0;
      margin-bottom: 16px;
    }
    li { margin-top: 0.25em; }
    hr {
      height: 0.25em;
      padding: 0;
      margin: 24px 0;
      background-color: ${theme === 'dark' ? '#21262d' : '#d0d7de'};
      border: 0;
    }
    img {
      max-width: 100%;
      height: auto;
    }
  `;

  const mermaidScript = enableMermaid
    ? `
    <script src="https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.min.js"></script>
    <script>
      mermaid.initialize({
        startOnLoad: true,
        theme: '${theme === 'dark' ? 'dark' : 'default'}',
        securityLevel: 'loose',
      });
    </script>
  `
    : '';

  return `<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <style>${baseStyles}</style>
  ${customCss ? `<style>${customCss}</style>` : ''}
</head>
<body>
${body}
${mermaidScript}
</body>
</html>`;
};
