import sharp from 'sharp';
import { unlink } from 'node:fs/promises';

const CELL = 160;

const jobs = [
  {
    input: 'pc/docs/reference/movimentos-heroi-vermelho.png',
    output: 'pc/assets/heroi_vermelho_guide_atlas.png',
    uiColor: 'red',
    frames: [
      [538, 88, 58, 58], [636, 88, 60, 58], [536, 153, 58, 55], [624, 153, 58, 55],
      [707, 153, 56, 55], [780, 153, 55, 55], [480, 462, 55, 55], [927, 462, 60, 55],
      [538, 281, 60, 58], [629, 278, 58, 56], [635, 342, 60, 56], [719, 402, 72, 58],
      [664, 524, 66, 56], [664, 590, 82, 58], [839, 706, 120, 62, 40], [517, 772, 58, 58],
    ],
  },
  {
    input: 'pc/docs/reference/movimentos-heroi-azul.png',
    output: 'pc/assets/heroi_azul_guide_atlas.png',
    uiColor: 'blue',
    frames: [
      [483, 92, 66, 86], [574, 92, 66, 86], [483, 158, 56, 60], [564, 158, 56, 60],
      [637, 158, 54, 60], [701, 158, 54, 60], [429, 547, 52, 48], [839, 547, 58, 48],
      [483, 360, 58, 62], [564, 360, 58, 62], [637, 430, 58, 62], [483, 547, 64, 58],
      [606, 657, 70, 58], [681, 720, 90, 62], [894, 850, 180, 70, 50], [440, 925, 70, 58],
    ],
  },
];

function dilate(mask, width, height, radius = 2) {
  const output = new Uint8Array(mask.length);
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      let active = false;
      for (let oy = -radius; oy <= radius && !active; oy++) {
        for (let ox = -radius; ox <= radius; ox++) {
          const nx = x + ox;
          const ny = y + oy;
          if (nx >= 0 && nx < width && ny >= 0 && ny < height && mask[ny * width + nx]) {
            active = true;
            break;
          }
        }
      }
      output[y * width + x] = active ? 1 : 0;
    }
  }
  return output;
}

function findComponents(mask, width, height) {
  const seen = new Uint8Array(mask.length);
  const result = [];
  for (let start = 0; start < mask.length; start++) {
    if (!mask[start] || seen[start]) continue;
    const stack = [start];
    const pixels = [];
    seen[start] = 1;
    let minX = width, minY = height, maxX = 0, maxY = 0;
    while (stack.length) {
      const index = stack.pop();
      pixels.push(index);
      const x = index % width;
      const y = Math.floor(index / width);
      minX = Math.min(minX, x); maxX = Math.max(maxX, x);
      minY = Math.min(minY, y); maxY = Math.max(maxY, y);
      for (let oy = -1; oy <= 1; oy++) for (let ox = -1; ox <= 1; ox++) {
        const nx = x + ox, ny = y + oy;
        if (nx < 0 || nx >= width || ny < 0 || ny >= height) continue;
        const next = ny * width + nx;
        if (mask[next] && !seen[next]) { seen[next] = 1; stack.push(next); }
      }
    }
    result.push({ pixels, minX, minY, maxX, maxY, width: maxX - minX + 1, height: maxY - minY + 1 });
  }
  return result;
}

async function extractFrame(source, [cx, cy, cropWidth, cropHeight, mergeDistance = 14]) {
  const left = Math.max(0, Math.round(cx - cropWidth / 2));
  const top = Math.max(0, Math.round(cy - cropHeight / 2));
  const { data, info } = await source
    .clone()
    .extract({ left, top, width: cropWidth, height: cropHeight })
    .ensureAlpha()
    .raw()
    .toBuffer({ resolveWithObject: true });

  const bright = new Uint8Array(info.width * info.height);
  for (let index = 0; index < bright.length; index++) {
    const offset = index * 4;
    const maximum = Math.max(data[offset], data[offset + 1], data[offset + 2]);
    const minimum = Math.min(data[offset], data[offset + 1], data[offset + 2]);
    const saturation = maximum - minimum;
    bright[index] = maximum >= 58 || (maximum >= 42 && saturation >= 24) ? 1 : 0;
  }

  for (let y = 0; y < info.height; y++) {
    let active = 0;
    for (let x = 0; x < info.width; x++) active += bright[y * info.width + x];
    const nearEdge = y < info.height * 0.20 || y > info.height * 0.80;
    if (nearEdge && active >= info.width * 0.42) {
      for (let x = 0; x < info.width; x++) bright[y * info.width + x] = 0;
    }
  }
  for (let x = 0; x < info.width; x++) {
    let active = 0;
    for (let y = 0; y < info.height; y++) active += bright[y * info.width + x];
    if (active >= info.height * 0.90) {
      for (let y = 0; y < info.height; y++) bright[y * info.width + x] = 0;
    }
  }

  const expanded = dilate(bright, info.width, info.height, 2);
  const components = findComponents(expanded, info.width, info.height)
    .filter(component => component.height >= 18 && component.width >= 14 && component.width / component.height < 4.0);
  if (!components.length) throw new Error(`Nenhum sprite encontrado perto de ${cx},${cy}`);
  const centerX = info.width / 2;
  const centerY = info.height / 2;
  components.sort((a, b) => {
    const distanceA = Math.hypot((a.minX + a.maxX) / 2 - centerX, (a.minY + a.maxY) / 2 - centerY);
    const distanceB = Math.hypot((b.minX + b.maxX) / 2 - centerX, (b.minY + b.maxY) / 2 - centerY);
    return (b.pixels.length - distanceB * 5) - (a.pixels.length - distanceA * 5);
  });
  const primary = components[0];
  const keep = new Uint8Array(expanded.length);
  for (const component of components) {
    const gapX = Math.max(0, primary.minX - component.maxX, component.minX - primary.maxX);
    const gapY = Math.max(0, primary.minY - component.maxY, component.minY - primary.maxY);
    const nearby = Math.hypot(gapX, gapY) <= mergeDistance;
    if (component === primary || nearby) {
      for (const index of component.pixels) keep[index] = 1;
    }
  }
  const mask = dilate(keep, info.width, info.height, 1);
  for (let index = 0; index < mask.length; index++) {
    const offset = index * 4;
    data[offset + 3] = mask[index] ? 255 : 0;
  }

  const sprite = sharp(data, { raw: info }).trim({ background: { r: 0, g: 0, b: 0, alpha: 0 } });
  const metadata = await sprite.metadata();
  const scale = Math.min(144 / metadata.width, 144 / metadata.height, 2.6);
  const width = Math.max(1, Math.round(metadata.width * scale));
  const height = Math.max(1, Math.round(metadata.height * scale));
  const buffer = await sprite.resize(width, height, { kernel: 'nearest' }).png().toBuffer();
  return { buffer, width, height };
}

async function cleanGuideLines(path, uiColor) {
  const { data, info } = await sharp(path).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
  const isUiPixel = (offset) => {
    const r = data[offset];
    const g = data[offset + 1];
    const b = data[offset + 2];
    if (uiColor === 'red') return r >= 24 && r <= 145 && g <= 52 && b <= 62;
    return r <= 72 && g >= 88 && b >= 115;
  };

  for (let cellRow = 0; cellRow < 4; cellRow++) {
    for (let cellColumn = 0; cellColumn < 4; cellColumn++) {
      for (let localY = 0; localY < CELL; localY++) {
        if (localY > 22 && localY < CELL - 18) continue;
        const y = cellRow * CELL + localY;
        for (let localX = 0; localX < CELL; localX++) {
          const x = cellColumn * CELL + localX;
          const offset = (y * info.width + x) * 4;
          if (data[offset + 3] > 0 && isUiPixel(offset)) data[offset + 3] = 0;
        }
      }
    }
  }
  await sharp(data, { raw: info }).png({ compressionLevel: 9 }).toFile(path + '.clean.png');
  await sharp(path + '.clean.png').toFile(path);
  await unlink(path + '.clean.png');
}

for (const job of jobs) {
  const source = sharp(job.input);
  const composites = [];
  for (let index = 0; index < job.frames.length; index++) {
    const frame = await extractFrame(source, job.frames[index]);
    const column = index % 4;
    const row = Math.floor(index / 4);
    composites.push({
      input: frame.buffer,
      left: column * CELL + Math.round((CELL - frame.width) / 2),
      top: row * CELL + CELL - frame.height - 6,
    });
  }

  await sharp({
    create: { width: CELL * 4, height: CELL * 4, channels: 4, background: { r: 0, g: 0, b: 0, alpha: 0 } },
  }).composite(composites).png({ compressionLevel: 9 }).toFile(job.output);
  await cleanGuideLines(job.output, job.uiColor);
  console.log(`${job.output}: 640x640, 16 sprites extraídos diretamente do guia`);
}
