require 'minitest/autorun'
require_relative '../scripts/knowledge_archive/catalog'

class KnowledgeArchiveCatalogTest < Minitest::Test
  FIXTURE = File.read('test/fixtures/knowledge_archive/list.html')
  OVERRIDES = {
    'know_20250212.html' => { 'source_path' => 'know_20250212.html' },
    'know_20231115.html' => {
      'replacement' => 'knowledge/20231115-isq-implant-stability.html'
    },
    '台中冷光美白.html' => {
      'source_path' => '台中冷光美白.html',
      'local_path' => 'knowledge/know_cold-light-whitening.html',
      'allow_title_mismatch' => true
    }
  }

  def test_extracts_title_date_and_all_candidate_links
    article = KnowledgeArchive::Catalog.parse(FIXTURE, overrides: OVERRIDES)[1]
    assert_equal '2025-02-12', article.date.iso8601
    assert_equal ['know_20250212.html', 'know_20250206.html'], article.candidates
    assert_equal 'knowledge/know_20250212.html', article.local_path
  end

  def test_marks_existing_new_version_as_replacement
    article = KnowledgeArchive::Catalog.parse(FIXTURE, overrides: OVERRIDES)[2]
    assert_equal 'knowledge/20231115-isq-implant-stability.html', article.replacement
  end

  def test_honors_explicit_local_path
    article = KnowledgeArchive::Catalog.parse(FIXTURE, overrides: OVERRIDES)[3]
    assert_equal 'knowledge/know_cold-light-whitening.html', article.local_path
    assert article.allow_title_mismatch
  end
end
