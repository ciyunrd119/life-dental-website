require 'minitest/autorun'
require 'nokogiri'
require 'date'

class KnowledgeContentIntegrityTest < Minitest::Test
  def test_every_card_target_and_local_image_exists
    doc = Nokogiri::HTML(File.read('knowledge.html'))
    doc.css('a.knowledge-card').each do |card|
      assert File.file?(card['href']), "missing article: #{card['href']}"
      image = card.at_css('img')['src']
      assert File.file?(image), "missing card image: #{image}"
    end
  end

  def test_migrated_articles_do_not_hotlink_source_images
    Dir['knowledge/know_*.html'].each do |path|
      html = File.read(path)
      refute_match(%r{<img[^>]+src="https?://(?:www\.)?gracelife\.com\.tw/}, html, path)
    end
  end

  def test_cards_are_unique_and_sorted_descending
    doc = Nokogiri::HTML(File.read('knowledge.html'))
    cards = doc.css('a.knowledge-card')
    hrefs = cards.map { |card| card['href'] }
    dates = cards.map { |card| Date.parse(card.at_css('time')['datetime']) }
    assert_equal hrefs.uniq, hrefs
    assert_equal dates.sort.reverse, dates
  end
end
