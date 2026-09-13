"""Tray crop 300x200 anchored at Box Core corner (x, y). No other crop rules (PRD section 13)."""
from PIL import Image

CROP_W, CROP_H = 300, 200


def crop_tray(image_path: str, out_jpg: str, out_thumb: str, box: tuple) -> dict:
    x, y = int(box[0]), int(box[1])
    with Image.open(image_path) as im:
        im = im.convert("RGB")
        x = max(0, min(x, max(0, im.width - CROP_W)))
        y = max(0, min(y, max(0, im.height - CROP_H)))
        cropped = im.crop((x, y, x + CROP_W, y + CROP_H))
        cropped.save(out_jpg, "JPEG", quality=92)
        thumb = cropped.copy()
        thumb.thumbnail((256, 256))
        thumb.save(out_thumb, "JPEG", quality=85)
    return {"size": [CROP_W, CROP_H], "anchor": [x, y], "jpg": out_jpg, "thumb": out_thumb}
