import { describe, expect, it } from 'vitest';
import { generateHtmlDocument, markdownToHtml } from '../markdown.js';

describe('markdownToHtml', () => {
  it('ソース行番号を付与する', () => {
    const html = markdownToHtml('# A\n\nB\n');
    expect(html).toContain('<h1 data-source-line="1">A</h1>');
    expect(html).toContain('<p data-source-line="3">B</p>');
  });

  it('コードブロックをHTMLエスケープする', () => {
    const html = markdownToHtml('```\n<>&"\n```\n');
    expect(html).toContain('&lt;&gt;&amp;&quot;');
  });

  it('mermaid のコードブロックは専用クラスを付ける', () => {
    const html = markdownToHtml('```mermaid\ngraph TD;\nA-->B\n```\n');
    expect(html).toContain('<pre class="mermaid"');
  });
});

describe('generateHtmlDocument', () => {
  it('width と theme を反映する', () => {
    const html = generateHtmlDocument('<p>hi</p>', { width: 1234, theme: 'dark' });
    expect(html).toContain('max-width: 1234px;');
    expect(html).toContain('background-color: #0d1117;');
  });

  it('customCss を style タグとして追加する', () => {
    const html = generateHtmlDocument('<p>hi</p>', {
      width: 800,
      theme: 'light',
      customCss: 'body{border:1px solid red;}',
    });
    expect(html).toContain('<style>body{border:1px solid red;}</style>');
  });
});
