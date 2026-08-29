require 'minitest/autorun'
require 'nokogiri'

class KnowledgeComponentLibraryTest < Minitest::Test
  def test_component_library_previews_the_migrated_article_table_wrapper
    doc = Nokogiri::HTML(File.read('element.html'))
    preview = doc.at_css('.element-preview .know-table-wrap')

    assert preview, 'element.html must preview know-table-wrap'
    assert preview.at_css('table th'), 'table preview must include a heading cell'
    assert preview.at_css('table td'), 'table preview must include a data cell'
    assert_includes doc.text, 'know-table-wrap'
  end

  def test_stylesheet_keeps_article_tables_inside_the_content_width
    css = File.read('css/style.css')

    assert_includes css, '.know-table-wrap{'
    assert_match(/\.know-table-wrap\{[^}]*overflow-x:auto/, css)
    assert_match(/\.know-table-wrap table\{[^}]*min-width:/, css)
  end

  def test_article_metadata_uses_compact_wrapped_row_spacing
    css = File.read('css/style.css')

    assert_match(/\.know-article-meta\{[^}]*gap:5px 18px/, css)
  end
end
