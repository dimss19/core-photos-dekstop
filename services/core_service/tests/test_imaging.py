from PIL import Image
from app.imaging import crop_tray


def test_crop_produces_300x200_and_thumb(tmp_path):
    src = tmp_path / "raw.jpg"
    Image.new("RGB", (800, 600), (200, 30, 30)).save(src)
    out_jpg = tmp_path / "out.jpg"
    out_thumb = tmp_path / "thumb.jpg"
    r = crop_tray(str(src), str(out_jpg), str(out_thumb), (10, 20))
    assert r["size"] == [300, 200]
    assert out_jpg.exists() and out_thumb.exists()
    assert Image.open(out_jpg).size == (300, 200)
