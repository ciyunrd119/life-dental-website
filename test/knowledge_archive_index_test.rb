require 'minitest/autorun'
require 'nokogiri'
require_relative '../scripts/knowledge_archive/index_builder'

class KnowledgeArchiveIndexTest < Minitest::Test
  def test_cards_are_unique_and_sorted_newest_first
    builder = KnowledgeArchive::IndexBuilder.new(path: 'knowledge.html')
    entries = [
      fixture_entry('knowledge/know_20180731.html', Date.new(2018, 7, 31)),
      fixture_entry('knowledge/know_20260506.html', Date.new(2026, 5, 6))
    ]
    html = builder.rebuild(entries: entries + [entries.first])
    doc = Nokogiri::HTML(html)
    hrefs = doc.css('.knowledge-card').map { |node| node['href'] }
    migrated = hrefs.grep(/know_/)
    assert_equal ['knowledge/know_20260506.html', 'knowledge/know_20180731.html'], migrated
    assert_equal migrated.uniq, migrated
  end

  private

  def fixture_entry(path, date)
    {
      article: KnowledgeArchive::Article.new(
        source_path: File.basename(path),
        title: '固定測試標題',
        date: date,
        local_path: path,
        categories: ['general']
      ),
      extracted: KnowledgeArchive::ExtractedArticle.new(
        title: '固定測試標題',
        summary: '固定測試摘要',
        body_html: '<p>固定測試摘要</p>',
        images: []
      ),
      cover_path: 'knowledge/img/default.png'
    }
  end
end
