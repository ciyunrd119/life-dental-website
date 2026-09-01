require 'json'
require 'minitest/autorun'

class TaichungStructuredDataTest < Minitest::Test
  def setup
    html = File.read('taichung/index.html')
    json = html.match(%r{<script type="application/ld\+json">\s*(.*?)\s*</script>}m)

    refute_nil json, '台中診所頁面應包含 JSON-LD'
    @data = JSON.parse(json[1])
  end

  def test_dentist_identity_and_canonical_page
    assert_includes Array(@data['@type']), 'Dentist'
    assert_equal '生活牙醫診所 台中旗艦店', @data['name']
    assert_equal 'https://www.gracelife.com.tw/taichung/', @data['url']
  end

  def test_location_and_image_are_published_without_self_serving_rating
    assert_equal 'https://www.gracelife.com.tw/img/clinic/tc/env02.jpg', @data['image']
    assert_equal '24.151092211562702', @data.dig('geo', 'latitude')
    assert_equal '120.63645859841542', @data.dig('geo', 'longitude')
    refute @data.key?('aggregateRating'), '官方診所頁不應發布自身的 aggregateRating'
  end
end
