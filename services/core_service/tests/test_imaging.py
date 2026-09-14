from PIL import Image
from app.imaging import crop_tray, resolve_box


def test_crop_produces_300x200_and_thumb(tmp_path):
    src = tmp_path / "raw.jpg"
    Image.new("RGB", (800, 600), (200, 30, 30)).save(src)
    out_jpg = tmp_path / "out.jpg"
    out_thumb = tmp_path / "thumb.jpg"
    r = crop_tray(str(src), str(out_jpg), str(out_thumb), (10, 20))
    assert r["size"] == [300, 200]
    assert out_jpg.exists() and out_thumb.exists()
    assert Image.open(out_jpg).size == (300, 200)


def test_resolve_box_fractions_and_clamp():
    assert resolve_box([0, 0], 800, 600) == [0, 0]
    assert resolve_box([1.0, 1.0], 800, 600) == [500, 400]
    assert resolve_box([0.5, 0.5], 800, 600) == [250, 200]
    assert resolve_box([9, -3], 800, 600) == [500, 0]
    assert resolve_box(None, 800, 600) == [0, 0]
