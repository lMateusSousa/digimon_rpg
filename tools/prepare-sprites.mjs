import { mkdir, writeFile } from "node:fs/promises";
import { resolve } from "node:path";
import sharp from "sharp";

const characters = [
  { name: "heroi_vermelho", master: resolve("art/source/heroi_vermelho_master_v2.png") },
  { name: "heroi_azul", master: resolve("art/source/heroi_azul_master_v2.png") },
];
const outputDirectory = resolve("graphics");

function scaledRect(metadata, left, top, width, height) {
  const rect = {
    left: Math.round(metadata.width * left),
    top: Math.round(metadata.height * top),
    width: Math.round(metadata.width * width),
    height: Math.round(metadata.height * height),
  };
  rect.width = Math.min(rect.width, metadata.width - rect.left);
  rect.height = Math.min(rect.height, metadata.height - rect.top);
  return rect;
}

async function hardenAlpha(input) {
  const { data, info } = await sharp(input).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
  for (let offset = 3; offset < data.length; offset += 4) {
    data[offset] = data[offset] >= 112 ? 255 : 0;
  }
  return sharp(data, { raw: info }).png().toBuffer();
}

async function removeSmallComponents(input) {
  const { data, info } = await sharp(input).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
  const visited = new Uint8Array(info.width * info.height);
  const components = [];

  for (let start = 0; start < visited.length; start += 1) {
    if (visited[start] || data[start * 4 + 3] === 0) {
      continue;
    }
    const pixels = [];
    const queue = [start];
    visited[start] = 1;
    for (let index = 0; index < queue.length; index += 1) {
      const pixel = queue[index];
      pixels.push(pixel);
      const x = pixel % info.width;
      const y = Math.floor(pixel / info.width);
      for (let deltaY = -1; deltaY <= 1; deltaY += 1) {
        for (let deltaX = -1; deltaX <= 1; deltaX += 1) {
          const nextX = x + deltaX;
          const nextY = y + deltaY;
          if ((deltaX === 0 && deltaY === 0) || nextX < 0 || nextY < 0 ||
              nextX >= info.width || nextY >= info.height) {
            continue;
          }
          const next = nextY * info.width + nextX;
          if (! visited[next] && data[next * 4 + 3] !== 0) {
            visited[next] = 1;
            queue.push(next);
          }
        }
      }
    }
    components.push(pixels);
  }

  const largest = Math.max(0, ...components.map((component) => component.length));
  const minimumSize = Math.max(12, Math.floor(largest * 0.006));
  for (const component of components) {
    if (component.length < minimumSize) {
      for (const pixel of component) {
        data[pixel * 4 + 3] = 0;
      }
    }
  }

  return sharp(data, { raw: info }).png().toBuffer();
}

async function fitFrame(master, rect, size) {
  const extracted = await sharp(master).extract(rect).png().toBuffer();
  const trimmed = await sharp(extracted)
    .trim({ background: { r: 0, g: 0, b: 0, alpha: 0 }, threshold: 4 })
    .png()
    .toBuffer();
  const hardened = await hardenAlpha(trimmed);
  const resizedWithNoise = await sharp(hardened)
    .resize({
      width: size - 4,
      height: size - 4,
      fit: "inside",
      kernel: sharp.kernel.nearest,
      withoutEnlargement: false,
    })
    .png()
    .toBuffer();
  const resized = await removeSmallComponents(resizedWithNoise);
  const metadata = await sharp(resized).metadata();
  const left = Math.floor((size - metadata.width) / 2);
  const top = size - metadata.height - 1;

  return sharp({
    create: {
      width: size,
      height: size,
      channels: 4,
      background: { r: 0, g: 0, b: 0, alpha: 0 },
    },
  }).composite([{ input: resized, left, top }]).png().toBuffer();
}

async function createSheet(frames, columns, frameSize, outputPath) {
  const rows = Math.ceil(frames.length / columns);
  const composites = frames.map((input, index) => ({
    input,
    left: (index % columns) * frameSize,
    top: Math.floor(index / columns) * frameSize,
  }));
  const sheet = await sharp({
    create: {
      width: columns * frameSize,
      height: rows * frameSize,
      channels: 4,
      background: { r: 0, g: 0, b: 0, alpha: 0 },
    },
  }).composite(composites).png().toBuffer();
  const hardened = await hardenAlpha(sheet);
  const png = await sharp(hardened).png({ palette: true, colours: 16, dither: 0 }).toBuffer();
  await writeFile(outputPath, png);
  await writeIndexedBmp(png, outputPath.replace(/\.png$/i, ".bmp"));
}

async function writeIndexedBmp(png, outputPath) {
  const { data, info } = await sharp(png).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
  const colors = [{ red: 0, green: 0, blue: 0, alpha: 0 }];
  const colorIndexes = new Map();

  for (let offset = 0; offset < data.length; offset += 4) {
    const alpha = data[offset + 3];
    if (alpha === 0) {
      continue;
    }
    const key = `${data[offset]},${data[offset + 1]},${data[offset + 2]}`;
    if (! colorIndexes.has(key)) {
      if (colors.length >= 16) {
        throw new Error(`${outputPath} needs more than 15 visible colors`);
      }
      colorIndexes.set(key, colors.length);
      colors.push({ red: data[offset], green: data[offset + 1], blue: data[offset + 2], alpha: 255 });
    }
  }

  const paletteEntries = 16;
  const pixelOffset = 14 + 40 + paletteEntries * 4;
  const rowStride = (info.width + 3) & ~3;
  const imageSize = rowStride * info.height;
  const bmp = Buffer.alloc(pixelOffset + imageSize);

  bmp.write("BM", 0, "ascii");
  bmp.writeUInt32LE(bmp.length, 2);
  bmp.writeUInt32LE(pixelOffset, 10);
  bmp.writeUInt32LE(40, 14);
  bmp.writeInt32LE(info.width, 18);
  bmp.writeInt32LE(info.height, 22);
  bmp.writeUInt16LE(1, 26);
  bmp.writeUInt16LE(8, 28);
  bmp.writeUInt32LE(imageSize, 34);
  bmp.writeUInt32LE(paletteEntries, 46);
  bmp.writeUInt32LE(paletteEntries, 50);

  for (let index = 0; index < colors.length; index += 1) {
    const color = colors[index];
    const paletteOffset = 54 + index * 4;
    bmp[paletteOffset] = color.blue;
    bmp[paletteOffset + 1] = color.green;
    bmp[paletteOffset + 2] = color.red;
  }

  for (let y = 0; y < info.height; y += 1) {
    const sourceY = info.height - 1 - y;
    const rowOffset = pixelOffset + y * rowStride;
    for (let x = 0; x < info.width; x += 1) {
      const sourceOffset = (sourceY * info.width + x) * 4;
      if (data[sourceOffset + 3] === 0) {
        bmp[rowOffset + x] = 0;
      } else {
        const key = `${data[sourceOffset]},${data[sourceOffset + 1]},${data[sourceOffset + 2]}`;
        bmp[rowOffset + x] = colorIndexes.get(key);
      }
    }
  }

  await writeFile(outputPath, bmp);
}

async function prepareCharacter(character) {
  const metadata = await sharp(character.master).metadata();
  const columnLefts = [0.19, 0.39, 0.59];
  const rowTops = [0.0, 0.16, 0.32, 0.47];
  const overworldFrames = [];

  for (const top of rowTops) {
    for (const left of columnLefts) {
      overworldFrames.push(await fitFrame(
        character.master,
        scaledRect(metadata, left, top, 0.20, 0.18),
        32
      ));
    }
  }

  const battleIdle = await fitFrame(
    character.master,
    scaledRect(metadata, 0.02, 0.63, 0.48, 0.37),
    64
  );
  const battleAttack = await fitFrame(
    character.master,
    scaledRect(metadata, 0.43, 0.63, 0.57, 0.37),
    64
  );

  await createSheet(overworldFrames, 3, 32, resolve(outputDirectory, `${character.name}_overworld.png`));
  await createSheet([battleIdle, battleAttack], 2, 64, resolve(outputDirectory, `${character.name}_battle.png`));
  await createSheet([overworldFrames[0]], 1, 32, resolve(outputDirectory, `${character.name}_icon.png`));
  console.log(`Prepared ${character.name}`);
}

await mkdir(outputDirectory, { recursive: true });
for (const character of characters) {
  await prepareCharacter(character);
}

