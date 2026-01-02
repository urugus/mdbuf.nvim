#!/usr/bin/env node
/**
 * CLI tool for testing markdown rendering
 * Usage: tsx src/cli.ts input.md [output.png]
 */

import { copyFile, readFile } from 'node:fs/promises';
import { basename, resolve } from 'node:path';
import { closeRenderer, getRenderer } from './renderer.js';

async function main(): Promise<void> {
  const args = process.argv.slice(2);

  if (args.length === 0 || args[0] === '--help' || args[0] === '-h') {
    console.log(`
mdbuf-render - Render markdown to PNG

Usage:
  mdbuf-render <input.md> [output.png]
  mdbuf-render --help

Options:
  --width <px>    Viewport width (default: 800)
  --theme <name>  Theme: light or dark (default: light)

Examples:
  mdbuf-render README.md
  mdbuf-render README.md preview.png --width 1200
  mdbuf-render doc.md --theme dark
`);
    process.exit(0);
  }

  // Parse arguments
  const inputFile = args[0];
  let outputFile: string | undefined;
  let width = 800;
  let theme: 'light' | 'dark' = 'light';

  for (let i = 1; i < args.length; i++) {
    if (args[i] === '--width' && args[i + 1]) {
      width = Number.parseInt(args[i + 1], 10);
      i++;
    } else if (args[i] === '--theme' && args[i + 1]) {
      theme = args[i + 1] as 'light' | 'dark';
      i++;
    } else if (!args[i].startsWith('--') && !outputFile) {
      outputFile = args[i];
    }
  }

  // Default output filename
  if (!outputFile) {
    outputFile = basename(inputFile).replace(/\.md$/, '.png');
  }

  const inputPath = resolve(inputFile);
  const outputPath = resolve(outputFile);

  console.log(`Rendering: ${inputPath}`);
  console.log(`Output: ${outputPath}`);
  console.log(`Width: ${width}px, Theme: ${theme}`);
  console.log('');

  try {
    // Read markdown file
    const markdown = await readFile(inputPath, 'utf-8');
    console.log(`Read ${markdown.length} bytes`);

    // Initialize renderer
    console.log('Initializing Playwright...');
    const startInit = performance.now();
    const renderer = await getRenderer();
    console.log(`Initialized in ${Math.round(performance.now() - startInit)}ms`);

    // Render
    console.log('Rendering...');
    const result = await renderer.render({
      markdown,
      filePath: inputPath,
      viewport: { width },
      options: { theme },
    });

    // Copy to output location
    await copyFile(result.imagePath, outputPath);

    console.log('');
    console.log('=== Result ===');
    console.log(`Render time: ${result.renderTime}ms`);
    console.log(`Image height: ${result.sourceMap.totalHeight}px`);
    console.log(`Source lines mapped: ${Object.keys(result.sourceMap.lineToY).length}`);
    console.log(`Output: ${outputPath}`);

    // Cleanup
    await closeRenderer();
  } catch (error) {
    console.error('Error:', error);
    await closeRenderer();
    process.exit(1);
  }
}

main();
