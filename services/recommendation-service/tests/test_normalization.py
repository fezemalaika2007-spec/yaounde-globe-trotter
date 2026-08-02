import importlib.util
import sys
from pathlib import Path


def _load_module():
    base = Path(__file__).resolve().parents[1]
    # Ensure `app` package (and its image_utils dependency) is importable.
    if str(base) not in sys.path:
        sys.path.insert(0, str(base))
    mod_path = base / 'app' / 'overpass_sync.py'
    spec = importlib.util.spec_from_file_location('overpass_sync', str(mod_path))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def test_is_disallowed_pub():
    mod = _load_module()
    tags = {'amenity': 'pub'}
    assert mod._is_disallowed_destination(tags) is True


def test_is_disallowed_keyword_in_name():
    mod = _load_module()
    tags = {'name': 'Alcohol Shop'}
    assert mod._is_disallowed_destination(tags) is True


def test_allowed_museum():
    mod = _load_module()
    tags = {'amenity': 'museum'}
    assert mod._is_disallowed_destination(tags) is False


def test_build_long_description_contains_name_and_category():
    mod = _load_module()
    tags = {'name': 'Mefou Park', 'tourism': 'park'}
    desc = mod._build_long_description(
        'Mefou Park', tags, 'nature', '', '', '', '', 'Yaoundé')
    assert isinstance(desc, str)
    assert 'Mefou' in desc
    assert len(desc) > 20


def test_junk_description_is_rejected():
    mod = _load_module()
    assert mod._has_junk_description('') is True
    assert mod._has_junk_description('#GGK Diocèse') is True
    assert mod._has_junk_description('no description') is True
    assert mod._has_junk_description('ok') is True
    assert mod._has_junk_description(
        'A proper visitor description of the place.') is False


def test_junk_name_is_rejected():
    mod = _load_module()
    assert mod._has_junk_name('Bench 1') is True
    assert mod._has_junk_name('Bus stop') is True
    assert mod._has_junk_name('Parking') is True
    assert mod._has_junk_name('Mefou National Park') is False


def test_normalize_image_url_dedups_query_and_fragment():
    mod = _load_module()
    url1 = mod._normalize_image_url(
        'https://upload.wikimedia.org/wikipedia/commons/9/9f/YaoundeNationalMuseum.png?width=400'
    )
    url2 = mod._normalize_image_url(
        'https://upload.wikimedia.org/wikipedia/commons/9/9f/YaoundeNationalMuseum.png#fragment'
    )
    assert url1 == url2
    assert url1 == (
        'https://upload.wikimedia.org/wikipedia/commons/9/9f/'
        'YaoundeNationalMuseum.png'
    )


def test_normalize_image_url_lowercases_scheme_and_host():
    mod = _load_module()
    url = mod._normalize_image_url('HTTPS://EXAMPLE.COM/Photo.JPG?x=1')
    assert url == 'https://example.com/Photo.JPG'


def test_normalize_element_skips_unnamed_and_junk():
    mod = _load_module()
    element = {'type': 'node', 'id': 1, 'tags': {}}
    assert mod._normalize_osm_element(element) is None
    element2 = {
        'type': 'node',
        'id': 2,
        'tags': {'name': 'Bench 1', 'leisure': 'park'},
    }
    assert mod._normalize_osm_element(element2) is None


def test_normalize_element_produces_long_description_and_unique_images():
    mod = _load_module()
    element = {
        'type': 'node',
        'id': 123,
        'lat': 3.8667,
        'lon': 11.5167,
        'tags': {
            'name': 'Mefou National Park',
            'tourism': 'attraction',
            'addr:city': 'Yaoundé',
            'description': 'A long visitor description of Mefou National Park.',
        },
    }
    dest = mod._normalize_osm_element(element)
    assert dest is not None
    assert dest['name'] == 'Mefou National Park'
    assert 'long_description' in dest
    assert len(dest['long_description']) > 30
    assert dest['category'] == 'culture'
    # Images list should be non-empty and internally unique.
    assert len(dest['images']) >= 1
    assert len(dest['images']) == len(set(dest['images']))
