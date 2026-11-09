"""Keep tables whole in a Word file rendered by Quarto.

Usage: python3 fix_docx_tables.py path/to/file.docx

Quarto's Word output lets a table row split across two pages. This sets
every table row not to split, and every row except the last to stay on
the same page as the next row, so a short table is never cut in two.
It also keeps the paragraph before each table on the same page as the
table. Column widths come from the dashes under each table heading in
the .qmd file.
The file is changed in place.
"""
import re
import shutil
import sys
import zipfile


def keep_table_together(table_xml):
    rows = re.findall(r"<w:tr[ >].*?</w:tr>", table_xml, flags=re.S)
    for index, row in enumerate(rows):
        fixed = row
        if "<w:trPr>" in fixed:
            if "<w:cantSplit" not in fixed:
                fixed = fixed.replace("<w:trPr>", "<w:trPr><w:cantSplit/>", 1)
        else:
            fixed = re.sub(r"(<w:tr[^>]*>)", r"\1<w:trPr><w:cantSplit/></w:trPr>", fixed, count=1)
        if index < len(rows) - 1:
            fixed = re.sub(r"<w:p>.*?</w:p>", lambda m: add_keep_next(m.group(0)), fixed, flags=re.S)
        table_xml = table_xml.replace(row, fixed, 1)
    return table_xml


def add_keep_next(paragraph):
    """Mark one paragraph to stay on the same page as what follows it.

    Word reads the settings inside w:pPr in a fixed order: the paragraph
    style comes first and keepNext after it. Out of order, it is ignored.
    """
    if "<w:keepNext" in paragraph:
        return paragraph
    style = re.search(r"<w:pStyle [^>]*/>", paragraph)
    if style:
        return paragraph.replace(style.group(0), style.group(0) + "<w:keepNext/>", 1)
    if "<w:pPr>" in paragraph:
        return paragraph.replace("<w:pPr>", "<w:pPr><w:keepNext/>", 1)
    return paragraph.replace("<w:p>", "<w:p><w:pPr><w:keepNext/></w:pPr>", 1)


def main(path):
    temporary = path + ".tmp"
    with zipfile.ZipFile(path) as source, zipfile.ZipFile(temporary, "w", zipfile.ZIP_DEFLATED) as target:
        for item in source.infolist():
            data = source.read(item.filename)
            if item.filename == "word/document.xml":
                text = data.decode("utf8")
                text, count = re.subn(r"<w:tbl>.*?</w:tbl>", lambda m: keep_table_together(m.group(0)), text, flags=re.S)
                # The paragraph just before a table stays on its page.
                text = re.sub(r"(<w:p>(?:(?!<w:p>|<w:tbl>).)*?</w:p>)(?=\s*<w:tbl>)", lambda m: add_keep_next(m.group(0)), text, flags=re.S)
                print("tables fixed:", count)
                data = text.encode("utf8")
            target.writestr(item, data)
    shutil.move(temporary, path)


if __name__ == "__main__":
    main(sys.argv[1])
