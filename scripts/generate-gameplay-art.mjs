/**
 * Reproducible vector artwork for the thirteen in-game boards.
 * No fonts or external image references: every shape remains sharp at any vp size.
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const media = path.resolve(here, '../entry/src/main/resources/base/media');

function save(name, width, height, body) {
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}" viewBox="0 0 ${width} ${height}">${body}</svg>`;
  fs.writeFileSync(path.join(media, `play_${name}.svg`), svg);
}

function gradient(top, bottom) {
  return `<defs><linearGradient id="surface" x1="0" y1="0" x2=".14" y2="1"><stop offset="0" stop-color="${top}"/><stop offset="1" stop-color="${bottom}"/></linearGradient></defs>`;
}

function tile(width, height, top, bottom, stroke, accent = '') {
  const radius = Math.min(width, height) * 0.13;
  return `${gradient(top, bottom)}
    <rect x="3" y="5" width="${width - 6}" height="${height - 8}" rx="${radius}" fill="${stroke}" opacity=".35"/>
    <rect x="3" y="2" width="${width - 6}" height="${height - 8}" rx="${radius}" fill="url(#surface)" stroke="${stroke}" stroke-width="2"/>
    <path d="M ${radius} 9 H ${width - radius} Q ${width - 8} 9 ${width - 8} ${radius}" fill="none" stroke="#fff" stroke-opacity=".48" stroke-width="3" stroke-linecap="round"/>
    <path d="M ${radius} ${height - 14} H ${width - radius}" fill="none" stroke="${stroke}" stroke-opacity=".27" stroke-width="3" stroke-linecap="round"/>
    ${accent}`;
}

// Hua Rong Dao: a complete coherent wooden-board set.
save('klotski_board', 320, 400, `${gradient('#B77F4C', '#794B2F')}
  <rect x="1" y="1" width="318" height="398" rx="21" fill="url(#surface)" stroke="#684027" stroke-width="2"/>
  <rect x="13" y="13" width="294" height="374" rx="13" fill="#4D392D" stroke="#D8A36A" stroke-width="4"/>
  <rect x="22" y="22" width="276" height="356" rx="6" fill="#665041"/>
  <path d="M112 386H208" stroke="#F5CC80" stroke-width="8" stroke-linecap="round"/>
  <path d="M121 370L160 387L199 370" fill="none" stroke="#F5CC80" stroke-width="4" stroke-linecap="round" stroke-linejoin="round"/>`);
save('klotski_target', 128, 128, tile(128, 128, '#EEAE78', '#B95346', '#8C3B37',
  '<circle cx="64" cy="62" r="47" fill="none" stroke="#FFE5B2" stroke-opacity=".55" stroke-width="2"/><path d="M24 27l12-8m68 8l-12-8M24 99l12 8m68-8l-12 8" stroke="#FFE5B2" stroke-width="3" opacity=".7"/>'));
save('klotski_vertical', 80, 160, tile(80, 160, '#8ED3D6', '#327E98', '#245F77',
  '<path d="M40 30V129" stroke="#D5F5EC" stroke-opacity=".46" stroke-width="2"/><circle cx="40" cy="44" r="8" fill="#D7F2E8" opacity=".7"/><circle cx="40" cy="116" r="8" fill="#D7F2E8" opacity=".7"/>'));
save('klotski_horizontal', 160, 80, tile(160, 80, '#8ED3D6', '#327E98', '#245F77',
  '<path d="M34 40H126" stroke="#D5F5EC" stroke-opacity=".46" stroke-width="2"/><circle cx="45" cy="40" r="8" fill="#D7F2E8" opacity=".7"/><circle cx="115" cy="40" r="8" fill="#D7F2E8" opacity=".7"/>'));
save('klotski_soldier', 80, 80, tile(80, 80, '#F7D596', '#BA814D', '#8C5736',
  '<circle cx="40" cy="37" r="21" fill="none" stroke="#FFF1D0" stroke-opacity=".63" stroke-width="2"/>'));

// Grid games: transparent surfaces preserve the existing state colors.
save('snake_food', 64, 64, `${gradient('#FF9984', '#D54853')}
  <path d="M33 18c-9-9-25-2-24 15 1 17 12 25 23 21 12 4 23-4 23-21 1-17-15-24-22-15Z" fill="url(#surface)" stroke="#A93A48" stroke-width="2"/>
  <path d="M32 21c1-9 4-12 9-15" stroke="#765237" stroke-width="4" stroke-linecap="round" fill="none"/>
  <path d="M35 14c8-11 17-8 19-7-4 9-10 12-19 7Z" fill="#5EBB74"/>
  <ellipse cx="22" cy="28" rx="5" ry="3" fill="#fff" opacity=".55"/>`);
save('tetris_gloss', 100, 100, '<rect x="2" y="2" width="96" height="96" rx="13" fill="none" stroke="#fff" stroke-opacity=".52" stroke-width="4"/><path d="M14 22Q14 13 23 13H78" fill="none" stroke="#fff" stroke-opacity=".58" stroke-width="8" stroke-linecap="round"/><path d="M18 84H82" stroke="#182E5D" stroke-opacity=".24" stroke-width="6" stroke-linecap="round"/>');
save('2048_surface', 100, 100, '<rect x="3" y="3" width="94" height="94" rx="17" fill="none" stroke="#fff" stroke-opacity=".48" stroke-width="4"/><path d="M18 18H74" stroke="#fff" stroke-opacity=".44" stroke-width="5" stroke-linecap="round"/><path d="M25 83H75" stroke="#233A5C" stroke-opacity=".2" stroke-width="4" stroke-linecap="round"/>');
save('sudoku_cell', 100, 100, '<rect x="2" y="2" width="96" height="96" rx="8" fill="none" stroke="#43678F" stroke-opacity=".38" stroke-width="3"/><path d="M10 10H33M10 10V33" stroke="#fff" stroke-opacity=".64" stroke-width="5" stroke-linecap="round"/>');
save('slide_tile', 100, 100, '<rect x="3" y="4" width="94" height="92" rx="14" fill="none" stroke="#214C76" stroke-opacity=".45" stroke-width="4"/><path d="M17 17H76" stroke="#fff" stroke-opacity=".58" stroke-width="6" stroke-linecap="round"/><path d="M23 82H77" stroke="#214C76" stroke-opacity=".24" stroke-width="5" stroke-linecap="round"/>');
save('guess_key', 100, 100, '<rect x="3" y="5" width="94" height="90" rx="20" fill="none" stroke="#1F568A" stroke-opacity=".43" stroke-width="5"/><path d="M18 18H72" stroke="#fff" stroke-opacity=".62" stroke-width="7" stroke-linecap="round"/>');

// Character and board details.
save('whack_hole', 128, 92, `${gradient('#C59161', '#764936')}
  <ellipse cx="64" cy="49" rx="60" ry="38" fill="#9C6D49"/>
  <ellipse cx="64" cy="48" rx="47" ry="26" fill="#3E2B27"/>
  <path d="M12 47c6-19 26-33 52-33s46 14 52 33" fill="none" stroke="url(#surface)" stroke-width="11" stroke-linecap="round"/>
  <path d="M21 64c11 13 30 20 43 20s32-7 43-20" fill="none" stroke="#D9A876" stroke-width="7" stroke-linecap="round"/>`);
save('mine', 100, 100, `${gradient('#5C83AA', '#1E3559')}
  <path d="M50 2L59 19L77 8L77 28L97 32L82 47L97 64L77 68L77 92L58 80L50 98L41 80L22 92L22 69L3 64L18 48L3 32L22 28L22 8L41 20Z" fill="#2E4C73" stroke="#162A49" stroke-width="3"/>
  <circle cx="50" cy="50" r="32" fill="url(#surface)" stroke="#9BB6CC" stroke-width="3"/>
  <circle cx="40" cy="40" r="8" fill="#DBEBF2" opacity=".78"/><circle cx="64" cy="62" r="5" fill="#162A49"/>`);
save('flag', 100, 100, '<path d="M32 13V88" stroke="#244872" stroke-width="7" stroke-linecap="round"/><path d="M35 16Q59 7 82 19L69 45Q54 36 35 47Z" fill="#F26762" stroke="#B73D43" stroke-width="3"/><path d="M20 88H49" stroke="#244872" stroke-width="8" stroke-linecap="round"/>');

// Memory cards use 12 original motifs instead of rendered emoji.
save('memory_back', 100, 120, `${gradient('#2A7ADB', '#194DAB')}
  <rect x="3" y="3" width="94" height="114" rx="15" fill="url(#surface)" stroke="#143C82" stroke-width="3"/>
  <rect x="11" y="11" width="78" height="98" rx="10" fill="none" stroke="#B4DAFF" stroke-opacity=".72" stroke-width="3"/>
  <path d="M50 27L56 48L77 53L56 59L50 82L44 59L23 53L44 48Z" fill="#E5F5FF" opacity=".92"/>
  <circle cx="50" cy="53" r="8" fill="#FFD182"/>`);
const motifs = [
  ['sun', '#FFB65E', '<circle cx="50" cy="50" r="20" fill="#FFCB65"/><path d="M50 12V23M50 77v11M12 50h11M77 50h11M23 23l8 8M69 69l8 8M77 23l-8 8M31 69l-8 8" stroke="#E88B39" stroke-width="5" stroke-linecap="round"/>'],
  ['moon', '#7C78D5', '<path d="M68 18a31 31 0 1 0 14 53A33 33 0 0 1 68 18Z" fill="#E7E4FF"/>'],
  ['star', '#F0A34B', '<path d="M50 15L60 38L85 40L66 57L72 82L50 68L28 82L34 57L15 40L40 38Z" fill="#FFE29C"/>'],
  ['heart', '#EC6D7B', '<path d="M50 80L20 52C1 32 21 12 40 27L50 37L60 27C79 12 99 32 80 52Z" fill="#FFD0D6"/>'],
  ['clover', '#55BD8C', '<circle cx="38" cy="38" r="15" fill="#B9F2D1"/><circle cx="62" cy="38" r="15" fill="#B9F2D1"/><circle cx="38" cy="62" r="15" fill="#B9F2D1"/><circle cx="62" cy="62" r="15" fill="#B9F2D1"/>'],
  ['bolt', '#5DAFDC', '<path d="M56 14L26 54H46L40 87L75 42H54Z" fill="#DAF6FF"/>'],
  ['crown', '#D9A655', '<path d="M20 35L34 48L50 22L66 48L80 35L74 76H26Z" fill="#FFF0BC"/>'],
  ['diamond', '#56C2D1', '<path d="M50 13L83 50L50 87L17 50Z" fill="#D8FAFF"/><path d="M50 13L50 87M17 50H83" stroke="#7BD8E8" stroke-width="3"/>'],
  ['spiral', '#A58BDC', '<path d="M65 44c-5-11-25-8-25 6 0 13 23 17 34 4 15-19-4-41-26-40-28 2-40 35-23 57 17 22 53 17 63-8" fill="none" stroke="#E7DEFF" stroke-width="9" stroke-linecap="round"/>'],
  ['leaf', '#67BD70', '<path d="M21 75C19 40 43 19 82 18C84 57 62 83 28 80Z" fill="#D8F4AF"/><path d="M25 76L74 28" stroke="#6CAD56" stroke-width="5" stroke-linecap="round"/>'],
  ['shell', '#D48D81', '<path d="M18 69C17 40 31 20 50 20s33 20 32 49Z" fill="#FFE0D1"/><path d="M50 22V68M33 29L40 68M67 29L60 68" stroke="#D89183" stroke-width="4"/>'],
  ['flame', '#EE8C52', '<path d="M51 13C60 32 35 39 38 56C27 48 27 38 29 32C14 50 25 84 50 86C77 84 87 56 69 40C68 55 56 56 60 42C63 33 58 22 51 13Z" fill="#FFE2A5"/>']
];
for (const motif of motifs) {
  const [name, color, shape] = motif;
  save(`memory_${name}`, 100, 100, `<circle cx="50" cy="50" r="46" fill="${color}" opacity=".24"/>${shape}`);
}

// Arcade surfaces.
save('jump_frog', 100, 100, `${gradient('#B2E76D', '#53A750')}
  <ellipse cx="51" cy="57" rx="35" ry="29" fill="url(#surface)" stroke="#3B8D4A" stroke-width="3"/>
  <circle cx="34" cy="28" r="15" fill="#78CB59"/><circle cx="68" cy="28" r="15" fill="#78CB59"/>
  <circle cx="34" cy="28" r="8" fill="#fff"/><circle cx="68" cy="28" r="8" fill="#fff"/>
  <circle cx="38" cy="28" r="4" fill="#263A3D"/><circle cx="72" cy="28" r="4" fill="#263A3D"/>
  <ellipse cx="50" cy="67" rx="24" ry="12" fill="#E9F4C0"/>
  <path d="M38 68Q50 78 63 67" fill="none" stroke="#4B8C4A" stroke-width="3" stroke-linecap="round"/>
  <ellipse cx="17" cy="80" rx="14" ry="7" fill="#64B74F"/><ellipse cx="84" cy="80" rx="14" ry="7" fill="#64B74F"/>`);
save('jump_platform', 160, 52, `${gradient('#A5E496', '#4CA26E')}
  <rect x="2" y="3" width="156" height="45" rx="19" fill="#2E795F"/>
  <rect x="2" y="2" width="156" height="31" rx="16" fill="url(#surface)" stroke="#397E61" stroke-width="2"/>
  <path d="M22 12H124" stroke="#E4F9C8" stroke-opacity=".7" stroke-width="4" stroke-linecap="round"/>`);
save('brick_gloss', 160, 64, '<rect x="3" y="3" width="154" height="58" rx="10" fill="none" stroke="#fff" stroke-opacity=".56" stroke-width="4"/><path d="M18 16H132" stroke="#fff" stroke-opacity=".64" stroke-width="7" stroke-linecap="round"/><path d="M18 50H139" stroke="#692E57" stroke-opacity=".2" stroke-width="5" stroke-linecap="round"/>');
save('brick_paddle', 160, 32, `${gradient('#70C9EB', '#246FC0')}
  <rect x="2" y="3" width="156" height="27" rx="13" fill="url(#surface)" stroke="#1B5294" stroke-width="3"/>
  <path d="M23 10H133" stroke="#E1FAFF" stroke-opacity=".8" stroke-width="4" stroke-linecap="round"/>`);
save('brick_ball', 64, 64, `${gradient('#FFF2AE', '#F4A53F')}
  <circle cx="32" cy="32" r="28" fill="url(#surface)" stroke="#D99031" stroke-width="3"/>
  <ellipse cx="24" cy="22" rx="10" ry="6" fill="#fff" opacity=".82"/>`);

const gems = [
  ['coral', '#FF8D83', '#D65068', 'M50 5L91 30L82 78L50 96L18 78L9 30Z'],
  ['amber', '#FFE08A', '#F59B37', 'M50 3L94 50L50 97L6 50Z'],
  ['mint', '#A6EBC2', '#34A984', 'M25 10H75L95 42L75 90H25L5 42Z'],
  ['blue', '#A8DEFF', '#238BD5', 'M50 5L91 27L91 73L50 95L9 73L9 27Z'],
  ['pink', '#FFC0D9', '#E65D9F', 'M50 9C68-1 91 13 91 35C91 59 67 78 50 93C33 78 9 59 9 35C9 13 32-1 50 9Z'],
  ['violet', '#D4C2FF', '#7860D3', 'M50 4L86 21L96 60L70 93H30L4 60L14 21Z']
];
for (let i = 0; i < gems.length; i++) {
  const [name, top, bottom, outline] = gems[i];
  save(`gem_${i}`, 100, 100, `${gradient(top, bottom)}
    <path d="${outline}" fill="url(#surface)" stroke="${bottom}" stroke-width="3"/>
    <path d="M50 10L68 35L50 72L31 35Z" fill="#fff" opacity=".28"/>
    <path d="M14 34L50 10L31 35L50 72Z" fill="#fff" opacity=".3"/>
    <path d="M68 35L87 34L50 72Z" fill="${bottom}" opacity=".36"/>
    <path d="M50 72L77 80L50 94L22 80Z" fill="${bottom}" opacity=".33"/>`);
}
