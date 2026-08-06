from pathlib import Path
import sys

base = Path(__file__).resolve().parents[1]
if str(base) not in sys.path:
    sys.path.insert(0, str(base))

from app.image_utils import _normalize_image_url
from app.foursquare_sync import _safe_place_name, _build_description


def test_normalize_image_url_dedups_query_and_fragment():
    url1 = _normalize_image_url(
        'https://fastly.4sqi.net/img/general/800x800/ABC.jpg?width=400'
    )
    url2 = _normalize_image_url(
        'https://fastly.4sqi.net/img/general/800x800/ABC.jpg#fragment'
    )
    assert url1 == url2
    assert url1 == 'https://fastly.4sqi.net/img/general/800x800/ABC.jpg'


def test_normalize_image_url_lowercases_scheme_and_host():
    url = _normalize_image_url('HTTPS://EXAMPLE.COM/Photo.JPG?x=1')
    assert url == 'https://example.com/Photo.JPG'


def test_safe_place_name_rejects_generic():
    assert _safe_place_name('Hotel') is False
    assert _safe_place_name('Restaurant') is False
    assert _safe_place_name('Mefou National Park') is True
    assert _safe_place_name('') is False


def test_build_description_contains_name():
    desc = _build_description('Mefou National Park', 'nature', 'Park', 'Yaoundé', 2)
    assert isinstance(desc, str)
    assert 'Mefou' in desc
    assert len(desc) > 20
