"""Tests for ../fix_docx_tables.py.

Run from the request folder with:
    uv run --with pytest pytest tests/test_fix_docx_tables.py
"""
import re
import sys
import zipfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import fix_docx_tables  # noqa: E402

LEAD_IN = '<w:p><w:pPr><w:pStyle w:val="BodyText" /></w:pPr><w:r><w:t>Lead-in:</w:t></w:r></w:p>'
EARLIER = '<w:p><w:r><w:t>An earlier paragraph.</w:t></w:r></w:p>'


def cell(text, style=True):
    properties = '<w:pPr><w:pStyle w:val="Compact" /></w:pPr>' if style else ""
    return f"<w:tc><w:tcPr /><w:p>{properties}<w:r><w:t>{text}</w:t></w:r></w:p></w:tc>"


def row(text, header=False, style=True):
    properties = "<w:trPr><w:tblHeader /></w:trPr>" if header else ""
    return f"<w:tr>{properties}{cell(text, style)}</w:tr>"


def make_docx(path, body):
    document = f'<?xml version="1.0"?><w:document xmlns:w="x"><w:body>{body}</w:body></w:document>'
    with zipfile.ZipFile(path, "w") as archive:
        archive.writestr("word/document.xml", document)
        archive.writestr("word/styles.xml", "<styles/>")


def fixed_document(tmp_path, body):
    path = tmp_path / "file.docx"
    make_docx(path, body)
    fix_docx_tables.main(str(path))
    with zipfile.ZipFile(path) as archive:
        return archive.read("word/document.xml").decode("utf8"), archive.namelist()


def rows_of(document):
    return re.findall(r"<w:tr[ >].*?</w:tr>", document, flags=re.S)


def test_every_row_is_set_not_to_split(tmp_path):
    body = f"<w:tbl>{row('Head', header=True)}{row('One')}{row('Two')}</w:tbl>"
    document, _ = fixed_document(tmp_path, body)
    assert all("<w:cantSplit/>" in r for r in rows_of(document))
    assert document.count("<w:cantSplit/>") == 3


def test_header_row_keeps_its_existing_settings(tmp_path):
    body = f"<w:tbl>{row('Head', header=True)}{row('One')}</w:tbl>"
    document, _ = fixed_document(tmp_path, body)
    assert "<w:trPr><w:cantSplit/><w:tblHeader /></w:trPr>" in rows_of(document)[0]


def test_all_rows_but_the_last_stay_with_the_next_row(tmp_path):
    body = f"<w:tbl>{row('Head', header=True)}{row('One')}{row('Two')}</w:tbl>"
    document, _ = fixed_document(tmp_path, body)
    rows = rows_of(document)
    assert "<w:keepNext/>" in rows[0]
    assert "<w:keepNext/>" in rows[1]
    assert "<w:keepNext/>" not in rows[2]


def test_keep_next_comes_after_the_paragraph_style(tmp_path):
    # Word ignores keepNext when it is written before the style.
    body = f"<w:tbl>{row('One')}{row('Two')}</w:tbl>"
    document, _ = fixed_document(tmp_path, body)
    assert '<w:pPr><w:pStyle w:val="Compact" /><w:keepNext/></w:pPr>' in rows_of(document)[0]


def test_a_cell_paragraph_with_no_settings_still_stays_with_the_next_row(tmp_path):
    body = f"<w:tbl>{row('One', style=False)}{row('Two', style=False)}</w:tbl>"
    document, _ = fixed_document(tmp_path, body)
    assert "<w:p><w:pPr><w:keepNext/></w:pPr>" in rows_of(document)[0]


def test_a_paragraph_with_settings_but_no_style_still_stays_with_the_next_row(tmp_path):
    plain = '<w:tr><w:tc><w:p><w:pPr><w:jc w:val="left" /></w:pPr><w:r><w:t>One</w:t></w:r></w:p></w:tc></w:tr>'
    document, _ = fixed_document(tmp_path, f"<w:tbl>{plain}{row('Two')}</w:tbl>")
    assert '<w:pPr><w:keepNext/><w:jc w:val="left" /></w:pPr>' in rows_of(document)[0]


def test_the_paragraph_before_a_table_stays_with_it(tmp_path):
    body = f"{EARLIER}{LEAD_IN}\n    <w:tbl>{row('One')}</w:tbl>"
    document, _ = fixed_document(tmp_path, body)
    assert '<w:pStyle w:val="BodyText" /><w:keepNext/>' in document
    assert EARLIER in document  # paragraphs further up are left alone


def test_running_it_twice_changes_nothing_more(tmp_path):
    path = tmp_path / "file.docx"
    make_docx(path, f"{LEAD_IN}<w:tbl>{row('Head', header=True)}{row('One')}{row('Two')}</w:tbl>")
    fix_docx_tables.main(str(path))
    with zipfile.ZipFile(path) as archive:
        once = archive.read("word/document.xml")
    fix_docx_tables.main(str(path))
    with zipfile.ZipFile(path) as archive:
        twice = archive.read("word/document.xml")
    assert once == twice


def test_other_files_in_the_document_are_kept_and_no_temporary_file_is_left(tmp_path):
    body = f"<w:tbl>{row('One')}</w:tbl>"
    _, names = fixed_document(tmp_path, body)
    assert sorted(names) == ["word/document.xml", "word/styles.xml"]
    assert [p.name for p in tmp_path.iterdir()] == ["file.docx"]


def test_a_document_with_no_table_is_left_as_it_was(tmp_path):
    document, _ = fixed_document(tmp_path, EARLIER)
    assert "keepNext" not in document and "cantSplit" not in document
