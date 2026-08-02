import importlib.util
from pathlib import Path


def _load_module():
    base = Path(__file__).resolve().parents[1]
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
