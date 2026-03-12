#!/usr/bin/env node
// 从网站首页提取产品详情页 URL（通过 Lighthouse 的 Chrome 绕过 CF challenge）
// 用法: node scripts/discover-product-urls.mjs <homepage_url>
// 输出: 每行一个产品 URL

import { createRequire } from 'module';
import { dirname, join } from 'path';
import { execSync } from 'child_process';

// 找到全局安装的 lighthouse
const lhBin = execSync('which lighthouse', { encoding: 'utf8' }).trim();
const lhRoot = join(dirname(lhBin), '..', 'lib', 'node_modules', 'lighthouse');

const require2 = createRequire(join(lhRoot, 'package.json'));
const lighthouse = (await import(join(lhRoot, 'core', 'index.js'))).default;
const chromeLauncher = await import(require2.resolve('chrome-launcher'));

const url = process.argv[2];
if (!url) { console.error('Usage: node discover-product-urls.mjs <url>'); process.exit(1); }

const chrome = await chromeLauncher.launch({ chromeFlags: ['--headless', '--no-sandbox'] });

try {
  const result = await lighthouse(url, {
    port: chrome.port,
    onlyAudits: ['link-text'],
    output: 'json',
  });

  const anchors = result?.artifacts?.AnchorElements || [];
  const products = anchors
    .map(a => a.href || a.rawHref || '')
    .filter(h => /\/products\/[a-z0-9][a-z0-9-]*$/i.test(h))
    .filter((v, i, a) => a.indexOf(v) === i);

  products.forEach(p => console.log(p));
} finally {
  await chrome.kill();
}
