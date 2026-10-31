import { mkdir } from "node:fs/promises";
import { resolve } from "node:path";
import sharp from "sharp";

const characters = [
  { name: "heroi_vermelho", master: resolve("art/source/heroi_vermelho_master.png") },
  { name: "heroi_azul", master: resolve("art/source/heroi_azul_master.png") },
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

async function fitFrame(master, rect, size) {
  const extracted = await sharp(master).extract(rect).png().toBuffer();
  const trimmed = await sharp(extracted)
    .trim({ background: { r: 0, g: 0, b: 0, alpha: 0 }, threshold: 4 })
    .png()
    .toBuffer();
  const hardened = await hardenAlpha(trimmed);
  const resized = await sharp(hardened)
    .resize({
      width: size - 4,
      height: size - 4,
      fit: "inside",
      kernel: sharp.kernel.nearest,
      withoutEnlargement: false,
    })
    .png()
    .toBuffer();
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
  await sharp(hardened).png({ palette: true, colours: 16, dither: 0 }).toFile(outputPath);
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

