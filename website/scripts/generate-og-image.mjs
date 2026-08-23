import { readFile } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import sharp from 'sharp';

const websiteRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const outputPath = resolve(websiteRoot, 'public/og-image.png');
const fontRoot = resolve(websiteRoot, 'node_modules');

const [displayFont, monoFont] = await Promise.all([
  readFile(
    resolve(
      fontRoot,
      '@fontsource/barlow-condensed/files/barlow-condensed-latin-700-normal.woff2',
    ),
  ),
  readFile(
    resolve(
      fontRoot,
      '@fontsource-variable/fira-code/files/fira-code-latin-wght-normal.woff2',
    ),
  ),
]);

const svg = `
<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="630" viewBox="0 0 1200 630">
  <defs>
    <style>
      @font-face {
        font-family: "Barlow Condensed";
        src: url("data:font/woff2;base64,${displayFont.toString('base64')}") format("woff2");
        font-weight: 700;
      }
      @font-face {
        font-family: "Fira Code";
        src: url("data:font/woff2;base64,${monoFont.toString('base64')}") format("woff2");
      }
      .display { font-family: "Barlow Condensed", sans-serif; font-weight: 700; }
      .mono { font-family: "Fira Code", monospace; }
    </style>
    <pattern id="register-grid" width="48" height="48" patternUnits="userSpaceOnUse">
      <path d="M 48 0 L 0 0 0 48" fill="none" stroke="#171717" stroke-opacity=".055"/>
    </pattern>
    <filter id="proof-lift" x="-20%" y="-20%" width="140%" height="150%">
      <feDropShadow dx="0" dy="18" stdDeviation="18" flood-color="#171717" flood-opacity=".22"/>
    </filter>
  </defs>

  <rect width="1200" height="630" fill="#f4f1e8"/>
  <rect x="506" y="76" width="694" height="554" fill="#ff62c7"/>
  <rect x="506" y="76" width="694" height="554" fill="url(#register-grid)"/>
  <path d="M0 76H1200M506 76V630" stroke="#171717"/>

  <g transform="translate(52 29)">
    <rect width="9" height="9" fill="#a91d78"/>
    <rect x="14" width="9" height="9" fill="#a91d78"/>
    <rect y="14" width="9" height="9" fill="#a91d78"/>
    <rect x="14" y="14" width="9" height="9" fill="#a91d78"/>
    <text class="display" x="38" y="24" font-size="36" fill="#171717">ccl</text>
  </g>
  <text class="mono" x="1148" y="48" text-anchor="end" font-size="15" font-weight="600" letter-spacing="1.4" fill="#171717">SOURCE-PRESERVING CCL FOR GLEAM</text>

  <text class="display" transform="translate(52 184) scale(.62 1)" font-size="91" fill="#171717">Edit the value.</text>
  <text class="display" transform="translate(52 260) scale(.62 1)" font-size="91" fill="#171717">Keep the source.</text>
  <text class="mono" x="56" y="326" font-size="17" fill="#68655d">PARSE / READ / EDIT / EMIT</text>
  <path d="M56 360H302" stroke="#b8b3a7"/>
  <text class="mono" x="56" y="398" font-size="16" fill="#171717">Comments stay.</text>
  <text class="mono" x="56" y="428" font-size="16" fill="#171717">Order stays.</text>
  <text class="mono" x="56" y="458" font-size="16" fill="#171717">Indentation stays.</text>
  <text class="mono" x="56" y="588" font-size="14" letter-spacing="1" fill="#68655d">GLEAM 1.11+  /  ERLANG + JAVASCRIPT  /  MIT</text>

  <g filter="url(#proof-lift)">
    <rect x="588" y="132" width="542" height="392" fill="#fffef9" stroke="#171717"/>
    <path d="M648 132V524M588 195H1130" stroke="#b8b3a7"/>

    <g fill="#f4f1e8" stroke="#171717">
      <circle cx="618" cy="160" r="7"/>
      <circle cx="618" cy="205" r="7"/>
      <circle cx="618" cy="250" r="7"/>
      <circle cx="618" cy="295" r="7"/>
      <circle cx="618" cy="340" r="7"/>
      <circle cx="618" cy="385" r="7"/>
      <circle cx="618" cy="430" r="7"/>
      <circle cx="618" cy="475" r="7"/>
    </g>

    <text class="mono" x="680" y="170" font-size="12" letter-spacing="1.3" fill="#68655d">DOCUMENT PROOF / SET_INT</text>
    <circle cx="1052" cy="165" r="5" fill="#a91d78"/>
    <text class="mono" x="1064" y="170" font-size="11" font-weight="700" letter-spacing="1" fill="#a91d78">REGISTERED</text>

    <text class="display" transform="translate(680 252) scale(.8 1)" font-size="49" fill="#171717">One entry changed.</text>
    <text class="mono" x="680" y="286" font-size="12" fill="#68655d">The surrounding source remains fixed.</text>
    <path d="M680 310H1094" stroke="#b8b3a7"/>

    <g class="mono" font-size="14">
      <text x="680" y="346" fill="#b8b3a7">01</text>
      <text x="718" y="346" fill="#68655d">/= the server block</text>
      <text x="680" y="379" fill="#b8b3a7">02</text>
      <text x="718" y="379" fill="#171717">server =</text>
      <text x="680" y="412" fill="#b8b3a7">03</text>
      <text x="718" y="412" fill="#171717">  host = localhost</text>
      <text x="680" y="445" fill="#b8b3a7">04</text>
      <text x="718" y="445" fill="#171717">  port =</text>
      <rect x="802" y="424" width="54" height="29" fill="#ff62c7"/>
      <text x="809" y="445" font-weight="700" fill="#171717">9090</text>
    </g>

    <g transform="translate(942 475) rotate(-2)">
      <rect width="146" height="31" fill="none" stroke="#a91d78" stroke-width="2"/>
      <text class="mono" x="73" y="20" text-anchor="middle" font-size="11" font-weight="700" letter-spacing=".8" fill="#a91d78">READ-BACK SAFE</text>
    </g>
  </g>
</svg>`;

await sharp(Buffer.from(svg)).png().toFile(outputPath);

console.log(`Generated ${outputPath}`);
